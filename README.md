# TriboContact

Standalone Delphi 13 (Win64 VCL) contact-mechanics tool for ball-on-flat tribotests on single-layer and $N$-layer coated substrates.

## Capabilities

1. **Classical Hertz Baselines**: Computes substrate-only (`hertz_substrate`) and top-film-only (`hertz_top_film`) Hertz references for every load case.
2. **Engine 1 — Semi-Analytical Layered Elastic Solver**: Computes contact pressure, contact radius, indentation depth, 2D subsurface stress fields, dual-sided interface stress jumps ($z_k^-$ and $z_k^+$), 3D sliding stresses ($\mu > 0$), and yield-onset warnings using the Hankel-transform Stiffness Matrix Method (SMM) and Polonsky-Keer CG.
3. **Engine 2 — Automated CalculiX FEM Solver**: Generates graded 2D axisymmetric meshes, builds `.inp` decks, runs portable `ccx.exe` under displacement control, matches target load, and extracts elastic-plastic contact pressures, `PEEQ`, and residual unloading depth.
4. **Desktop GUI, CLI, and Verification Suite**: Includes the native Win64 VCL desktop application (`TriboContact.exe`), console CLI (`TriboContactCLI.exe`), and automated DUnitX verification suite (`TriboContactTests.exe`, V&V benchmarks `T1`–`T8`).

## Download & Install

Pre-built 64-bit Windows installer packages are published on [GitHub Releases](https://github.com/OleksiyPenkov/TriboContact/releases):

1. Download and run `TriboContact-Setup-1.0.0.exe`.
2. Engine 1 (semi-analytical layered elastic solver) and classical Hertz baselines work immediately offline with zero external dependencies.
3. For Engine 2 (CalculiX FEM), either check **Download and verify CalculiX FEM solver** on the final installer page, click **Setup CalculiX** in the GUI toolbar, or run `TriboContactCLI.exe setup-ccx`.

## Building from Source

Run from the repository root (`D:\APS\TriboContact\`):

- Build Debug and Release Win64 binaries (`TriboContactCLI.exe`, `TriboContact.exe`, `TriboContactTests.exe` all into `out\bin\`, together with `out\bin\Help\`):
  ```cmd
  build.cmd
  ```
- Launch the desktop GUI (`F1` or `Help > User Manual` opens the bundled HTML manual):
  ```cmd
  run_gui.bat
  ```
- Run the full DUnitX test and benchmark suite:
  ```cmd
  tests\run_tests.cmd
  ```
- Build the Inno Setup 6 Windows installer (`dist\TriboContact-Setup-1.0.0.exe`):
  ```cmd
  installer\build-installer.bat
  ```

## CLI Usage

```cmd
out\bin\TriboContactCLI.exe setup-ccx
out\bin\TriboContactCLI.exe validate
out\bin\TriboContactCLI.exe solve examples\tin_on_steel.json --engine both --pdf
out\bin\TriboContactCLI.exe sweep examples\dlc_on_glass.json --loads-mn 500,1000,2000,5000 --engine elastic
out\bin\TriboContactCLI.exe gui
```

## Repository Layout

- `TriboContact.groupproj`, `TriboContact.dproj`, `TriboContactCLI.dproj` — Delphi 13 Win64 projects (`build.cmd`, `run_gui.bat`).
- `src/core/` — models, materials library, Hertz baselines, Engine 1 (`ElasticLayered`), Engine 2 (`CcxManager`, `FemMesh`, `FemCalculix`), orchestrator (`Runner`), offscreen plots (`PlotRenderer`), and exporters (`Export`).
- `src/cli/` — command-line runner (`TriboContact.CliRunner.pas`).
- `src/gui/` — VCL desktop UI (`MainForm`, `LayerDialog`, `MaterialDialog`, `Worker`).
- `Artwork/` — SVG and multi-resolution Windows `.ico`/PNG application icons (`generate_icon.py`).
- `Help/` — offline HTML User Manual and Physics Reference copied to `out\bin\Help\`.
- `installer/` — Inno Setup 6 installer script and PowerShell/batch packaging wrapper (`build-installer.bat`).
- `data/materials.json` — curated ball, coating, and substrate presets (custom presets saved locally without altering `data/materials.json`).
- `examples/` — sample coated tribotest JSON cases (`tin_on_steel.json`, `dlc_on_glass.json`, `hard_film_on_polymer.json`).
- `tests/` — DUnitX unit tests and automated V&V benchmarks (`T1`–`T8`, CLI, export, and GUI smoke tests).
- `bin/ccx/` — local portable CalculiX Windows binary (gitignored, installed on demand via `TriboContactCLI.exe setup-ccx`).

## License

TriboContact source code and binaries are licensed under the [MIT License](LICENSE). Optional CalculiX (`ccx.exe`, GPLv2) is downloaded separately on demand from upstream CalculiX distributions and is not bundled in the repository or MIT installer.
