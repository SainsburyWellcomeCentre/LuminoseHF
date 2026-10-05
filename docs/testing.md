# Testing

## Running the tests

From MATLAB:

```matlab
cd tests
runTests
```

From WSL (headless):

```bash
"/mnt/c/Program Files/MATLAB/R2025b/bin/matlab.exe" -batch "cd tests; runTests"
```

`runTests` errors when a test fails, so a `-batch` run exits non-zero.

If that command fails with `Exec format error` or a screen of `not found` / `Syntax error` lines, WSL cannot run Windows programs: its interop is not registered (systemd in `/etc/wsl.conf` often clears it). It is not a MATLAB problem. In a WSL terminal:

```bash
sudo sh -c 'echo :WSLInterop:M::MZ::/init:PF > /proc/sys/fs/binfmt_misc/register'
```

## What they cover

Nothing in `tests/` opens a device, a COM port or Bpod, so the suite can run while the rig is idle or from another machine. `runTests` puts the device packages on the path (`LuminoseConstants.addDevicePackages`), so their repos must be in `paths.matlabFolder`; the laser tests use `obis`'s simulated laser. Each device repo has its own suite (`tests/run_tests` there).

| File | Covers |
|---|---|
| `ScoreTrialTest` | `lhf.scoreTrial` for go/no-go and choice tasks, the outcome codes |
| `TrialSelectionTest` | `lhf.nextTrialType` (probabilities, alternation, no repeat-on-error, bias bounds), `lhf.responseBias`, `lhf.trialPolicy`, `lhf.random` seeding, `lhf.protocolInfo` |
| `MergeSettingsTest` | `lhf.mergeSettings`: saved values, declarations, retired, undeclared, wrong-kind and out-of-range settings; `lhf.settingsHistory` |
| `OdourDeliveryTest` | `lhf.olf.resolve`: single rows, probability draws, fixed rows (drawn as the trial is prepared), padding zeros dropped, repeatability, unknown codes; `lhf.olf.drawRows`; `lhf.olf.sequenceDuration`; on the olfactometer package's simulated valves, in process: `lhf.olf.deliver` (the duty actually sent recorded, a bottle duty for 0, a bad row logged not thrown) and `lhf.olf.close` (deliveries kept) |
| `LivePlotsTest` | every `lhf.plot` panel in an invisible window, including that only new trials are read; the power panel only when asked for, grouping by irradiance and leaving out NaN |
| `ReportTest` | `lhf.report.summary` and `write` (to a temporary folder), that `write` never throws, `lhf.stopRecord` |
| `PatternDesignTest` | `lhf.patternFolder`, `lhf.patternFileType` (a type saved under its own name), `lhf.patternDesign` (newest file per row, memory first, empty designs, old files without a row), `lhf.patternDuration` and `lhf.stimDuration` (how long a cue or stimulus lasts, every kind), `lhf.patternTiming` (exposures follow the designs), blank designs saved with no spots |
| `LaserTest` | `lhf.laser.options` (a design's list, the type's defaults, bad weights), `lhf.laser.draw` drawing and queuing nothing without the laser, `lhf.laser.describe` (the pattern table's laser column); on obis's simulated laser, `lhf.laser.onSoftCode` (the queued power set, a refused one logged not thrown) and `lhf.laser.close` (record kept, emission off); `irradianceCalibration` and `irradianceToSetpoint_mW` (round trip, refusal outside the range, `spotGain`) |
| `CameraRegistrationTest` | `lhf.cam`: the affine fit and its inverse on a rig-like map (rotated, scaled, mirrored), residuals, refused points, the canvas map and frames on it, the spot finder (dust ignored, no spot an error), the newest calibration loaded, fiducial files (the first stays the reference); `lhf.spotImage`, `lhf.subjectName` |
| `DesignerCameraPanelTest` | the Pattern Designer's camera column in an invisible figure, on hamacam's simulated camera and `FakeDmd`: off without a calibration, a capture on the canvas, limits (Auto turned off, kept across frames), live, the DMD modes and a running session keeping the DMD, placing and saving fiducials, the reference mark drawn, Align to reference (refused without its calibrations or a reference; end to end on `StageAlignmentTest`'s synthetic sample, the session saved), devices released as the figure closes |
| `StageAlignmentTest` | `lhf.cam.register` (shift and rotation under a fixed illumination, a blank view not confident), `lhf.cam.fitStageCamera` (from given and from measured shifts), `lhf.cam.align` on a synthetic sample seen through a simulated camera moved by ZaberStage's simulated X, Y and Z (back to the reference in X/Y and Z, rotation reported and a large one flagged, a blank view moves nothing, the travel box, a declined confirmation, Stop), `calibration/rigStages` (three axes on one port) |
| `RepositoryTest` | every protocol and package file parses; no file calls a removed per-protocol helper or device model (`LaserModel`, `CameraModel`, `ZaberModel`); the device packages are found; `RepeatOnError` is gone; the config path |

`fakeTrial` and `fakeSession` build made-up trial data for the tests.

## What they do not cover

- **The protocols end to end.** The protocol files need Bpod, the DMD, the NI-DAQ, the HiFi and rotary encoder modules; there are no stand-ins for these yet, so a protocol cannot run under `Bpod('EMU')`. After changing a protocol file, run one short session on the rig.
- **The state machines** (`PrepareStateMachine`): they need Bpod's state-machine functions.
- **The laser connected** (`lhf.laser.open`, `onSoftCode`, `setpoint`): needs the OBIS and the power calibration.
- **Odour delivery on the real valves** (`lhf.olf.startWorker`, `waitWorker` with a DAQ session): needs the NI-DAQ. The worker mechanism itself is tested in the NIDAQOlfactometer repo, on a real one-worker pool with simulated valves.
- **The parameter GUIs**, and the Pattern Designer beyond its camera column.
- **The camera-DMD calibration and the camera column on the rig** (`calibrate_camera_dmd.m`, the Hamamatsu camera and the DMD): run the calibration, then check in the designer that a spot drawn on a landmark lands on it with **DMD: this pattern**.
- **Alignment on the rig** (`rigStages`, `calibrate_stage_camera.m`, **Align to reference**): set `zaber.axes`, run the calibration (about 0.634 px/um), save a reference, move X/Y about 200 um and Z about 30 um by hand, align, and check the stage comes back within 2 um and Stop halts it.

## Adding tests

Add a test for anything added to `+lhf`: one `matlab.unittest.TestCase` class per area in `tests/`, named `<Area>Test.m`, using `fakeTrial`/`fakeSession` for data. Keep tests free of hardware.
