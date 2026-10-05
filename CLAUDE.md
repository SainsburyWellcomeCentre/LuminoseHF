# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

MATLAB codebase for head-fixed mouse behavioural experiments combining Bpod task control, DMD-based patterned optogenetic stimulation, NI-DAQ odour delivery, and optional Bonsai video acquisition.

## Running experiments

All entry points are MATLAB functions launched from within the Bpod GUI:

```matlab
% 1. Start Bpod (with appropriate COM port)
Bpod('COM3')

% 2. Select a protocol from the Bpod GUI
% Available protocols: luminose_hf_goNogo, luminose_hf_2AFC,
%                      luminose_hf_MTS, luminose_hf_sleep,
%                      luminose_hf_powercal (goNogo + laser power per pattern trial, drawn from the design's irradiance list)
```

## Hardware testing

```matlab
% Test DMD pattern generation and BMP export
luminose = LuminoseConstants();
dmdModel = DMDmodel(luminose.dmd);
img_stack = dmdModel.generate_pattern(patterns.test);
dmdModel.save_images(img_stack, "path/to/testimages");

% Test olfactometer
% Run: olfactometer/test_olfactometer.m
```

## Configuration

All rig-specific settings live in `luminose_config.yaml`. Required top-level sections: `paths`, `bpod`, `olfactometer`, `dmd`, `bonsai`. `LuminoseConstants` validates these on construction and also adds key folders to the MATLAB path.

`LuminoseConstants()` reads `luminose_config.yaml` from the folder holding `LuminoseConstants.m` (`LuminoseConstants.defaultConfigFile()`), so the repo works wherever it is cloned; the paths inside the YAML are the rig's.

## Docs and tests

- `docs/architecture.md` — the session, the shared package, and the design decisions (D1–D10). Read it before changing the trial loop, trial selection, scoring, plots, odour delivery or settings loading.
- `docs/data-format.md` — every field and file a session writes, the scoring rules, the settings history.
- `docs/testing.md` — the hardware-free test suite: `cd tests; runTests` in MATLAB, or from WSL `"/mnt/c/Program Files/MATLAB/R2025b/bin/matlab.exe" -batch "cd tests; runTests"` (if that prints `Exec format error`, WSL interop needs re-registering; see the doc).

Update the affected doc in the same change, and add a test for anything added to `+lhf`.

## Architecture

### Configuration layer
- `LuminoseConstants.m` — handle class; loads `luminose_config.yaml`, resolves paths, exposes `.f`, `.bpod`, `.olfactometer`, `.dmd`, `.bonsai` structs. Always instantiate this as `luminose = LuminoseConstants()` at the top of a protocol.

### Hardware models
- `olfactometer/OlfactometerModel.m` — manages NI-DAQ sessions, generates per-odour valve timing matrices, and sequences delivery. Constructed with `OlfactometerModel(luminose.olfactometer, triggered)`.
- `dmd/DMDPatternPlayer.m` (on `DMDController`) — uploads each trial's DMD sequences in the prepare window, never in a soft-code callback. Protocols call `dmd_hf_<name>('prepare', dmdSoftCodes(sma))` after `PrepareStateMachine`, `dmd_hf_<name>('advance')` after `getTrialData`, and `dmd_hf_<name>('close')` in `cleanup`; the soft code itself only starts projection. Fixed patterns are reused across trials; patterns with random spots are rebuilt once per trial. The sleep protocol still runs its DMD handler through `parfeval` and does not use the player.

### Shared package (`+lhf`)

Code the protocols share lives in the `lhf` package (not `luminose`: the global variable `luminose` would hide it). See `docs/architecture.md` for the table and the decisions.
- `lhf.protocolInfo(name)` — per protocol: task kind (`goNogo`/`choice`), trial-type names, odour types, probability setting.
- `lhf.scoreTrial` / `lhf.Outcome` — the only scoring; results stored in `Data.TrialOutcome`/`TrialResponse` and read by everything else.
- `lhf.nextTrialType` + `lhf.trialPolicy` + `lhf.responseBias` — trial selection. No repeat-on-error: the next trial is prepared before the running one's outcome is known.
- `lhf.random` — the session's seeded stream (`Data.RandomSeed`); draw random numbers from it.
- `lhf.plot.*` — the live-plot window and panels (powercal adds `lhf.plot.power`, performance vs irradiance); state in each axes' `UserData`, newest trial only, no `drawnow`.
- `lhf.olf.*` — odour delivery on one warmed-up worker (`startWorker` before the GUI, its warm-up awaited by `waitWorker` after START, `deliver` from the soft-code handler).
- `lhf.mergeSettings` / `lhf.settingsHistory` — loading saved settings; rename or retire a setting there.
- `lhf.patternFolder` / `lhf.patternFileType` / `lhf.patternDesign` — the one folder designs live in, the name a type's files carry (a protocol can save a type under its own name via `luminose.dmd.typeFileNames`, as powercal does: CS- as `designed_powercal_*`, CS+ as `designed_powercalCSplus_*`) and one row's design; a row with no design shows nothing and sends no soft code.
- `lhf.stimDuration` — how long a cue or stimulus lasts (there is no duration setting): a pattern its design (`lhf.patternDuration`), an odour its sequence (`lhf.olf.sequenceDuration`, rows drawn at prepare by `lhf.olf.drawRows` into `NextOdourRow`, handed to the soft-code handler as `SelectedOdourRow` after `getTrialData`), light and sound the `Duration (s)` in their own panel.
- `lhf.laser.*` — optional laser control (Trials tab's **Laser control**; unticked, nothing connects and the protocol runs without the laser). Power is per pattern design, set in the Pattern Designer, drawn per trial by `lhf.laser.draw` and set by soft code 13 in each trial's first state, `SetLaserPower`.
- `lhf.stopRecord` (`Data.StoppedReason`) and `lhf.report.write` (end-of-session `_report.md` and `_summary.png`, from cleanup).

### Protocol structure

```
protocols/luminose_hf_<name>/
  luminose_hf_<name>.m          # Entry point: setup → START → trial loop; PrepareStateMachine, cleanup
  HelperFiles/
    devices/
      SoftCodeHandler_luminose_hf_<name>.m  # odour codes → lhf.olf.deliver; others → DMD (laser for powercal)
      dmd_hf_<name>.m           # DMD handler
    gui/
      GUIparams_luminose_hf_<name>.m        # Declares S.GUI.* defaults and S.GUIMeta.* metadata
      LuminoseParameterGUI_hf_<name>.m      # Renders and syncs the parameter GUI
```

The sleep protocol keeps its own encoder and tracking plots and has no report.

The trial loop: sync the GUI → `lhf.nextTrialType` → `PrepareStateMachine` → `SendStateMachine(sma, 'RunASAP')` → `getTrialData` → start the next trial → record (`AddTrialEvents`, `lhf.scoreTrial`, sniff, encoder) → `lhf.plot.*` updates → one `drawnow` → repeat.

### Shared GUI utilities (`gui/`)
Reusable widgets used by the protocols' parameter screens:
- `DrawTrialStructure.m` — renders cue/stim/response/ITI timeline
- `DrawOptoStim.m` — previews single-pulse or paired-pulse optogenetic timing
- `OdourBottleClicked.m`, `generateBottleImage.m`, `getOdourMapping.m` — odour bottle selector controls
- `StartButtonPressed.m` — locks GUI controls and sets the `StartPressed` appdata flag

### Global variables
Protocols use MATLAB globals: `BpodSystem` (Bpod), `S` (GUI parameter struct), `luminose` (LuminoseConstants instance). `olfModel` (OlfactometerModel) lives on the olfactometer worker (`lhf.olf.worker`).

## Conventions

- Use `luminose = LuminoseConstants()` rather than hardcoded paths anywhere in protocol code.
- Hardware-specific logic belongs in model classes or `HelperFiles/devices/`, not in the main protocol script.
- Protocol-specific GUI defaults go in the protocol's `GUIparams_*.m`; shared GUI widgets go in the top-level `gui/`; logic more than one protocol needs goes in `+lhf`, not in copies per protocol.
- Soft codes ≤ 7 route to the olfactometer handler; codes 8–12 go to the DMD handler (8 cue, 9/10 stimuli, 11 halt, 12 opto); 13 sets the laser power (`lhf.laser.onSoftCode`).
- Nothing slow or allocating runs in a soft-code callback or per trial when it can run once: all live plots share one window (`lhf.plot.createFigure`), are updated from the newest trial only and redrawn once per trial, and are saved as the window closes (`saveOnlinePlotsOnClose`), session data every 5 trials, and `TrialSettings(n)` keeps only `S.GUI` (`GUIMeta` is saved once). `cleanup` runs through `onCleanup`, calls `RunProtocol('Stop')` and clears `BpodSystem` from the base workspace (the R2025b Workspace browser otherwise runs MATLAB out of memory after a session).
- Olfactometer valve numbering: back odour valves are channels 3–8 and 11–16; clean air valves are 1, 2, 9, 10.
