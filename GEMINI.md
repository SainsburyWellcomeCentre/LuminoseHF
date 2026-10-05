# Luminose HF Project Overview

`luminose_hf` is a MATLAB codebase for head-fixed mouse behavioural experiments. It combines Bpod task control, DMD-based patterned stimulation, NI-DAQ driven odour delivery, and optional Bonsai video acquisition.

## Core technologies

- MATLAB for protocol logic and hardware orchestration
- Bpod Gen2 for trial state machines and modules
- DMD hardware plus `DMDController` for patterned optogenetic stimuli
- NI DAQ through MATLAB Data Acquisition Toolbox for olfactometer timing
- Bonsai for synchronized camera workflows
- YAML configuration via `luminose_config.yaml`

## Current architecture

### Configuration

- `LuminoseConstants.m` is the central entry point for loading config, constants, and paths.
- `luminose_config.yaml` stores rig-specific paths, module settings, and hardware parameters.

### Hardware models

- `dmd/DMDmodel.m` manages pattern generation, storage, and DMD communication.
- `olfactometer/OlfactometerModel.m` generates valve state matrices and handles bottle metadata.

Recent model updates:

- `DMDmodel.save_images(...)` now deduplicates identical frames before writing BMPs.
- `OlfactometerModel.generate_valve_pattern(...)` now allocates each odour to its own slot, applies bounds checks, and handles empty selections safely.

### Protocols

Behavioural protocols live under `protocols/` and keep the same general layout:

- Main entry script: `protocol_name.m`
- `HelperFiles/devices/`: soft code handlers and device wrappers
- `HelperFiles/gui/`: parameter GUI definitions and sync logic
- Shared code (scoring, trial selection, live plots, odour delivery, settings loading, the session report) is in the `+lhf` package; see `docs/architecture.md`

Active protocol areas include:

- `protocols/luminose_hf_goNogo/`: main go/no-go task

### Shared GUI layer

The top-level `gui/` folder now provides reusable GUI helpers used by the protocols' parameter interfaces:

- `StartButtonPressed.m`: locks selected controls and flips the GUI into a running state
- `DrawTrialStructure.m`: renders the current cue, stimulus, response, reward/error, and ITI timeline
- `DrawOptoStim.m`: previews configured single-pulse or paired-pulse optogenetic timing
- `OdourBottleClicked.m`, `generateBottleImage.m`, `getOdourMapping.m`: support odour selection controls

## Operational notes

- `dmd/test_dmd.m` now serves as a simple pattern generation and BMP export check using the `dmd/testimages_*` output prefix.
- `protocols/luminose_hf_goNogo/HelperFiles/gui/GUIparams_luminose_hf_goNogo.m` was updated to remove the error amplitude GUI field and to change the default CS+ and CS- odour valves.

## Development conventions

- Use `LuminoseConstants` rather than hardcoded rig paths in protocol code.
- Keep hardware-specific logic inside model classes or `HelperFiles/devices`.
- Keep protocol-specific GUI defaults in the protocol folder, and shared GUI widgets in the top-level `gui/` folder.
