# Architecture

How a luminose_hf session is put together, and why. Read this before changing the trial loop, trial selection, scoring, the live plots, odour delivery or settings loading.

## The layout

```
luminose_hf/
  LuminoseConstants.m        rig configuration (luminose_config.yaml beside it)
  +lhf/                      code shared by the protocols (below)
  protocols/luminose_hf_<name>/
    luminose_hf_<name>.m     the session: setup, START, trial loop, cleanup
    HelperFiles/devices/     soft-code handler, DMD handler (laser for powercal)
    HelperFiles/gui/         GUIparams_* (setting declarations), LuminoseParameterGUI_*
  dmd/, olfactometer/, laser/, camera/, zaber/, gui/   hardware models and GUI widgets
  tests/                     hardware-free test suite (docs/testing.md)
```

Protocols: `goNogo`, `powercal` (goNogo with a laser power on each trial that shows a pattern, drawn from the design's own irradiance list, so a one-value list gives a fixed power; its CS+ and CS- designs are its own, see D11), `2AFC`, `MTS` (match-to-sample) and `sleep` (test pulses, no behaviour).

### The shared package, `+lhf`

The package is `lhf`, not `luminose`: the protocols keep a global variable named `luminose`, which would hide a package of the same name.

| Code | What it owns |
|---|---|
| `lhf.protocolInfo` | Per protocol: task kind, trial-type names, odour types, the probability setting, what habituation does to trial types (2AFC and MTS alternate; powercal runs only CS+) |
| `lhf.scoreTrial`, `lhf.Outcome` | The one definition of a trial's outcome and response, and the stored outcome codes |
| `lhf.nextTrialType`, `lhf.trialPolicy`, `lhf.responseBias` | Trial selection and bias correction |
| `lhf.random` | The session's seeded random stream |
| `lhf.responseTime` | Response time of one trial |
| `lhf.plot.*` | The live-plot window (`createFigure`) and its panels: `outcome`, `accuracy`, `reward`, `responseTime`, `encoder`, and `power` (percent correct per irradiance; a fourth row with `createFigure('WithPower', true)`, used by powercal) |
| `lhf.olf.*` | Odour delivery: `startWorker`, `waitWorker`, `deliver` (soft-code side), `resolve` (which valves), `worker` (the hardware call), `drawRows` (a trial's rows, drawn as it is prepared), `sequenceDuration` (how long a row plays) |
| `lhf.mergeSettings`, `lhf.settingsHistory` | Loading a saved settings file into the current declarations |
| `lhf.patternFolder`, `lhf.patternFileType`, `lhf.patternDesign` | Where pattern designs are saved, the name a type's files carry, and one row's design (or none) |
| `lhf.selectedDesign` | The design of the pattern row chosen for this trial (and the row), or [] |
| `lhf.patternDuration`, `lhf.stimDuration` | How long a design plays on the DMD; how long a cue or stimulus lasts, this trial's or its longest row (D13) |
| `lhf.laser.*` | Optional laser control: `open`/`close` (only with Laser control ticked), `draw` (a trial's power from its pattern's design), `onSoftCode` (code 13), `options`, `setpoint` (cached calibration) |
| `lhf.stopRecord` | Why a session ended (`Data.StoppedReason`) |
| `lhf.report.*` | The end-of-session report: `write`, `summary`, `summaryImage` |

Still per protocol (they differ too much to share safely): the state machine (`PrepareStateMachine`), setting declarations (`GUIparams_*`), the parameter GUI, the DMD handler, the sound and rotary-encoder setup.

## The session

1. **Setup.** `LuminoseConstants`, the olfactometer worker (`lhf.olf.startWorker`, whose warm-up runs while the GUI is open; `lhf.olf.waitWorker` after START), the settings (`GUIparams_*` defaults, then `lhf.mergeSettings` with the saved file), the parameter GUI.
2. **START.** `onCleanup(@cleanup)` is registered; the session seed is drawn (`lhf.random('init')`) and stored; the first trial type is chosen; the live-plot window opens; devices are set up.
3. **Trial loop.** For trial *k*: sync the GUI → choose and prepare trial *k*+1 and send it with `RunASAP` → wait for trial *k*'s data (`getTrialData`) → start *k*+1 → record *k* (events, settings, `lhf.scoreTrial`, sniff, encoder) → update the plots (newest trial only) → one `drawnow` → save every 5 trials.
4. **End.** The loop ends when all trials ran, when the operator stops (`handle_pause_condition`), or on an error; each records `Data.StoppedReason`.
5. **Cleanup** (`onCleanup`, so it also runs after an error or Ctrl+C): DMD closed, data and settings saved, the report written, `RunProtocol('Stop')`, `BpodSystem` cleared from the base workspace.

## Decisions

**D1. The next trial is prepared while the current one runs; there is no repeat-on-error.** Trial *k*+1 is built and sent with `RunASAP` during trial *k*, so it starts with no gap. Its type is therefore chosen before trial *k*'s outcome is known: the recorded data end at trial *k*−1. A repeat-on-error rule could only repeat trial *k*−1's type on *k*+1, splitting the session into two interleaved chains, and in 2AFC/MTS it repeated the wrong trial's type. It was removed (2026-09-29); old settings files drop `RepeatOnError` with a note. Bias correction keeps reading recorded responses: a 20-trial window one trial late is harmless. Habituation alternation reads the running trial's type (`runningType`), which is known.

**D2. One scoring function.** `lhf.scoreTrial` is the only place a trial is scored. The loop stores its result in `Data.TrialOutcome` and `Data.TrialResponse`; the plots, bias correction and the report read those fields and never look at states themselves. Before this, the accuracy plot scored 2AFC Right trials with go/no-go's rule (reaching the ITI without punishment counted as correct), and the outcome plot's no-response marks could never appear for go/no-go. In choice tasks only licks during `GetResponse` count as the response, so a lick during the cue is not a choice.

**D3. Outcome codes are data.** `lhf.Outcome`: 0 incorrect, 1 correct, 3 no response. Never renumber or reuse one.

**D4. Plots keep their own state.** Each `lhf.plot.*` function keeps its line handles and running values in its axes' `UserData`, adds only the newest trial on update, and leaves the redraw to the loop's single `drawnow`. No globals or persistent variables, so they can be tested with no Bpod and replayed for the report.

**D5. Odour delivery runs on one warmed-up worker.** The soft-code handler resolves the valves in the client (where `S` is valid; a worker has its own globals) and hands only the resolved data to `lhf.olf.worker` on a one-worker process pool. The pool is created before the parameter GUI opens (`lhf.olf.startWorker`) and the DAQ session is warmed up on it while the GUI is open, because `daq("ni")` in a fresh worker process can take a minute; after START, `lhf.olf.waitWorker` waits for the warm-up and fails loudly if it failed, before any trial. If the pool is gone, `lhf.olf.deliver` warns and skips rather than letting `parfeval` open a new pool mid-session. Worker errors go to `<data file>_olfactometer_errors.txt`, because nothing collects `parfeval` errors.

**D6. One seed per session.** `lhf.random('init')` draws a seed, stored in `Data.RandomSeed`. Trial types, the ITI order and odour rows draw from its stream; MATLAB's global stream is seeded from it too (for pattern rows, random spots and the barcode). To repeat a session's draws, put its seed in `S.RandomSeed` in the settings file: it is used once and cleared. Draws on the global stream can still differ if soft codes arrive in a different order.

**D7. Settings are merged, not overwritten.** `GUIparams_*` builds the defaults from nothing; `lhf.mergeSettings` then applies the saved file: declarations (`GUIMeta`, `GUIPanels`, `GUITabs`) always from the defaults, saved values kept, renamed settings moved and retired ones dropped (`lhf.settingsHistory`), and a value of the wrong kind or an out-of-range menu choice replaced by the default. Every change is printed at startup and stored in `Data.SettingsNotes`. To rename a setting, add it to `lhf.settingsHistory`; never reuse a retired name.

**D8. Every session records why it ended.** `Data.StoppedReason` (`lhf.stopRecord`): `completed`, `operator`, `error` (with the message and stack) or `unknown` (cleanup found none: a setup error or Ctrl+C).

**D9. Every behaviour session ends with a report.** `lhf.report.write`, from cleanup after the data are saved: `<data file>_report.md` (session, performance per trial type, water, response time, settings changed during the session, settings-file notes) and `<data file>_summary.png` (the live panels redrawn over the whole session). It never throws. Sleep sessions have no report.

**D10. The config file is found beside the code.** `LuminoseConstants()` reads `luminose_config.yaml` from the folder holding `LuminoseConstants.m`, so the repository works wherever it is cloned. The paths inside the YAML are still the rig's.

**D11. powercal's stimuli are designs with defaults, not hard-coded.** powercal keeps its CS+ and CS- designs in the shared `dmd/Patterns` folder under their own file names, `designed_powercalCSplus_*` and `designed_powercal_*` (`luminose.dmd.typeFileNames`, read through `lhf.patternFileType` by the Pattern Designer, the DMD handler and the loaders), so goNogo's `CSplus`/`CSminus` designs never reach it; cue and opto designs stay shared. At startup `loadPowercalDesigns` loads only powercal's files. Until 2026-10-01 they were in a subfolder, `dmd/Patterns/powercal`, under the type names. Both CS+ and CS- default to Pattern. Defaults until something is designed there: CS+ row 1 is blank, no spots for 80 ms (`blankMs`: nothing is projected, no soft code or laser power is sent, but the stimulus lasts 80 ms, D13), and CS- row 1 is a single spot at the DMD centre for 80 ms, 0.12 mm wide. Both last `defaultStimMs`, so the response window opens 80 ms after the sniff on both trial types. A design's spot size is set in the Pattern Designer (**Spot side**) and saved with it (`r_px`); a design opens at its own size, a new one at the rig default (`luminose.dmd.spotSide`). Until 2026-10-02 powercal set it for all its designs with `S.GUI.dmdSpotSide` on the Task tab. A pattern row with no design shows nothing: `PrepareStateMachine` sends no soft code for it (8, 9 or 10) and draws no laser power, while the trial keeps its mask, sniff wait and timing. Laser power is set per design (D12). Before 2026-09-30 CS- was a hard-coded spot (`CentralSpotSide_um`, `CentralSpotDur_ms`, now retired) that ignored the designer.

**D12. The laser is optional, and its power belongs to each pattern.** Every behaviour protocol has a **Laser control** checkbox on the Trials tab (on the Task tab until 2026-10-02) (ticked by default in powercal, unticked elsewhere). Unticked, `lhf.laser.open` connects nothing and no power is ever set, so a session runs with the laser unplugged; the DMD's pin 8 still gates emission at whatever power the laser was left at. Ticked, a laser that does not connect stops the session before trial 1 with a message to untick it. Each stimulus pattern design carries its own irradiance list and draw weights, set in the Pattern Designer (the fields appear for types whose `S.GUIMeta.patternSel_<type>.LaserOptions` is set: CS+/CS-, Left/Right, Template/Sample; a design saved without them uses `LaserDefaults`). A trial showing a pattern draws one irradiance from that design (`lhf.laser.draw`), converts it with the power calibration (cached per session) and queues it. The calibration is full-field, and the DMD is not lit evenly, so it is scaled by `laser.spotGain` in `luminose_config.yaml` (spot irradiance / full-field irradiance, measured 2026-10-01 at 2.348 for a 57×57-mirror spot near the centre): irradiances mean irradiance in that spot, and the calibrated range is about 1.1–34 mW/mm²; soft code 13 in the trial's first state, `SetLaserPower`, sets it. One power per trial: MTS uses the Template's design, or the Sample's on a Non-match trial whose only pattern is the Sample. Every power set is logged to `<data file>_laser_log.txt`. The designer refuses an irradiance outside the calibration.

**D13. A cue or stimulus lasts as long as what it shows.** There is no cue or stimulus duration setting. `ShowCue` and the `DeliverStim` states (MTS: `DeliverStimTemplate`, `DeliverStimMatch`) are timed by `lhf.stimDuration` from the kind chosen in the Task tab: a **pattern** by the drawn row's design as the DMD plays it once, `ceil(max(onset_ms + dur_ms) / tickMs)` frames of the row's exposure (`lhf.patternDuration`, the sequence `DMDPatternPlayer` builds; a row with no design lasts 0, a blank design, no spots and a `blankMs` field such as powercal's default CS+, shows nothing for `blankMs`); an **odour** by its sequence, one olfactometer slot (`preSequenceTime + pulseTime + postSequenceTime` from the config) per odour in the drawn row (`lhf.olf.sequenceDuration`); **light** and **sound** by the `Duration (s)` in their own panel (`LightDuration_<type>`, `SoundDuration_<type>`; a sound is generated at that length when the session starts). So the next state, the response window, starts as the stimulus ends. For the timer to match what is delivered, the odour rows are drawn as the trial is prepared (`lhf.olf.drawRows` into `BpodSystem.PluginObjects.NextOdourRow`) and handed to the soft-code handler (`SelectedOdourRow`) after `getTrialData`, as the DMD handler's `advance` hands over its sequences: the next trial is prepared before the running one's soft codes arrive (D1). The time from the sniff to the response window therefore differs between rows of different lengths. MTS has no cue state: its cue starts with the Template, so its cue has a sound `Duration` only. The GUI's trial-structure preview shows each type's longest row. Until 2026-10-02 `Cue Duration (s)` and `Stim Duration (s)` (`CueTime`, `StimTime`) timed every kind: a longer pattern was halted by soft code 11 at `GetResponse`, a shorter one left the DMD blank, and an odour's `StimTime` was refilled by the GUI from the longest sequence.

**D14. A pattern starts at the sniff onset, if Sniff Trigger is ticked.** With **Sniff Trigger** (Trials tab, Sniff panel; ticked by default), a pattern stimulus waits in `GetSniff` (MTS: `GetSniffTemplate`, `GetSniffMatch`) for the sniff detector's onset event, `Flex1Trig1`; unticked, it starts as soon as the cue ends. Odour, light and sound stimuli never wait for a sniff. The sniff is always detected on a falling signal, as an inhalation drives it (`SniffDetector.risingEdge` false, also for the calibration button). Until 2026-10-02 a **Rising Edge** checkbox (`SniffRising`) could flip it for a hand test, and was ticked by default in goNogo and powercal.

## Rules that follow

- Anything that decides from trial outcomes must accept that the running trial is not yet recorded (D1).
- Score in `lhf.scoreTrial`, nowhere else (D2).
- New per-trial plots go in `lhf.plot`, keep state in `UserData`, update from the newest trial and do not call `drawnow` (D4).
- Draw random numbers from `lhf.random()` (D6).
- Declare settings in `GUIparams_*`; rename or retire them through `lhf.settingsHistory` (D7).
- Add a test for anything added to `+lhf` (docs/testing.md).
