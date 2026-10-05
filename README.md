# LuminoseHF

MATLAB codebase for head-fixed mouse behaviour with patterned optogenetics, odour delivery, and Bpod-controlled task logic.

## Installation

Install [git](https://git-scm.com/downloads) and [MATLAB](https://uk.mathworks.com/help/install/ug/install-products-with-internet-connection.html) with these add-ons:

1. [Data Acquisition Toolbox](https://uk.mathworks.com/help/daq/index.html?s_tid=CRUX_lftnav) for olfactometer control
2. [Signal Processing Toolbox](https://uk.mathworks.com/help/signal/index.html?s_tid=srchtitle_support_results_1_signal%2520processing%2520toolbox)
3. [DSP System Toolbox](https://uk.mathworks.com/help/dsp/index.html?s_tid=srchtitle_support_results_1_dsp%2520system%2520toolbox)
4. [Image Processing Toolbox](https://uk.mathworks.com/help/images/index.html?s_tid=srchtitle_support_results_1_image%2520processing%2520toolbox)

### External dependencies

1. [Bpod Gen2](https://github.com/sanworks/Bpod_Gen2)
2. [DMDController](https://github.com/SainsburyWellcomeCentre/DMDController) for DMD control
3. [OBISLaser](https://github.com/SainsburyWellcomeCentre/OBISLaser) (package `obis`) for the OBIS laser, [ZaberStage](https://github.com/SainsburyWellcomeCentre/ZaberStage) (`zaberstage`) for the Z stage and [HamamatsuCam](https://github.com/SainsburyWellcomeCentre/HamamatsuCam) (`hamacam`) for the calibration camera, [NIDAQOlfactometer](https://github.com/SainsburyWellcomeCentre/NIDAQOlfactometer) (`olfactometer`) for the valves

### Setup

1. Clone Bpod_Gen2, DMDController, OBISLaser, ZaberStage, HamamatsuCam and NIDAQOlfactometer into the folder named by `paths.matlabFolder` in `luminose_config.yaml` (`C:\Users\harrislab\MATLAB` on the rig). `LuminoseConstants` puts each device repo's root on the path and stops with the URL to clone if one is missing.
2. Clone this repository:

```bash
cd <parent directory>
git clone https://github.com/SainsburyWellcomeCentre/LuminoseHF.git
```

3. Add the parent directory and its subfolders to the MATLAB path.
4. Edit `luminose_config.yaml` for the local rig, file paths, and hardware IDs.

## Usage

1. Launch Bpod:

```matlab
Bpod('COM3')
```

2. Select a protocol from the Bpod GUI.

Current protocol families include:

- `protocols/luminose_hf_goNogo/` for the main go/no-go task
- `protocols/luminose_hf_2AFC/` and `protocols/luminose_hf_MTS/` for two-alternative choice and match-to-sample
- `protocols/luminose_hf_powercal/` for go/no-go with a laser power per pattern trial, drawn from the pattern design's irradiance list
- `protocols/luminose_hf_sleep/` for test pulses without behaviour

## Project layout

- `LuminoseConstants.m`: central configuration loader and path setup
- `luminose_config.yaml`: rig-specific configuration
- `dmd/`: DMD control, pattern generation, and image export helpers
- `olfactometer/`: the rig's bottle and chemical tables, sniff detection, a valve check script (the driver is the NIDAQOlfactometer repo)
- `protocols/`: behavioural tasks and their `HelperFiles`
- `gui/`: shared GUI utilities for start control, odour selection, and trial/opto visualizations
- `+lhf/`: code the protocols share: scoring, trial selection, live plots, odour delivery, settings loading, the end-of-session report
- `tests/`: hardware-free tests (`cd tests; runTests`)
- `docs/`: [architecture](docs/architecture.md), [data format](docs/data-format.md), [testing](docs/testing.md)

## After a session

Beside the data file, each behaviour session writes `<name>_report.md` (performance per trial type, water, response time, settings changed, why it ended) and `<name>_summary.png` (the live plots over the whole session). `Data.RandomSeed` records the session's seed; put it in `S.RandomSeed` in the settings file to repeat the session's trial order.

## Recent behaviour changes

- 2026-10-05: the laser, olfactometer, Zaber stage and Hamamatsu camera drivers moved to their own repositories (OBISLaser, NIDAQOlfactometer, ZaberStage, HamamatsuCam; docs/architecture.md, D16); `OlfactometerModel`, `LaserModel`, `CameraModel` and `ZaberModel` are gone
- `dmd/DMDmodel.m` now exports only unique pattern frames in `save_images`, writing deduplicated BMPs for test stacks
- `dmd/test_dmd.m` now exercises pattern generation plus BMP export using the `testimages` prefix
- `olfactometer/OlfactometerModel.m` now builds valve sequences in per-odour time slots, includes safer index bounds, and returns early for empty valve selections
- Default go/no-go odour assignments were updated in `GUIparams_luminose_hf_goNogo.m`

## Notes

- Protocols require the Bpod HiFi module and rotary encoder module.
- The protocols' parameter screens depend on the custom top-level GUI helpers for stimulus previews and odour selection.
