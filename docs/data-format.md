# Data format

What a LuminoseHF session writes. Bpod's own fields (`RawEvents`, `RawData`, `TrialStartTimestamp`, `TrialEndTimestamp`, `Info`, ...) are as Bpod documents them; this page lists what the protocols add.

## Files

Beside Bpod's data file `<subject>_luminose_hf_<protocol>_<date>_<time>.mat`:

| File | Written by | What |
|---|---|---|
| `<name>_LivePlots.png` | the live-plot window as it closes | the live window as it last looked |
| `<name>_report.md` | `lhf.report.write` (behaviour protocols) | session, performance per trial type, water, response time, settings changed, settings-file notes |
| `<name>_summary.png` | `lhf.report.write` (behaviour protocols) | the live panels redrawn over the whole session |
| `<name>_laser_log.txt` | `lhf.laser.onSoftCode`, with Laser control ticked | every laser power set, and any error |
| `<name>_olfactometer_errors.txt` | `lhf.olf.deliver` (a refused request) and the olfactometer worker (a failed sequence, e.g. no trigger), only if one failed | one line per failure |
| `<subject>_..._log.txt` | `diary` | the MATLAB console for the session |

In `<dataFolder>/calibration/`, from the Pattern Designer's camera column (architecture D17):

| File | Written by | What |
|---|---|---|
| `camera_dmd_<yyyymmdd_HHMMSS>.mat` (and `.png`) | `calibration/calibrate_camera_dmd.m` | `registration`: `A` (3x2, `[x y 1] * A` maps DMD px to camera px), `Ainv` (camera to DMD), `dmdXY`/`camXY` (the spots), `residualPx`, `rmsPx`, `timestamp`, `camSize`, `dmdSize`, `exposureMs`, `spotRadiusPx`; `background` (the frame with the DMD dark). The newest is used |
| `stage_camera_<yyyymmdd_HHMMSS>.mat` | `calibration/calibrate_stage_camera.m` | `stageCamera`: `C` (2x2, camera px per stage um: `shift' = C * move'`), `Cinv`, `pxPerUm`, `rotationDeg` (stage X on the camera), `movesUm`/`shiftsPx` (the measurements), `residualPx`, `rmsPx`, `timestamp`, `startUm`. The newest is used |
| `fiducials/<animal>.mat` | **Save fiducial** and **Align to reference** (`lhf.cam.saveFiducial`) | `fiducial`: `animal`, `reference` (the first entry saved, never replaced) and `sessions` (every entry, the reference first). An entry: `frame` (averaged camera frame, uint16), `xy` (the mark, camera px; empty for an aligned frame), `exposureMs`, `roi`, `registrationFile`, `stageUm` (`[x y z]`, when the stages were connected), `alignment` (`lhf.cam.align`'s result: `status`, `message`, `residualUm`, `rotationDeg`, `rotationWarning`, `peak`, `startUm`, `endUm`, `zFoundUm`, `moves`), `time`. Fields an older file lacks are filled empty |

## Per trial (`Data`, indexed by trial)

| Field | Meaning |
|---|---|
| `TrialTypes(n)` | 1 or 2: CS+/CS- (goNogo, powercal), Left/Right (2AFC), Match/Non-match (MTS) |
| `TrialOutcome(n)` | `lhf.Outcome`: 0 incorrect, 1 correct, 3 no response (choice tasks only). Written by `lhf.scoreTrial` |
| `TrialResponse(n)` | goNogo, powercal: 1 licked, 0 did not. Choice tasks: 1 or 2, the first lick on BNC1 or BNC2 while in `GetResponse`; NaN for none |
| `TrialSettings(n).GUI` | `S.GUI` as trial *n* ran (`GUIMeta` is stored once, below) |
| `RawEvents.Trial{n}.Actions` | the output actions of the trial's main states |
| `RawEvents.Trial{n}.States.DeliverStim` | the stimulus state (MTS: `DeliverStimTemplate`, `DeliverStimMatch`); with `ShowCue`, it lasts as long as what it shows: a pattern's design, an odour's sequence, or the light or sound panel's `Duration` (docs/architecture.md, D13) |
| `SniffInhalationOnset_s(n)`, `SniffInhalationOffset_s(n)` | from the sniff detector |
| `EncoderData{n}` | rotary encoder stream, times relative to the trial's first encoder event |
| `LaserIrradiance_mWmm2(n)`, `LaserSetpoint_mW(n)` | goNogo, powercal, 2AFC, MTS: the power set for trial *n*, drawn from the shown pattern's design (docs/architecture.md, D12); NaN when none was set: Laser control off, no pattern stimulus, or a pattern row with no design (powercal's default CS+) |

### Scoring rules (`lhf.scoreTrial`)

- **goNogo, powercal:** CS+ is correct when `Reward` ran (a CS+ trial without it is a miss, incorrect); CS- is correct when `Punishment` did not run. There is no no-response outcome.
- **2AFC, MTS:** correct when `Reward` ran; no response when there was no lick during `GetResponse`; incorrect when `Punishment` ran; with no punishment state (punishment off, habituation) the response itself is compared with the trial type.

Until 2026-09-29 (files without `RandomSeed`), 2AFC and MTS scored a trial with a lick but neither reward nor punishment as no response, counted licks outside `GetResponse`, and the live accuracy plot used its own rule. Re-score old files with `lhf.scoreTrial` if the rules need to match.

## Per session (`Data`)

| Field | Meaning |
|---|---|
| `RandomSeed` | the session seed (`lhf.random`); put it in `S.RandomSeed` to repeat the session's draws |
| `StoppedReason` | `lhf.stopRecord`: `Reason` (`completed`, `operator`, `error`, `unknown`), `Trial`, `Time`, `Message`, `Identifier`, `Stack` |
| `SettingsNotes` | what `lhf.mergeSettings` changed when loading the settings file (cell of text; empty for none) |
| `GitHash` | the repository commit the session ran |
| `GUIMeta` | the settings' labels and styles |
| `luminose` | the `LuminoseConstants` object; `luminose.packageVersions` holds each device package's version (D16) |
| `Olfactometer` | the session's `olfactometer.AsyncDelivery.record()`, kept by `lhf.olf.close`: every delivery (time, valves, duty sent) and every worker failure |
| `Laser` | with Laser control ticked: the laser's `obis.Laser.record()`, kept by `lhf.laser.close` (identity, limits, mode, every command with its time, reply and latency) |

## Settings file (`S`, Bpod's `ProtocolSettings`)

`S.GUI` values, `S.GUIMeta`/`GUIPanels`/`GUITabs` declarations, and `S.RandomSeed` (normally empty).

Pattern designs (`designed_<type>_r<row>_<time>_meta.mat`) hold `spots`, `tickMs`, `r_px`, `nF`, for types with laser options `laserIrradiances_mWmm2` and `laserWeights`, and for a blank (saved with no spots) `blankMs`, how long it shows nothing (its tick).

### Settings history

Renamed and retired `S.GUI` settings, applied by `lhf.mergeSettings` from `lhf.settingsHistory`:

| Date | Protocols | Change |
|---|---|---|
| 2026-09-29 | goNogo, powercal, 2AFC, MTS, playground | `RepeatOnError` retired (docs/architecture.md, D1) |
| 2026-09-30 | powercal | `CentralSpotSide_um`, `CentralSpotDur_ms` retired: CS- is a design (D11) |
| 2026-09-30 | powercal | `LaserIrradiances_mWmm2`, `LaserIrradianceProbs` retired: laser power is set per pattern design, in the Pattern Designer |
| 2026-10-01 | powercal | `TrainingIrradiance_mWmm2` and the Randomized power training level retired (a day after they were added): every trial draws from the design's list; save it with one irradiance for a fixed power |
| 2026-10-02 | goNogo, powercal, 2AFC, MTS | `CueTime`, `StimTime` retired: a cue or stimulus lasts as long as its pattern design or odour sequence, or the new `LightDuration_<type>` / `SoundDuration_<type>` in its Light or Sound panel (D13) |
| 2026-10-02 | goNogo, powercal, 2AFC, MTS, sleep | `SniffRising` retired: the sniff is always detected on a falling signal (D14). New: `SniffTrigger` (behaviour protocols) |
| 2026-10-02 | powercal | `dmdSpotSide` retired: each design's spot size is set in the Pattern Designer and saved with it (D11) |
