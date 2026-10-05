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

Nothing in `tests/` opens a device, a COM port or Bpod, so the suite can run while the rig is idle or from another machine.

| File | Covers |
|---|---|
| `ScoreTrialTest` | `lhf.scoreTrial` for go/no-go and choice tasks, the outcome codes |
| `TrialSelectionTest` | `lhf.nextTrialType` (probabilities, alternation, no repeat-on-error, bias bounds), `lhf.responseBias`, `lhf.trialPolicy`, `lhf.random` seeding, `lhf.protocolInfo` |
| `MergeSettingsTest` | `lhf.mergeSettings`: saved values, declarations, retired, undeclared, wrong-kind and out-of-range settings; `lhf.settingsHistory` |
| `OdourDeliveryTest` | `lhf.olf.resolve`: single rows, probability draws, fixed rows (drawn as the trial is prepared), padding zeros dropped, repeatability, unknown codes; `lhf.olf.drawRows`; `lhf.olf.sequenceDuration` |
| `LivePlotsTest` | every `lhf.plot` panel in an invisible window, including that only new trials are read; the power panel only when asked for, grouping by irradiance and leaving out NaN |
| `ReportTest` | `lhf.report.summary` and `write` (to a temporary folder), that `write` never throws, `lhf.stopRecord` |
| `PatternDesignTest` | `lhf.patternFolder`, `lhf.patternFileType` (a type saved under its own name), `lhf.patternDesign` (newest file per row, memory first, empty designs, old files without a row), `lhf.patternDuration` and `lhf.stimDuration` (how long a cue or stimulus lasts, every kind) |
| `LaserTest` | `lhf.laser.options` (a design's list, the type's defaults, bad weights), `lhf.laser.draw` drawing and queuing nothing without the laser |
| `RepositoryTest` | every protocol and package file parses; no file calls a removed per-protocol helper; `RepeatOnError` is gone; the config path |

`fakeTrial` and `fakeSession` build made-up trial data for the tests.

## What they do not cover

- **The protocols end to end.** The protocol files need Bpod, the DMD, the NI-DAQ, the HiFi and rotary encoder modules; there are no stand-ins for these yet, so a protocol cannot run under `Bpod('EMU')`. After changing a protocol file, run one short session on the rig.
- **The state machines** (`PrepareStateMachine`): they need Bpod's state-machine functions.
- **The laser connected** (`lhf.laser.open`, `onSoftCode`, `setpoint`): needs the OBIS and the power calibration.
- **Odour delivery on the worker** (`lhf.olf.startWorker`, `waitWorker`, `deliver`, `worker`): needs the NI-DAQ.
- **The parameter GUIs.**

## Adding tests

Add a test for anything added to `+lhf`: one `matlab.unittest.TestCase` class per area in `tests/`, named `<Area>Test.m`, using `fakeTrial`/`fakeSession` for data. Keep tests free of hardware.
