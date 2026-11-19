# Implementation Plan (`TriboContact`)

Execute milestones `M0` through `M6` in strict order. Complete every acceptance gate before you start the next milestone.

---

## M0 — Project Scaffold, Schemas, Presets, and Hertz Baseline

### Deliverables
1. `pyproject.toml`: Configure Python 3.13, `uv` dependencies (`numpy`, `scipy`, `matplotlib`, `pydantic`, `PySide6`), dev tools (`pytest`, `ruff`), and `tribocontact` console script entry point.
2. `src/tribocontact/models.py`: Implement all Pydantic v2 input and output schemas defined in `SPEC.md` Section 3, unit conversion helpers, and `yield_from_hardness()`.
3. `data/materials.json` and `src/tribocontact/materials.py`: Populate all ball, coating, and substrate presets from `SPEC.md` Section 7 with loader and local user-override support.
4. `src/tribocontact/hertz.py`: Implement analytical Hertz contact and subsurface centerline stress calculations for rigid and deformable balls.
5. `tests/test_models_hertz.py`: Test schema validation, unit conversions, preset loading, and Hertz baseline math.

### Acceptance Gate
- `uv sync` installs cleanly.
- `uv run pytest tests/test_models_hertz.py` and `uv run ruff check src tests` pass.

---

## M1 — Engine 1 Normal Layered Contact and Subsurface Stresses

### Deliverables
1. `src/tribocontact/solvers/elastic_layered.py` (normal contact core):
   - Implement the $N$-layer Hankel-transform Stiffness Matrix Method (SMM) using only $e^{-\xi h_k} \in (0, 1]$.
   - Implement top-layer homogeneous asymptotic subtraction and complete elliptic-integral ring influence matrix (`scipy.special.ellipk`, `ellipe`).
   - Integrate the smooth residual $\Delta C(\xi)$ numerically to $\xi_{\max} h_1 \ge 25$.
   - Implement the Polonsky-Keer Conjugate Gradient (CG) solver with adaptive re-gridding when $a > 0.85\, r_{\max}$ or $a < 0.25\, r_{\max}$.
   - Implement top-down displacement propagation and 2D $(r, z)$ stress recovery with dual-sided interface evaluation ($z_k^-$ and $z_k^+$).
   - Compute per-layer yield ratios and `yield_warning`.
2. `tests/test_elastic_normal.py`: Automate V&V Benchmarks `T1`, `T2`, and `T3` (normal contact).

### Acceptance Gate
- **T1**: Homogeneous limit matches Hertz $a, \delta, p_0$ within $< 0.2\%$ and centerline $\sigma_{\text{vM}}$ within $< 0.5\%$ for 1, 2, and 3 layers.
- **T2**: Thin-film ($h/a = 0.001$) and thick-film ($h/a = 20$) limits match substrate and film Hertz within $< 1\%$.
- **T3**: Layered cases ($E_f/E_s \in \{0.5, 2, 4\}$, $h/a \in \{0.5, 1.0, 2.0\}$) reproduce O'Sullivan & King (1988) trends, pressure peaks, and interface jumps.

---

## M2 — Engine 1 3D Sliding Friction ($m=1$ Harmonic)

### Deliverables
1. Extend `src/tribocontact/solvers/elastic_layered.py`:
   - Add $m=1$ cylindrical harmonic P-SV and decoupled $2 \times 2$ SH layer stiffness solvers for tangential surface traction $q_x(r) = \mu\, p(r)$.
   - Compute surface ($z = 0$) and symmetry-plane ($y = 0$) sliding stresses and superpose them onto the normal stress field.
   - Populate optional sliding fields in `StressGrid` when $\mu > 0$.
2. `tests/test_elastic_sliding.py`: Automate V&V Benchmark `T4` plus layered sliding stress checks.

### Acceptance Gate
- **T4**: Homogeneous sliding ($\mu = 0.25$ and $\mu = 0.5$) matches Hamilton (1983) trailing-edge peak tensile stress $\sigma_{xx}$ within $< 1\%$.
- Hard-on-soft layered sliding reproduces the O'Sullivan & King (1988) peak tensile stress shift at the coating surface and interface.

---

## M3 — CalculiX Binary Manager and Parametric Axisymmetric Mesh Generator

### Deliverables
1. `src/tribocontact/solvers/ccx_manager.py`:
   - Implement `ccx.exe` discovery (`ccx_path` $\to$ `TRIBOCONTACT_CCX` $\to$ `bin/ccx/ccx.exe` $\to$ `PATH`).
   - Implement `setup-ccx` downloader and 1-element smoke test.
2. `src/tribocontact/solvers/fem_mesh.py`:
   - Implement the pure-Python graded structured quad mesh generator for $N$ conformal coating layers, substrate, and quarter-sphere ball (or rigid profile).
   - Enforce domain sizing rules, density presets (`coarse`, `standard`, `fine`), aspect-ratio bounds, and exact $X = 0$ node alignment.
   - Implement mesh quality validation (positive Jacobian, orientation, no duplicate nodes).
3. `tests/test_fem_mesh.py`: Verify mesh quality, aspect ratios, interface node sharing across 1–3 layers, and `ccx.exe` discovery/smoke test.

### Acceptance Gate
- `tribocontact setup-ccx` installs a working `ccx.exe` in `bin/ccx/` and passes the 1-element smoke test.
- Mesh generator passes all quality assertions for `coarse`, `standard`, and `fine` presets.

---

## M4 — Engine 2 CalculiX Solver, Target-Load Matcher, and Elastic-Plastic Validation

### Deliverables
1. `src/tribocontact/solvers/fem_calculix.py`:
   - Build CalculiX `.inp` decks with `CAX4I` (or `CAX4`), `*CONTACT PAIR, TYPE=SURFACE TO SURFACE`, auto-scaled penalty stiffness, `NLGEOM`, `*ELASTIC`, and `*PLASTIC` (bilinear or tabular).
   - Implement displacement-controlled loading on `BALL_TOP` with secant target-load matching ($\le 1\%$ tolerance, max 3 brackets).
   - Support optional unloading `*STEP` for residual depth $h_r$.
   - Parse `.dat` and `.frd` (`OUTPUT=2D`) files in pure Python, verify node-ID mapping on the installed `ccx.exe`, apply the $180 \times$ wedge factor, and assert pressure-integral force balance $< 3\%$.
   - Recover per-region stress grids without smoothing across interfaces ($z_k^-$ vs $z_k^+$).
2. `tests/test_fem_calculix.py` and `tests/test_vv_benchmarks.py`: Automate V&V Benchmarks `T5`, `T6`, `T7`, and `T8`.

### Acceptance Gate
- **T5**: CalculiX homogeneous Hertz matches analytical $a, \delta, p_0$ within $< 2\%$ and force balance within $< 2\%$.
- **T6**: Engine 1 and elastic Engine 2 agree within $< 3\%$ on $a, \delta, p_{\max}$, and interface stresses at $E_f/E_s = 4$ and $E_f/E_s = 10$.
- **T7**: Plasticity benchmarks confirm yield onset near $1.6\, \sigma_Y$, Tabor plateau near $2.8\text{–}3.0\, \sigma_Y$, `PEEQ > 0`, $h_r > 0$, and realistic load transfer on a hard-film/soft-substrate stack.
- **T8**: `standard` vs `fine` mesh difference in $p_{\max}$ and $a$ is $< 2\%$.

---

## M5 — Plotting, CLI, Example Cases, and Exports

### Deliverables
1. `src/tribocontact/plotting.py`: Implement all 5 plot functions from `SPEC.md` Section 8.2.
2. `src/tribocontact/export.py`: Export `ComparisonBundle` and sweep tables to CSV, JSON, PNG, and PDF.
3. `src/tribocontact/cli.py`: Implement `solve`, `sweep`, `gui`, `setup-ccx`, and `validate`.
4. `examples/`: Add `tin_on_steel.json`, `dlc_on_glass.json`, and `hard_film_on_polymer.json`.
5. `tests/test_cli_gui.py` (CLI and export portion): Test CLI commands, sweep execution, and file exports.

### Acceptance Gate
- All 3 example JSON cases run end-to-end via `tribocontact solve`.
- `tribocontact validate` passes all V&V benchmarks (`T1`–`T8`).

---

## M6 — Standalone Desktop GUI and Packaging

### Deliverables
1. `src/tribocontact/gui/` (`app.py`, `main_window.py`, `worker.py`, `widgets.py`):
   - Build the `PySide6` interface described in `SPEC.md` Section 8.3.
   - Run solvers in a `QThread` with live log streaming and cancel support.
2. `run_gui.bat`: Windows double-click launcher (`uv run tribocontact gui`).
3. `scripts/build_exe.py`: Optional PyInstaller one-folder packaging helper.
4. `tests/test_cli_gui.py` (GUI portion): Headless `QT_QPA_PLATFORM=offscreen` launch, widget binding, case load/save, and Engine 1 solve smoke test.

### Acceptance Gate
- GUI launches cleanly offscreen in `pytest` and interactively on Windows.
- Full test suite (`uv run pytest`) and linter (`uv run ruff check src tests`) pass with zero failures.
