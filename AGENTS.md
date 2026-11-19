# Coding Agent Instructions (`TriboContact`)

Follow these rules for all development work in `D:\Software\TriboContact\`.

## 1. Startup Order

1. Read `AGENTS.md`, `SPEC.md`, and `PLAN.md` completely before you write any code.
2. Execute the milestones in `PLAN.md` (`M0` through `M6`) in strict order.
3. Do not start the next milestone until all tests for the current milestone pass.
4. Keep code simple, modular, and strictly tied to `SPEC.md`.

## 2. Environment and Packaging

1. Target **Python 3.13** with `uv` (`pyproject.toml` and local `.venv`).
2. Keep core runtime dependencies minimal:
   - `numpy`
   - `scipy`
   - `matplotlib`
   - `pydantic`
   - `PySide6`
3. Keep development and test dependencies minimal:
   - `pytest`
   - `ruff`
4. Store the portable CalculiX Windows binary (`ccx.exe` and required DLLs) under `bin/ccx/` (gitignored).
5. Implement `tribocontact setup-ccx` to download, unpack, and self-test `ccx.exe`.

## 3. Workspace and Data Boundaries

1. Keep all application source code, tests, scripts, presets, and documentation inside `D:\Software\TriboContact\`.
2. Never commit `bin/ccx/`, CalculiX run folders, or measured lab datasets to this repository.
3. For batch studies on measured lab data, read inputs from `D:\ResearchProjects\<project>\raw\` and write results to `D:\ResearchProjects\<project>\computed\`.
4. Never run `git push`, change git credentials, or modify global machine settings unless the user explicitly asks you to do so.
5. Use absolute paths when referencing external lab folders. Keep all internal package imports and resource lookups relative to the package root.

## 4. Non-Negotiable Physics and Numerical Rules

### 4.1 Internal Solver Units
- Use consistent internal solver units across both engines:
  - **Length**: $\mu\text{m}$
  - **Stress / Young's modulus / Yield stress / Pressure**: $\text{GPa}$
  - **Force**: $\text{mN}$
- Verify the dimensional identity: $1\ \text{GPa} \cdot \mu\text{m}^2 = 1\ \text{mN}$.
- Convert user inputs (`mm`, `nm`, `N`, `MPa`) at the boundary (`models.py` / CLI / GUI). Never pass meters and Pascals to CalculiX.

### 4.2 Engine 1 (Semi-Analytical Layered Elastic Solver)
- Use the Hankel-transform **Stiffness Matrix Method (SMM)** built solely with decaying exponentials $e^{-\xi h_k} \in (0, 1]$.
- **Do NOT** use the Transfer Matrix Method (it overflows at large $\xi h_k$).
- Split the top-layer homogeneous half-space compliance analytically (asymptotic subtraction):
  $$G_{zz}^{\text{coated}}(\xi) = G_{zz}^{\text{top}}(\xi) + \Delta G_{zz}(\xi)$$
- Integrate the singular homogeneous term analytically over concentric rings using complete elliptic integrals (`scipy.special.ellipk`, `scipy.special.ellipe`).
- Integrate the smooth residual $\Delta G_{zz}(\xi)$ numerically up to $\xi_{\max} h_1 \ge 25$.
- Solve the normal contact complementarity problem using the **Polonsky-Keer Conjugate Gradient (CG)** algorithm.

### 4.3 Engine 2 (Automated CalculiX Axisymmetric FEM)
- Define axisymmetric geometry in the global $X$–$Y$ plane where $X = r \ge 0$ and $Y = z$ (specimen top surface at $Y = 0$, depth in $-Y$).
- Fix radial displacement on the symmetry axis ($X = 0$) in DOF 1 (`*BOUNDARY` with `1, 1, 0.0`).
- Enforce the CalculiX $2^\circ$ axisymmetric wedge scaling factor for total normal force:
  $$F_{N,360^\circ} = 180 \times \left|\sum \text{RF}_2\right|$$
- Verify the contact pressure integral balance on every solve:
  $$\left|\frac{2\pi \int_0^{r_{\max}} r\,p(r)\,dr - F_N}{F_N}\right| < 0.03$$
- Use `CAX4I` elements by default (allow `CAX4` as an option). **Do NOT** use `CAX8` or `CAX8R` on the contact surface.
- Use `*CONTACT PAIR, TYPE=SURFACE TO SURFACE` (face-to-face penalty contact) with auto-scaled linear pressure-overclosure stiffness and `NLGEOM`.
- Drive indentation by displacement control on `BALL_TOP` (`*BOUNDARY` with `*AMPLITUDE`), never from $F = 0$ by pure force control.
- Match the target load $F_N$ to $\le 1\%$ using secant interpolation (max 3 bracket runs).
- Request `OUTPUT=2D` on `.frd` outputs so node IDs match the 2D `.inp` mesh; verify this behavior against the installed `ccx.exe` in M3/M4 tests.

### 4.4 Interface Discontinuities and Baselines
- Evaluate and store subsurface stresses on **both sides** ($z_k^-$ and $z_k^+$) of every film-film and film-substrate interface. Never average across an interface.
- Always compute and display both `hertz_substrate` and `hertz_top_film` baselines alongside Engine 1 and Engine 2 results.

## 5. Code Comment Policy

It is strictly PROHIBITED to post comments based on the principle that “a comment is useful if the information is accurate and relevant.” Adopt the following approach: comments are not allowed by default; they must prove their right to exist. Pass this same briefing on to subagents verbatim.

## 6. Subagent Rules

If you delegate subtasks to subagents:
1. Pass the Section 5 Code Comment Policy to every subagent verbatim.
2. Give each subagent exact files, clear scope, and concrete acceptance criteria.
3. Require subagents to return ONLY the result of their work. If a subagent saves output to a file, require only a brief status update (task completed or not completed).
4. Review and verify all subagent code and test results before accepting them.

## 7. Verification Gate

1. Run `uv run pytest` and `uv run ruff check src tests` before reporting any milestone or task complete.
2. Verify every quantitative tolerance in `SPEC.md` Section 9 against live test output.
3. Never report a physics benchmark as passing unless you observed the passing output after your final edit.
