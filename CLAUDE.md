# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

MATLAB codebase for head-fixed mouse behavioural experiments combining Bpod task control, DMD-based patterned optogenetic stimulation and NI-DAQ odour delivery.

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

All rig-specific settings live in `luminose_config.yaml`. Required top-level sections: `paths`, `bpod`, `olfactometer`, `dmd`, `laser`, `camera`, `zaber`. `LuminoseConstants` validates these on construction and also adds key folders to the MATLAB path.

`LuminoseConstants()` reads `luminose_config.yaml` from the folder holding `LuminoseConstants.m` (`LuminoseConstants.defaultConfigFile()`), so the repo works wherever it is cloned; the paths inside the YAML are the rig's.

## Docs and tests

- `docs/architecture.md` — the session, the shared package, and the design decisions (D1–D20). Read it before changing the trial loop, trial selection, scoring, plots, odour delivery or settings loading.
- `docs/data-format.md` — every field and file a session writes, the scoring rules, the settings history.
- `docs/testing.md` — the hardware-free test suite: `cd tests; runTests` in MATLAB, or from WSL `"/mnt/c/Program Files/MATLAB/R2025b/bin/matlab.exe" -batch "cd tests; runTests"` (if that prints `Exec format error`, WSL interop needs re-registering; see the doc).

Update the affected doc in the same change, and add a test for anything added to `+lhf`.

## Architecture

### Configuration layer
- `LuminoseConstants.m` — handle class; loads `luminose_config.yaml`, resolves paths, exposes `.f`, `.bpod`, `.olfactometer`, `.dmd`, `.laser`, `.camera`, `.zaber` structs. Always instantiate this as `luminose = LuminoseConstants()` at the top of a protocol. Data live in `paths.dataFolder`: `D:\luminoseData\rawdata` since 2026-10-05 (sessions, `calibration/`, fiducials). Bpod's own data folder (Bpod console settings) must be the same; `lhf.recordSetup` warns at START when a session is saved elsewhere.

### Device packages (separate repos in `paths.matlabFolder`, D16)
- `obis` ([OBISLaser](https://github.com/SainsburyWellcomeCentre/OBISLaser)) — the OBIS laser (`obis.Laser`, `obis.Calibration`, a simulated laser for tests). Used by `lhf.laser.*`, `laser/irradianceCalibration.m` and `lhf.cal.power`.
- `zaberstage` ([ZaberStage](https://github.com/SainsburyWellcomeCentre/ZaberStage)) — the Zaber stage, one `zaberstage.Stage` per axis (moves refused outside `LimitsUm`). Loading the rig's own `luminose_config.yaml` also stores `zaber.axes` (with each `safe_um`) and `zaber.port` as zaberstage's preferences (`LuminoseConstants.stageDefaults`/`storeStageDefaults`), so `zaberstage.app()` opened on its own keeps the rig's safe ranges. The rig's X, Y and Z are `lhf.device('stage')`; `calibration/rigStages.m` builds the three on one port (`SharedTransport`) from a config, as the tests do.
- `olfactometer` ([NIDAQOlfactometer](https://github.com/SainsburyWellcomeCentre/NIDAQOlfactometer)) — the valves (`olfactometer.Olfactometer`, sequences sample for sample as before; `olfactometer.AsyncDelivery`, the one warmed-up worker; `olfactometer.Bottles`). Used by `lhf.olf.*` and `olfactometer/test_olfactometer.m`; the rig's bottle tables stay in `olfactometer/`.
- `hamacam` ([HamamatsuCam](https://github.com/SainsburyWellcomeCentre/HamamatsuCam)) — the Hamamatsu camera (`hamacam.Camera`, averaged uint16 frames): `lhf.device('camera')`.
- **One object per device, controlled by its panel.** `lhf.device(name)` (`'camera'`, `'stage'` for X/Y/Z, `'laser'`, `'dmd'`) is the rig's one object for each device, made on first use from `luminose_config.yaml` (appdata `lhfDevices`); `lhf.device(name, 'connect')` connects it if needed. Everything uses it: the device packages' panels (`hamacam.app`, `zaberstage.app`, `obis.app`, `DMDController.app`), opened from the parameter GUI's **Camera / Stage / Laser / DMD** row under START (`gui/DeviceButtons.m`, all five protocols, through `lhf.devicePanel`: one panel per device, pressed again it comes to the front); the Laser panel shows the power out of the objective from `dmd/power_calibration.csv` (`lhf.laser.sampleCalibration`) and the Camera panel names each saved frame with it (`lhf.laser.powerTag`, e.g. `_sample5.1mW`) and saves into `<dataFolder>/<subject>/luminose_hf_widefield` (`lhf.cam.useSubjectFolder`: the Bpod subject when the panel opens or comes to the front and at START, the Pattern Designer's animal when set); the Pattern Designer (which draws on the camera's panel); the session (`lhf.laser.open`, `DMDPatternPlayer`); `lhf.stagePosition`; and the calibrations (`lhf.cal.run`, the Calibration window). So nothing opens a device twice and the panels show and control what the rest is doing. Connecting and disconnecting are the panels' (closing a panel leaves its device as it is); finishing with a device leaves it connected: a session turns the laser's emission off (`lhf.laser.close`) and halts the DMD and frees its sequences (`DMDPatternPlayer`), the Pattern Designer halts the DMD, scripts that narrow stage limits put them back. The calibrations leave every device connected too, put back as they found it (D20).
- `LuminoseConstants.addDevicePackages` puts each repo's root on the path and records versions in `luminose.packageVersions`; a missing repo stops with its URL. Driver code that is not rig- or protocol-specific belongs in the device's repo, not here.

### Hardware models
- `dmd/DMDPatternPlayer.m` (on `DMDController`) — uploads each trial's DMD sequences in the prepare window, never in a soft-code callback. Protocols call `dmd_hf_<name>('prepare', dmdSoftCodes(sma))` after `PrepareStateMachine`, `dmd_hf_<name>('advance')` after `getTrialData`, and `dmd_hf_<name>('close')` in `cleanup`; the soft code itself only starts projection. Fixed patterns are reused across trials; patterns with random spots are rebuilt once per trial. The sleep protocol uses it too (test pulses, code 12; until 2026-10-06 its handler ran on a `parfeval` worker, without the session's globals and with a DMD of its own).

### Shared package (`+lhf`)

Code the protocols share lives in the `lhf` package (not `luminose`: the global variable `luminose` would hide it). See `docs/architecture.md` for the table and the decisions.
- `lhf.protocolInfo(name)` — per protocol: task kind (`goNogo`/`choice`), trial-type names, odour types, probability setting.
- `lhf.scoreTrial` / `lhf.Outcome` — the only scoring; results stored in `Data.TrialOutcome`/`TrialResponse` and read by everything else.
- `lhf.nextTrialType` + `lhf.trialPolicy` + `lhf.responseBias` — trial selection. No repeat-on-error: the next trial is prepared before the running one's outcome is known.
- `lhf.random` — the session's seeded stream (`Data.RandomSeed`); draw random numbers from it.
- `lhf.plot.*` — the live-plot window and panels (goNogo and powercal add `lhf.plot.dprime`, moving d' from `lhf.dprime`; powercal adds `lhf.plot.power`, performance vs irradiance); state in each axes' `UserData`, newest trial only, no `drawnow`.
- `lhf.olf.*` — odour delivery on one warmed-up worker through `olfactometer.AsyncDelivery` (`startWorker` before the GUI, its warm-up awaited by `waitWorker` after START, `deliver` from the soft-code handler, `close` in cleanup).
- `lhf.mergeSettings` / `lhf.settingsHistory` — loading saved settings; rename or retire a setting there.
- `lhf.patternFolder` / `lhf.patternFileType` / `lhf.patternDesign` — the one folder designs live in, the name a type's files carry (a protocol can save a type under its own name via `luminose.dmd.typeFileNames`, as powercal does: CS- as `designed_powercal_*`, CS+ as `designed_powercalCSplus_*`) and one row's design; a row with no design shows nothing and sends no soft code.
- `lhf.stimDuration` — how long a cue or stimulus lasts (there is no duration setting): a pattern its design (`lhf.patternDuration`), an odour its sequence (`lhf.olf.sequenceDuration`, rows drawn at prepare by `lhf.olf.drawRows` into `NextOdourRow`, handed to the soft-code handler as `SelectedOdourRow` after `getTrialData`), light and sound the `Duration (s)` in their own panel.
- `lhf.laser.*` — optional laser control (Trials tab's **Laser control**; unticked, nothing connects and the protocol runs without the laser). Power is per pattern design, set in the Pattern Designer, drawn per trial by `lhf.laser.draw` and set by soft code 13 in each trial's first state, `SetLaserPower`.
- `lhf.stopRecord` (`Data.StoppedReason`) and `lhf.report.write` (end-of-session `_report.md` and `_summary.png`, from cleanup).
- `lhf.recordSetup` → `Data.Setup` at START (`lhf.provenance`: every repo's commit and uncommitted diff, the config; `lhf.calibrationSnapshot`; `lhf.stagePosition`; the subject's fiducial), per-trial `Actions.Patterns`/`PatternRows`/`OdourRows`, `Data.OdourDeliveries`, logs beside the data (`lhf.sessionFile`); `lhf.recreate(dataFile, folder)` writes a session back out to run again (D19). Calibration scripts save `lhf.provenance` too.
- `lhf.cal.*` — the rig's calibrations (D20), run from the Calibration window (the **Calibrate** button, `gui/CalibrationApp.m`) or `calibration/calibrate_*.m`: `catalog` (each calibration, what to set up, its settings and their defaults from the config), `run` (on the shared devices, putting back what it changes; Stop between steps), `cameraDmd`, `stageCamera`, `zFocus`, `power` (the measurements), `powerMeter` (the PM100D), `save` (the same files as before; the newest is used), `load`, `history`, `plot`.
- `lhf.cam.*` — the camera as the Pattern Designer's canvas (D17): the camera-DMD calibration (`calibration/calibrate_camera_dmd.m` → `camera_dmd_*.mat`, DMD px to full-sensor camera px, `fitRegistration`, `toCamera`/`toDmd`; `hamacam.Camera.sensorToFrame`/`frameToSensor` for the frame shown), per-animal fiducials (`calibration/fiducials/<animal>.mat`, the first saved is the reference), and automatic alignment to that reference with the Zaber X/Y/Z (D18: `register`, `fitStageCamera` from `calibration/calibrate_stage_camera.m`, `align`; the axes from `calibration/rigStages.m` and `zaber.axes`). The designer's fiducial column (`gui/PatternDesigner.m`) has them, with a stage readout and **Go to reference X/Y** (X/Y only, to the reference's saved position; Z is left to alignment), and per-animal **targets** (glomeruli: `calibration/targets/<animal>.mat`, `lhf.cam.saveTargets`/`loadTargets`, kept in the reference frame and carried into the current view by **Locate**, `lhf.cam.mapPoints`; a click near one snaps a spot onto it, **Spots on targets**).

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

The sleep protocol keeps its own encoder plot and has no report.

The trial loop: sync the GUI → `lhf.nextTrialType` → `PrepareStateMachine` → `SendStateMachine(sma, 'RunASAP')` → `getTrialData` → start the next trial → record (`AddTrialEvents`, `lhf.scoreTrial`, sniff, encoder) → `lhf.plot.*` updates → one `drawnow` → repeat.

### Shared GUI utilities (`gui/`)
Reusable widgets used by the protocols' parameter screens:
- `DrawTrialStructure.m` — renders cue/stim/response/ITI timeline
- `DrawOptoStim.m` — previews single-pulse or paired-pulse optogenetic timing
- `OdourBottleClicked.m`, `generateBottleImage.m`, `getOdourMapping.m` — odour bottle selector controls
- `StartButtonPressed.m` — locks GUI controls and sets the `StartPressed` appdata flag
- `DeviceButtons.m` — the Camera / Stage / Laser / DMD / Calibrate row under START (`lhf.devicePanel`)
- Window layout: `lhf.windowPosition` places the parameter GUI (top right), the camera left of it, the DMD, Calibration and Pattern Designer left of the camera, the stage below the camera and the laser left of the stage; the parameter GUIs, `lhf.devicePanel`, `PatternDesigner` and `CalibrationApp` use it
- `CalibrationApp.m` — the Calibration window (D20): every rig calibration with its settings, Run/Stop, the result, Save/Discard and the saved results
- `PatternDesignerGUI.m` → `PatternDesigner.m` — the DMD spot designer: spots are placed and drawn on the Hamamatsu camera panel's image (`lhf.devicePanel('camera')`, `setOverlay`/`setImageClickFcn`) through the camera-DMD calibration; it opens the Laser and Stage panels too (light and focus); its window has the spot controls, **Show on DMD**, and the fiducial/alignment column

### Global variables
Protocols use MATLAB globals: `BpodSystem` (Bpod), `S` (GUI parameter struct), `luminose` (LuminoseConstants instance). The olfactometer lives on its worker (`olfactometer.internal.serve`); the client side is `BpodSystem.PluginObjects.Olfactometer`.

## Conventions

- Use `luminose = LuminoseConstants()` rather than hardcoded paths anywhere in protocol code.
- Hardware-specific logic belongs in model classes or `HelperFiles/devices/`, not in the main protocol script.
- Protocol-specific GUI defaults go in the protocol's `GUIparams_*.m`; shared GUI widgets go in the top-level `gui/`; logic more than one protocol needs goes in `+lhf`, not in copies per protocol.
- Soft codes ≤ 7 route to the olfactometer handler; codes 8–12 go to the DMD handler (8 cue, 9/10 stimuli, 11 halt, 12 opto); 13 sets the laser power (`lhf.laser.onSoftCode`).
- Nothing slow or allocating runs in a soft-code callback or per trial when it can run once: all live plots share one window (`lhf.plot.createFigure`), are updated from the newest trial only and redrawn once per trial, and are saved as the window closes (`saveOnlinePlotsOnClose`), session data every 5 trials, and `TrialSettings(n)` keeps only `S.GUI` (`GUIMeta` is saved once). `cleanup` runs through `onCleanup`, calls `RunProtocol('Stop')` and clears `BpodSystem` from the base workspace (the R2025b Workspace browser otherwise runs MATLAB out of memory after a session).
- Olfactometer valve numbering: back odour valves are channels 3–8 and 11–16; clean air valves are 1, 2, 9, 10.
