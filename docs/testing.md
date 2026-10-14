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
| `OdourDeliveryTest` | `lhf.olf.resolve`: single rows, probability draws, fixed rows (drawn as the trial is prepared), padding zeros dropped, repeatability, unknown codes; `lhf.olf.drawRows`; `lhf.olf.sequenceDuration`; on the olfactometer package's simulated valves, in process: `lhf.olf.deliver` (the duty actually sent recorded, per trial in `Data.OdourDeliveries`, a bottle duty for 0, a bad row logged and recorded, not thrown) and `lhf.olf.close` (deliveries kept) |
| `LivePlotsTest` | every `lhf.plot` panel in an invisible window, including that only new trials are read and that each accuracy line averages its own type's last 20 trials; the power panel only when asked for, grouping by irradiance and leaving out NaN; `lhf.dprime` (0 at chance, finite with all hits) and `lhf.plot.dprime` (hits and false alarms, nothing until both types have run) |
| `ReportTest` | `lhf.report.summary` and `write` (to a temporary folder), that `write` never throws, `lhf.stopRecord` |
| `PatternDesignTest` | `lhf.patternFolder`, `lhf.patternFileType` (a type saved under its own name), `lhf.patternDesign` (newest file per row, memory first, empty designs, old files without a row), `lhf.patternDuration` and `lhf.stimDuration` (how long a cue or stimulus lasts, every kind), `lhf.patternTiming` (exposures follow the designs), blank designs saved with no spots |
| `LaserTest` | `lhf.laser.options` (a design's list, the type's defaults, bad weights), `lhf.laser.draw` drawing and queuing nothing without the laser, `lhf.laser.describe` (the pattern table's laser column); on obis's simulated laser, `lhf.laser.onSoftCode` (the queued power set with its trial, a refused one logged not thrown) and `lhf.laser.close` (record kept with the laser's status, emission off); `irradianceCalibration` and `irradianceToSetpoint_mW` (round trip, refusal outside the range, `spotGain`); `lhf.laser.powerTag` (the camera file name's power at the sample: off, outside the calibration, pulsing) and `lhf.laser.sampleCalibration` |
| `CameraRegistrationTest` | `lhf.cam`: the affine fit and its inverse on a rig-like map (rotated, scaled, mirrored), residuals, refused points, the spot finder (dust ignored, no spot an error), the newest calibration loaded, fiducial files (the first stays the reference); `lhf.spotImage`, `lhf.subjectName`; `lhf.cam.targetsFile`/`saveTargets`/`loadTargets` (list replaced, every save kept) |
| `BpodGuardTest` | `lhf.bpod`: a running BpodTrialManager-style timer is stopped (not deleted) and others left; an overflowed Flex I/O viewer buffer is reset to one sweep, a right-sized or closed one left; the sniff calibration refuses during a session and while one runs |
| `CalibrationTest` | `lhf.cal` on simulated devices with known answers (hamacam's camera drawing a `FakeDmd`'s spot through a known map, ZaberStage's axes, obis's laser, a made-up power meter), files in a temporary folder: settings from the config and checked; Camera - DMD recovers the map in sensor px at binning 1 and 2 and saves it where `lhf.cam.loadRegistration` finds it; spots off the map (dust, reflections) dropped and the map still right; no light with every mirror on stops it before the spots; every run logged to `calibration_log.txt`; Stop ends a run with the DMD halted, the camera put back and nothing saved; Stage - camera recovers `C` and returns X/Y with their limits; Z focus finds the brightest plane, returns and restores the limits, a scan past Z's limits is cut there (with a message) and one wholly outside them moves nothing; Laser power reads the meter, rewrites the CSV keeping the old one, emission off at the end, and without a meter keeps the CSV's powers and flags missing ones; history newest first, load and plot; the window: settings shown and edits checked, Defaults, a run used only once saved, Stop, refused during a session, Save of a power calibration asks first |
| `PatternDesignerTest` | the Pattern Designer (`gui/PatternDesigner`) drawing on the camera's own panel (and opening the Laser and Stage panels with it) (hamacam's simulated camera and panel, invisible) with a known calibration, and `FakeDmd`: a click on the camera image places a spot at the DMD px the calibration gives and its square is drawn where it lands, still right after binning 2 and a subarray; right click removes the nearest; overlap, nSpots and clicks outside the DMD field refused; grid clicks toggle cells (the fill buttons gone); DMD all on (the whole field, turned on by Place mark, exclusive with Show on DMD, halted on close); without a calibration nothing is placed and the camera is not drawn on; Save writes the design as before (read back by `lhf.patternDesign`, `S.GUI` frames and exposure) and it opens again; closing takes the design off the camera panel, which stays; Show on DMD projects every change and halts on untick and close, refused while a session runs; fiducials (the first is the reference, marks in sensor px, binning and ROI saved, the reference mark drawn), the fiducial column unfolding; Align to reference (refused without its calibrations, a reference, or the reference's readout; end to end on `StageAlignmentTest`'s synthetic sample, the session saved); the stage readout and Go to reference X/Y (X/Y moved and Z kept, off without a saved position, a target outside the safe range refused, a declined confirmation); setting the animal points the camera's Save to folder at `<data>/<animal>/luminose_hf_widefield`; targets: refused without a fiducial, marked (and removed) on a textured simulated tissue, saved, found again after the tissue moves (Locate), a click snapping a spot onto one, Spots on targets (ticked only), renaming, `spotTargets` in the meta file |
| `DevicePanelTest` | `lhf.devicePanel` (one panel per device, view only during a session), `lhf.windowPosition` (the rig's layout), and `lhf.cam.subjectFolder`/`useSubjectFolder` (the camera saving into the subject's `luminose_hf_widefield` folder; nothing changed without a subject) |
| `StageAlignmentTest` | `lhf.cam.register` (shift and rotation under a fixed illumination, a blank view not confident), `lhf.cam.fitStageCamera` (from given and from measured shifts), `lhf.cam.align` on a synthetic sample seen through a simulated camera moved by ZaberStage's simulated X, Y and Z (back to the reference in X/Y and Z, rotation reported and a large one flagged, a blank view moves nothing, the travel box, a declined confirmation, Stop), `calibration/rigStages` (three axes on one port, a `reversed` axis counted the other way, each kept within its `safe_um` and an axis without one refused), the config reader on nested axes, lists and inline maps; `lhf.cam.mapPoints` with register's result (points of the reference found in a shifted, rotated frame) |
| `RecordingTest` | `lhf.provenance` on a temporary git repository (commit, uncommitted diff, untracked files kept; a folder that is not a repository noted), `lhf.calibrationSnapshot` (the newest of each calibration copied, a missing one noted), `lhf.stagePosition` (read and released on simulated stages, the Pattern Designer's published stages used first, a failure noted), `lhf.recordSetup`, `lhf.recreate` (settings with the seed, one design per type and row including a blank, the patch, the untracked files, the README; refused without `Setup`), the report's Reproduce section; `setup.targets` |
| `RepositoryTest` | every protocol and package file parses; no file calls a removed per-protocol helper or device model (`LaserModel`, `CameraModel`, `ZaberModel`); the device packages are found; `RepeatOnError` is gone; the config path |

`fakeTrial` and `fakeSession` build made-up trial data for the tests.

## What they do not cover

- **The protocols end to end.** The protocol files need Bpod, the DMD, the NI-DAQ, the HiFi and rotary encoder modules; there are no stand-ins for these yet, so a protocol cannot run under `Bpod('EMU')`. After changing a protocol file, run one short session on the rig.
- **The state machines** (`PrepareStateMachine`): they need Bpod's state-machine functions.
- **The laser connected** (`lhf.laser.open`, `onSoftCode`, `setpoint`): needs the OBIS and the power calibration.
- **Odour delivery on the real valves** (`lhf.olf.startWorker`, `waitWorker` with a DAQ session): needs the NI-DAQ. The worker mechanism itself is tested in the NIDAQOlfactometer repo, on a real one-worker pool with simulated valves.
- **The parameter GUIs**, and the Pattern Designer's dialogs and laser table.
- **Bpod guards on the rig**: stop a session mid-trial, check `timerfindall` has no running timer whose `TimerFcn` mentions `processLiveEvents`, restart, run Calibrate Sniff (finishes after 12 s), and run trials with no `XDataYData` warnings.
- **The calibrations on the rig** (the Calibration window): run each once with its devices, check the plot, Stop one midway (the DMD halts, the laser's emission goes off, the stages return), Save, and check the Laser power result against the old CSV with the PM100D.
- **The camera-DMD calibration and the designer on the rig** (Calibrate: Camera - DMD, the Hamamatsu camera and the DMD): run the calibration, open the designer, place spots on landmarks on the live camera image, tick **Show on DMD** and check the light lands on the drawn squares; again at binning 2 with a subarray.
- **Alignment on the rig** (Calibrate: Stage - camera, **Align to reference**): set `zaber.axes`, run the calibration (about 0.634 px/um), save a reference, move X/Y about 200 um and Z about 30 um by hand, align, and check the stage comes back within 2 um and Stop halts it.

## Adding tests

Add a test for anything added to `+lhf`: one `matlab.unittest.TestCase` class per area in `tests/`, named `<Area>Test.m`, using `fakeTrial`/`fakeSession` for data. Keep tests free of hardware.
