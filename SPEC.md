# Technical Specification (`TriboContact`)

## 1. Purpose and Scope

`TriboContact` is a standalone Windows tool for ball-on-flat tribotest contact mechanics. It calculates contact pressure, contact radius, indentation depth, and subsurface stress fields for a sphere pressing against a coated elastic or elastic-plastic substrate.

The tool replaces Hertz calculations for single-film and $N$-layer coatings on softer substrates. It provides two complementary solvers and two analytical Hertz bounds:

- **Classical Hertz References**: Computes both substrate-only (`hertz_substrate`) and top-film-only (`hertz_top_film`) bounds for every case.
- **Engine 1 (`elastic_layered`)**: Fast semi-analytical Hankel-transform solver for an elastic sphere on an $N$-layer elastic half-space. Supports normal contact, 2D subsurface stress grids, interface stress jumps, 3D sliding traction ($\mu > 0$), and yield-onset warnings.
- **Engine 2 (`fem_calculix`)**: Automated 2D axisymmetric elastic-plastic finite element solver using CalculiX (`ccx.exe`). Models large-deformation contact, substrate or coating yielding (`PEEQ`), pressure flattening, contact radius widening, and optional unloading residual depth.

### Physical Scope Boundary
- Engine 2 solves **2D axisymmetric normal indentation** (with optional axisymmetric radial indentation friction).
- Engine 1 solves **3D tangential sliding traction** $q_x(r) = \mu\, p(r)$ in cylindrical $m=1$ harmonics on the surface and sliding symmetry plane ($y = 0$).

---

## 2. Units and Coordinate Conventions

### 2.1 User-Facing Input and Display Units
User schemas, JSON files, CLI flags, and GUI fields accept standard tribology units and convert them at the boundary:

| Quantity | Supported User Units | Default Display Unit |
|---|---|---|
| Ball radius / diameter | `mm`, `um` | `mm` (diameter) |
| Layer thickness | `um`, `nm` | `um` |
| Normal load | `N`, `mN` | `N` or `mN` |
| Young's modulus, yield stress, hardness, pressure, stress | `GPa`, `MPa` | `GPa` |
| Contact radius, indentation depth | `um`, `nm` | `um` |

### 2.2 Consistent Internal Solver Units
Both Engine 1 and Engine 2 operate strictly in the following unit system:

| Quantity | Internal Unit | Equivalence Check |
|---|---|---|
| Length | $\mu\text{m}$ | $1\ \text{mm} = 1000\ \mu\text{m}$ |
| Stress / Modulus / Pressure | $\text{GPa}$ | $1\ \text{GPa} = 1000\ \text{MPa}$ |
| Force | $\text{mN}$ | $1\ \text{N} = 1000\ \text{mN}$ |

Dimensional identity:
$$1\ \text{GPa} \cdot \mu\text{m}^2 = \left(10^9\ \frac{\text{N}}{\text{m}^2}\right)\left(10^{-6}\ \text{m}\right)^2 = 10^{-3}\ \text{N} = 1\ \text{mN}$$

Never pass meters and Pascals to CalculiX.

### 2.3 Coordinate and Sign Conventions
- **Engine 2 (CalculiX Global $X$–$Y$ Plane)**:
  - $X = r \ge 0$: radial coordinate (symmetry axis at $X = 0$).
  - $Y$: vertical coordinate. Specimen top surface lies at $Y = 0$. Specimen body occupies $Y \in [-H_{\text{sub}} - h_{\text{total}},\, 0]$.
  - Ball bottom pole touches $(0, 0)$ at zero displacement. Ball body occupies $Y \ge 0$.
- **Engine 1 and Result Grids**:
  - $r \ge 0$: radial coordinate in $\mu\text{m}$.
  - $z \ge 0$: depth into the coated specimen from the top surface ($z = -Y$).
  - Interfaces lie at depths $z_1 = h_1$, $z_2 = h_1 + h_2$, ..., $z_N = \sum_{k=1}^N h_k$.
- **Stress Sign Convention**:
  - Normal stresses ($\sigma_{rr}, \sigma_{\theta\theta}, \sigma_{zz}, \sigma_{xx}, \sigma_{yy}$) are **positive in tension** and **negative in compression**.
  - Contact pressure $p(r) \ge 0$ is **positive in compression** ($p(r) = -\sigma_{zz}(r, 0)$).

---

## 3. Data Models (`src/tribocontact/models.py`)

Use Pydantic v2 models with strict validation ($E > 0$, $0 \le \nu < 0.5$, $h > 0$, $R > 0$, $F_N > 0$, $\mu \ge 0$).

### 3.1 Core Input Schemas
- **`Material`**:
  - `name: str`
  - `E_gpa: float`
  - `nu: float`
  - `sigma_y_gpa: float | None = None`
  - `E_t_gpa: float | None = None` (bilinear tangent modulus $d\sigma/d\varepsilon_{\text{total}}$)
  - `hardening_curve: list[tuple[float, float]] | None = None` (pairs `(true_stress_gpa, plastic_strain)`)
  - `hardness_gpa: float | None = None`
  - `category: Literal["ball", "coating", "substrate"] = "coating"`
  - `notes: str = ""`
- **`Layer`**:
  - `material: Material`
  - `thickness_um: float`
- **`BallSpec`**:
  - `radius_um: float`
  - `material: Material`
  - `rigid: bool = False`
  - Helper classmethod: `from_diameter_mm(diameter_mm, material, rigid=False)`
- **`LoadCase`**:
  - `normal_load_mn: float`
  - `friction_coeff: float = 0.0`
  - Helper classmethod: `from_newtons(force_n, friction_coeff=0.0)`
- **`SolverConfig`**:
  - `engine: Literal["elastic", "fem", "both"] = "both"`
  - `n_rings: int = 160`
  - `mesh_density: Literal["coarse", "standard", "fine"] = "standard"`
  - `element_type: Literal["CAX4I", "CAX4"] = "CAX4I"`
  - `include_unloading: bool = False`
  - `max_load_brackets: int = 3`
  - `load_tolerance_rel: float = 0.01`
  - `ccx_path: str | None = None`
  - `timeout_s: int = 300`
  - `work_dir: str | None = None`

### 3.2 Tabor Hardness Helper
Provide a standalone utility function:
```python
def yield_from_hardness(H_gpa: float, constraint_factor: float = 2.8) -> float:
    return H_gpa / constraint_factor
```

### 3.3 Output Schemas
- **`StressGrid`**:
  - `r_um: list[float]` (length $N_r$)
  - `z_um: list[float]` (length $N_z$, includes explicit $z_k^-$ and $z_k^+$ rows at every interface)
  - `sigma_rr_gpa: list[list[float]]` ($N_z \times N_r$)
  - `sigma_tt_gpa: list[list[float]]`
  - `sigma_zz_gpa: list[list[float]]`
  - `tau_rz_gpa: list[list[float]]`
  - `sigma_vm_gpa: list[list[float]]`
  - `peeq: list[list[float]] | None = None`
  - Optional Engine 1 3D sliding outputs ($\mu > 0$):
    - `sliding_surface_x_um: list[float] | None = None` (from $-r_{\max}$ to $+r_{\max}$ along $y = 0$)
    - `sliding_surface_sigma_xx_gpa: list[float] | None = None`
    - `sliding_plane_sigma_xx_gpa: list[list[float]] | None = None`
    - `sliding_plane_tau_xz_gpa: list[list[float]] | None = None`
    - `sliding_plane_sigma_vm_gpa: list[list[float]] | None = None`
- **`InterfaceStressSummary`**:
  - `interface_index: int` ($1 \dots N$, where $N$ is the film-substrate interface)
  - `depth_um: float`
  - `above_label: str`
  - `below_label: str`
  - `max_sigma_rr_above_gpa: float`
  - `max_sigma_rr_below_gpa: float`
  - `min_sigma_rr_above_gpa: float`
  - `min_sigma_rr_below_gpa: float`
  - `max_abs_tau_rz_gpa: float`
  - `max_sigma_vm_above_gpa: float`
  - `max_sigma_vm_below_gpa: float`
  - `max_peeq_above: float | None = None`
  - `max_peeq_below: float | None = None`
- **`ContactResult`**:
  - `solver_name: str`
  - `contact_radius_um: float`
  - `penetration_depth_um: float`
  - `residual_depth_um: float | None = None`
  - `p_max_gpa: float`
  - `p_mean_gpa: float`
  - `actual_load_mn: float`
  - `force_balance_error_rel: float`
  - `r_um: list[float]`
  - `p_gpa: list[float]`
  - `z_centerline_um: list[float]`
  - `centerline_sigma_vm_gpa: list[float]`
  - `centerline_sigma_rr_gpa: list[float]`
  - `centerline_sigma_zz_gpa: list[float]`
  - `stress_grid: StressGrid | None = None`
  - `interfaces: list[InterfaceStressSummary]`
  - `layer_yield_ratios: dict[str, float]` ($\max \sigma_{\text{vM}} / \sigma_Y$ per material)
  - `yield_warning: bool` (`True` when any yield ratio $> 0.95$)
  - `max_peeq: float | None = None`
  - `runtime_s: float`
  - `diagnostics: dict[str, Any]`
- **`ComparisonBundle`**:
  - `case_name: str`
  - `ball: BallSpec`
  - `layers: list[Layer]`
  - `substrate: Material`
  - `load_case: LoadCase`
  - `hertz_substrate: ContactResult`
  - `hertz_top_film: ContactResult`
  - `elastic_layered: ContactResult | None = None`
  - `fem_calculix: ContactResult | None = None`

---

## 4. Classical Hertz Reference (`src/tribocontact/hertz.py`)

For a sphere $(R, E_b, \nu_b)$ on a homogeneous half-space $(E_t, \nu_t)$:

$$\frac{1}{E^*} = \left(\text{0 if ball.rigid else } \frac{1 - \nu_b^2}{E_b}\right) + \frac{1 - \nu_t^2}{E_t}$$

$$a = \left(\frac{3 F_N R}{4 E^*}\right)^{1/3}, \qquad \delta = \frac{a^2}{R}, \qquad p_0 = \frac{3 F_N}{2\pi a^2}, \qquad p_{\text{mean}} = \frac{F_N}{\pi a^2} = \frac{2}{3} p_0$$

$$p(r) = \begin{cases} p_0 \sqrt{1 - (r/a)^2}, & r \le a \\ 0, & r > a \end{cases}$$

Centerline stresses at $r = 0$ and $\zeta = z / a \ge 0$:

$$\sigma_{rr}(0, z) = \sigma_{\theta\theta}(0, z) = -p_0 \left[(1 + \nu_t)\left(1 - \zeta \arctan\frac{1}{\zeta}\right) - \frac{1}{2(1 + \zeta^2)}\right]$$

$$\sigma_{zz}(0, z) = -\frac{p_0}{1 + \zeta^2}, \qquad \sigma_{\text{vM}}(0, z) = \left|\sigma_{zz}(0, z) - \sigma_{rr}(0, z)\right|$$

Always compute `hertz_substrate` (using `substrate`) and `hertz_top_film` (using `layers[0].material`).

---

## 5. Engine 1 — Semi-Analytical Layered Elastic Solver (`src/tribocontact/solvers/elastic_layered.py`)

### 5.1 Hankel Transform Convention and Compliance
Define the $n$-th order Hankel transform pair:
$$\tilde{f}_n(\xi) = \int_0^\infty f(r) J_n(\xi r)\, r\, dr, \qquad f(r) = \int_0^\infty \tilde{f}_n(\xi) J_n(\xi r)\, \xi\, d\xi$$

For a normal surface pressure $p(r) = -\sigma_{zz}(r, 0)$ and downward surface displacement $w(r) = u_z(r, 0)$:
$$\tilde{w}(\xi) = G_{zz}(\xi)\,\tilde{p}_0(\xi)$$

For a homogeneous half-space $(E, \nu)$:
$$G_{zz}^{\text{hom}}(\xi) = \frac{2(1 - \nu^2)}{E\,\xi}$$

Include deformable ball elasticity directly in wavenumber space:
$$C_{\text{total}}(\xi) = G_{zz}^{\text{coated}}(\xi) + G_{zz}^{\text{ball}}(\xi), \qquad G_{zz}^{\text{ball}}(\xi) = \begin{cases} 0, & \text{ball.rigid} \\ \frac{2(1 - \nu_b^2)}{E_b\,\xi}, & \text{otherwise} \end{cases}$$

### 5.2 Unconditionally Stable Stiffness Matrix Method (SMM)
Compute $G_{zz}^{\text{coated}}(\xi)$ for $N$ perfectly bonded isotropic layers ($k = 1 \dots N$) on an isotropic substrate half-space $s$ ($k = N+1$):
1. Express each layer's exact $4 \times 4$ P-SV stiffness matrix $\mathbf{K}^{(k)}(\xi)$ using **only decaying exponentials** $e^{-\xi h_k} \in (0, 1]$ (Kausel & Roesset 1981; Wang et al. 2010). Never form $e^{+\xi h_k}$.
2. Use the exact $2 \times 2$ substrate half-space stiffness matrix at $z = z_N$:
   $$\mathbf{K}^{(s)}(\xi) = \frac{2\mu_s \xi}{3 - 4\nu_s} \begin{bmatrix} 2(1 - \nu_s) & 1 - 2\nu_s \\ 1 - 2\nu_s & 2(1 - \nu_s) \end{bmatrix}$$
3. Condense stiffness matrices bottom-up from layer $N$ to layer $1$ using exact $2 \times 2$ Schur complements so the global surface stiffness matrix $\mathbf{K}^{\text{surf}}(\xi)$ has size $2 \times 2$.
4. Invert $\mathbf{K}^{\text{surf}}(\xi)$ to obtain $\mathbf{G}^{\text{coated}}(\xi)$ and take its $(z, z)$ entry $G_{zz}^{\text{coated}}(\xi)$.
5. Assert at $\xi h_1 \to \infty$ that $\xi G_{zz}^{\text{coated}}(\xi) \to \frac{2(1 - \nu_1^2)}{E_1}$ and for identical layer/substrate properties that $G_{zz}^{\text{coated}}(\xi) = G_{zz}^{\text{hom}}(\xi)$ to machine precision.

### 5.3 Asymptotic Subtraction and Influence Matrix
Split the total compliance into its top-layer homogeneous part and an exponentially decaying layered correction:
$$C_{\text{total}}(\xi) = C_{\text{top}}^{\text{hom}}(\xi) + \Delta C(\xi), \qquad C_{\text{top}}^{\text{hom}}(\xi) = \frac{2}{\xi}\left(\frac{1-\nu_1^2}{E_1} + \frac{1-\nu_b^2}{E_b}\right)$$
Because $\Delta C(\xi) = \mathcal{O}(e^{-2\xi h_1} / \xi)$, split the surface influence matrix $D_{ij}$ (displacement at ring midpoint $\bar{r}_i$ due to unit pressure on ring $[r_j, r_{j+1}]$) into two parts:
1. **Analytical Homogeneous Part $D_{ij}^{\text{hom}}$**: Evaluate the exact Boussinesq/Cerruti concentric-ring influence integral analytically using complete elliptic integrals (`scipy.special.ellipk`, `scipy.special.ellipe`) via Love's / Johnson's uniform-disk superposition ($D_{\text{ring}}(r; r_{j+1}) - D_{\text{ring}}(r; r_j)$). Handle the weak integrable logarithmic singularity at $r = r_j$ with exact elliptic evaluation or Gauss-Legendre sub-quadrature around $\bar{r}_i \approx r_j$.
2. **Smooth Residual Part $\Delta D_{ij}$**: Integrate numerically using composite Gauss-Legendre quadrature on $[0, \xi_{\max}]$ with $\xi_{\max} h_1 \ge 25$:
   $$\Delta D_{ij} = \int_0^{\xi_{\max}} \Delta C(\xi)\, J_0(\xi \bar{r}_i) \left[r_{j+1} J_1(\xi r_{j+1}) - r_j J_1(\xi r_j)\right] d\xi$$

### 5.4 Polonsky-Keer Conjugate Gradient Normal Solver
Discretize $r \in [0, r_{\max}]$ into $M$ concentric rings ($M = 160$ default, clustered near $[0, 1.3 a_0]$ if needed, with initial domain $r_{\max} = 2.0 \max(a_{\text{sub}}, a_{\text{film}})$).
- Ring area: $A_j = \pi(r_{j+1}^2 - r_j^2)$, ring midpoint: $\bar{r}_j = \frac{1}{2}(r_j + r_{j+1})$.
- Sphere gap profile: $h_{\text{gap}}(\bar{r}_i) = \frac{\bar{r}_i^2}{2 R}$ (or exact $R - \sqrt{R^2 - \bar{r}_i^2}$ when $a/R > 0.05$).
- Solve the quadratic complementarity problem using **Polonsky-Keer Conjugate Gradient (CG)** iterations for pressure vector $\mathbf{p} \ge 0$ and rigid approach $\delta$:
  - Active contact set $I_c = \{i : p_i > 0\}$: $g_i = (D\mathbf{p})_i + h_{\text{gap}}(\bar{r}_i) - \delta = 0$.
  - Outside $I_c$: $p_i = 0$ and $g_i \ge 0$.
  - Load constraint: $\sum_{j=0}^{M-1} A_j p_j = F_N$ enforced at every CG projection step.
  - Convergence tolerance: normalized gap residual $< 10^{-7}$ and load error $< 10^{-7}$.
- **Adaptive Re-gridding**: If the active contact radius $a > 0.85\, r_{\max}$ or $a < 0.25\, r_{\max}$, automatically re-grid around $r_{\max} = 1.6\, a$ and re-solve once.

### 5.5 Subsurface 2D Stress Recovery and Dual Interface Evaluation
From the converged ring pressures $p_j$, compute the exact piecewise-constant Hankel pressure transform:
$$\tilde{p}_0(\xi) = \frac{1}{\xi} \sum_{j=0}^{M-1} p_j \left[r_{j+1} J_1(\xi r_{j+1}) - r_j J_1(\xi r_j)\right]$$
1. Propagate displacements $(\tilde{u}_r(\xi, z), \tilde{u}_z(\xi, z))$ **top-down** using the precomputed SMM interface stiffness matrices (no growing exponentials).
2. Evaluate all four axisymmetric stress components $(\sigma_{rr}, \sigma_{\theta\theta}, \sigma_{zz}, \tau_{rz})$ on a 2D $(r, z)$ grid via Hankel transforms ($J_0, J_1$, and radial-strain $J_1(\xi r)/r$ terms, with exact $r \to 0$ limit $J_1(\xi r)/r \to \xi / 2$).
3. **Critical Interface Rule**: At every layer boundary $z_k$, create two distinct $z$ rows: $z_k^-$ (bottom of layer $k$, using $(E_k, \nu_k)$) and $z_k^+$ (top of layer $k+1$ or substrate, using $(E_{k+1}, \nu_{k+1})$). Record both values in `StressGrid` and `InterfaceStressSummary`.

### 5.6 3D Sliding Tangential Traction ($\mu > 0$)
When `friction_coeff > 0`:
1. Model tangential surface traction along $+x$ as $q_x(r) = \mu\, p(r)$, giving cylindrical $m=1$ harmonic tractions $q_r = q_x(r)\cos\theta$ and $q_\theta = -q_x(r)\sin\theta$ (Goodman approximation; document that normal-shear Dundurs $\beta$ coupling is neglected).
2. Solve the coupled $m=1$ P-SV system and the decoupled $2 \times 2$ SH shear layer stiffness system in the Hankel wavenumber domain using only $e^{-\xi h_k}$.
3. Recover sliding stresses on the top surface ($z = 0$) and symmetry plane ($y = 0$, i.e. $\theta \in \{0, \pi\}$) via 1D Hankel quadrature ($J_0, J_1, J_2$) and superpose them onto the normal contact stress field.

### 5.7 Yield-Onset Diagnostic
Compute $\max \sigma_{\text{vM}}(r, z) / \sigma_{Y, k}$ separately for every layer with defined `sigma_y_gpa` and for the substrate. Set `yield_warning = True` when any ratio exceeds `0.95`.

---

## 6. Engine 2 — Automated CalculiX Axisymmetric Elastic-Plastic FEM (`fem_mesh.py`, `fem_calculix.py`)

### 6.1 Binary Discovery and Setup (`tribocontact setup-ccx`)
Resolve `ccx.exe` in strict order:
1. `SolverConfig.ccx_path`
2. Environment variable `TRIBOCONTACT_CCX`
3. `<repo>/bin/ccx/ccx.exe`
4. `ccx` on system `PATH`

`tribocontact setup-ccx` downloads the official Windows 64-bit CalculiX archive (`calculix/CalculiX-Windows` on GitHub or `dhondt.de` mirror), unpacks `ccx.exe` and required DLLs into `bin/ccx/`, and runs a built-in 1-element smoke test.

### 6.2 Pure-Python Parametric Graded Mesh Generator (`solvers/fem_mesh.py`)
Generate structured quadrilateral meshes directly in Python (no external Gmsh dependency).
1. **Domain Sizing**:
   - Estimate contact radius $a_{\text{est}}$ and depth $\delta_{\text{est}}$ from Engine 1.
   - If Engine 1 `max(layer_yield_ratios) > 1.0`, scale $a_{\text{est}}$ by $\max(1.0, \sqrt{r_y}) \times 1.25$ to enclose plastic zone spreading.
   - Far-field extents: $R_{\text{dom}} \ge \max(20\, a_{\text{est}},\, 20\, h_{\text{total}})$ and $H_{\text{sub}} \ge \max(20\, a_{\text{est}},\, 20\, h_{\text{total}})$.
   - Fine contact zone radius: $r_{\text{fine}} = \max(2.0\, a_{\text{est}},\, 3.0\, h_{\text{total}})$ (at least $3.0\, a_{\text{est}}$ when plasticity is active).
2. **Mesh Density Presets**:

| Preset | Radial Elements across $a_{\text{est}}$ | Elements Through Top Film | Max Contact-Zone Aspect Ratio |
|---|---|---|---|
| `coarse` | $\ge 15$ | $\ge 3$ | $\le 10$ |
| `standard` | $\ge 24$ | $\ge 4$ | $\le 10$ |
| `fine` | $\ge 36$ | $\ge 6$ | $\le 10$ |

3. **Topology and Quality Checks**:
   - Enforce **exact conforming node sharing** across all film-film and film-substrate interfaces.
   - Generate a structured graded deformable quarter-sphere mesh for the ball (with smooth arc nodes on the contact face matching contact-zone resolution), or rigid analytic/rigid-element profile when `ball.rigid = True`.
   - Validate positive quad Jacobians, counter-clockwise element orientation in the $X$–$Y$ plane, no coincident nodes, and exact $X = 0$ symmetry-axis node alignment before writing `.inp`.

### 6.3 CalculiX `.inp` Deck Rules (`solvers/fem_calculix.py`)
- **Elements**: `CAX4I` default (`CAX4` selectable). Never use `CAX8` or `CAX8R` on contact surfaces.
- **Boundary Conditions**:
  - Symmetry axis ($X = 0$) on both ball and specimen: `*BOUNDARY` fixing DOF 1 (`Ux = 0`).
  - Specimen bottom ($Y = -H_{\text{sub}} - h_{\text{total}}$): fixed in DOF 2 (`Uy = 0`).
  - Optional specimen outer rim ($X = R_{\text{dom}}$): fixed in DOF 1.
- **Contact Definition**:
  - `*CONTACT PAIR, INTERACTION=INT_CONTACT, TYPE=SURFACE TO SURFACE`
  - Slave surface: top face of top film (finer or matched mesh); Master surface: lower arc of ball.
  - `*SURFACE INTERACTION, NAME=INT_CONTACT`
  - `*SURFACE BEHAVIOR, PRESSURE-OVERCLOSURE=LINEAR` with auto-scaled stiffness $K_p = 50\, E_{\text{eff}} / \Delta r_{\min}$ (and retry adjustment if contact stalls).
- **Plasticity Material Cards**:
  - `*ELASTIC` with $(E, \nu)$ in GPa.
  - When `sigma_y_gpa` is set: add `*PLASTIC` (von Mises J2 isotropic hardening).
  - If `hardening_curve` is provided, emit the tabular pairs `(true_stress_gpa, plastic_strain)`.
  - If only `E_t_gpa` is given (default $E_t = 0.01\, E$ when `E_t_gpa is None`), convert tangent modulus $E_t$ to plastic slope $H' = \frac{E\, E_t}{E - E_t}$ and emit:
    `sigma_y_gpa, 0.0`
    `sigma_y_gpa + H_prime * 0.1, 0.1`
- **Displacement Control and Target-Load Matching**:
  - Use `*STEP, NLGEOM, INC=200`.
  - Apply prescribed downward displacement $-\delta_{\text{trial}}$ to `BALL_TOP` via `*BOUNDARY` and `*AMPLITUDE`. Never run from $F = 0$ under pure force control.
  - Scale CalculiX $2^\circ$ wedge vertical reaction force to full $360^\circ$ load:
    $$F_{N,360^\circ} = 180 \times \left|\sum_{\text{BALL\_TOP}} \text{RF}_2\right|$$
  - Bracket and refine $\delta_{\text{trial}}$ using secant interpolation until $|F_{N,360^\circ} - F_{\text{target}}| / F_{\text{target}} \le 0.01$ (max `max_load_brackets` solves after initial trial $\delta_0 \approx \delta_{\text{Engine1}}$).
  - If `include_unloading = True`, append an unloading `*STEP` ramping `BALL_TOP` back upward until reaction force drops to zero to report `residual_depth_um`.
- **Outputs and Verification**:
  - Request `*NODE FILE, OUTPUT=2D` (`U`, `RF`), `*EL FILE, OUTPUT=2D` (`S`, `PEEQ`), `*CONTACT FILE` (`CSTR`, `CDIS`), plus `*NODE PRINT` (`RF` on `BALL_TOP`) and `*CONTACT PRINT` (`CSTR`, `CDIS`).
  - Parse `.dat` and `.frd` in pure Python.
  - Verify contact pressure integral balance on every solve:
    $$\left|\frac{2\pi \int_0^{r_{\max}} r\,p(r)\,dr - F_{N,360^\circ}}{F_{N,360^\circ}}\right| < 0.03$$
  - Extrapolate or project integration-point stresses cleanly within each material region separately so interface stress discontinuities ($z_k^-$ vs $z_k^+$) remain sharp.

---

## 7. Built-In Material Presets (`data/materials.json`, `src/tribocontact/materials.py`)

Ship a curated library in `data/materials.json` with literature elastic/plastic defaults and source notes:
- **Ball presets**: `Si3N4`, `Al2O3`, `WC-Co`, `100Cr6 Steel`, `Sapphire`, `Diamond`, `SiO2`
- **Coating presets**: `DLC`, `TiN`, `CrN`, `TiAlN`, `W/B4C`, `SiC`, `Al2O3`, `Cu`, `Ru`
- **Substrate presets**: `Si(100)`, `Glass`, `304 Steel`, `Ti-6Al-4V`, `Al 6061-T6`, `Cu`, `PMMA`, `PEEK`

Allow users to select presets, edit any property inline, or save custom presets locally without overwriting tracked `data/materials.json`.

---

## 8. CLI, Plotting, and Desktop GUI

### 8.1 CLI (`tribocontact`)
- `tribocontact solve <case.json> [--engine elastic|fem|both] [--out-dir <dir>]`
- `tribocontact sweep <case.json> --loads-mn 10,50,100,500 [--engine elastic|fem] [--out-dir <dir>]`
- `tribocontact gui`
- `tribocontact setup-ccx [--url <zip_url>]`
- `tribocontact validate` (runs built-in verification suite)

### 8.2 Plots (`src/tribocontact/plotting.py`)
1. **Contact Pressure Profile $p(r)$**: Overlays `hertz_substrate`, `hertz_top_film`, `elastic_layered`, and `fem_calculix`.
2. **2D Subsurface Heatmaps**: Displays $\sigma_{\text{vM}}$, $\sigma_{rr}$, $\tau_{rz}$, and `PEEQ` (FEM) with crisp horizontal lines marking every film interface.
3. **Centerline Depth Profile**: Plots $\sigma_{\text{vM}}(0, z)$ and $\sigma_{rr}(0, z)$ vs depth with explicit step jumps at interfaces.
4. **Load Sweep Curves**: Plots $p_{\max}$, $p_{\text{mean}}$, $a$, and $\max \sigma_{\text{vM}}/\sigma_Y$ vs normal load $F_N$.
5. **FEM Mesh Preview**: Shows structured graded mesh color-coded by layer/material, with zoom into the fine contact zone.

### 8.3 Standalone Desktop GUI (`src/tribocontact/gui/`)
Build with `PySide6`:
- **Left Input Panel**: Ball parameters (radius/diameter, material, rigid toggle), Load & Friction ($F_N$, $\mu$), dynamic $N$-layer Coating Stack table (add/remove/reorder layers, thickness in $\mu\text{m}$ or $\text{nm}$, material preset + inline edit), Substrate material, Solver controls (`Elastic`, `FEM`, `Both`, mesh density, `CAX4I`/`CAX4`, unloading toggle).
- **Execution**: Run solvers in a `QThread` background worker with live CalculiX stdout/stderr log and a Cancel button.
- **Right Results Panel**:
  - Summary comparison table (`Hertz Substrate`, `Hertz Top Film`, `Layered Elastic`, `CalculiX FEM`) with `a`, `delta`, `h_r`, `p_max`, `p_mean`, and yield-onset status badge.
  - Interface stress table showing both $z_k^-$ and $z_k^+$ values.
  - Tabbed interactive Matplotlib canvases for all 5 plot views.
- **Persistence & Export**: Save/load case JSON, export results to CSV/JSON and plots to PNG/PDF.
- **Launchers**: Provide `run_gui.bat` for double-click launch and `scripts/build_exe.py` (optional PyInstaller packaging).

---

## 9. Verification and Validation Matrix

All 8 benchmark checks must run automatically via `pytest` and pass within the exact tolerances below:

| ID | Benchmark | Expected Acceptance Criterion |
|---|---|---|
| **T1** | Engine 1 Hertz limit ($E_f = E_s, \nu_f = \nu_s$, 1, 2, 3 layers) | $a, \delta, p_0$ within $< 0.2\%$ of Hertz; centerline $\sigma_{\text{vM}}$ within $< 0.5\%$ |
| **T2** | Engine 1 thin/thick asymptotes ($h/a = 0.001$ and $h/a = 20$) | Within $< 1\%$ of substrate Hertz and film Hertz respectively |
| **T3** | Engine 1 O'Sullivan & King (1988) layered elastic ($E_f/E_s \in \{0.5, 2, 4\}$, $h/a \in \{0.5, 1.0, 2.0\}$) | Matches published trends and matches elastic Engine 2 FEM within $< 3\%$ |
| **T4** | Engine 1 Hamilton (1983) sliding sphere ($\mu = 0.25, 0.5$, homogeneous) | Trailing-edge surface peak tensile stress $\sigma_{xx}$ within $< 1\%$ of analytical formula |
| **T5** | Engine 2 CalculiX homogeneous elastic Hertz | $a, \delta, p_0$ within $< 2\%$ of Hertz; force-balance integral error $< 2\%$ |
| **T6** | Cross-solver agreement (Engine 1 vs Engine 2 elastic, $E_f/E_s = 4$ and $E_f/E_s = 10$) | $a, \delta, p_{\max}$, and interface $\sigma_{rr}(z_1^-), \tau_{rz}(z_1)$ within $< 3\%$ |
| **T7** | Engine 2 elastic-plastic validation | Homogeneous yield onset near $p_0 \approx 1.6\, \sigma_Y$; plastic plateau approaches Tabor limit ($p_{\text{mean}} \approx 2.8\text{–}3.0\, \sigma_Y$); `PEEQ > 0`; unloading residual depth $h_r > 0$; hard film on soft yielding substrate shows lower $p_{\max}$, wider $a$, and higher film bending $\sigma_{rr}$ than elastic |
| **T8** | Mesh convergence (`coarse` vs `standard` vs `fine`) | Change in $p_{\max}$ and $a$ between `standard` and `fine` is $< 2\%$ |

---

## 10. Target Repository Layout

```text
D:\Software\TriboContact\
├── AGENTS.md
├── CLAUDE.md
├── SPEC.md
├── PLAN.md
├── README.md
├── .gitignore
├── pyproject.toml
├── run_gui.bat
├── bin/                        # Gitignored; holds bin/ccx/ccx.exe
├── data/
│   └── materials.json
├── examples/
│   ├── tin_on_steel.json
│   ├── dlc_on_glass.json
│   └── hard_film_on_polymer.json
├── scripts/
│   └── build_exe.py
├── src/
│   └── tribocontact/
│       ├── __init__.py
│       ├── models.py
│       ├── materials.py
│       ├── hertz.py
│       ├── plotting.py
│       ├── export.py
│       ├── cli.py
│       ├── solvers/
│       │   ├── __init__.py
│       │   ├── elastic_layered.py
│       │   ├── ccx_manager.py
│       │   ├── fem_mesh.py
│       │   └── fem_calculix.py
│       └── gui/
│           ├── __init__.py
│           ├── app.py
│           ├── main_window.py
│           ├── worker.py
│           └── widgets.py
└── tests/
    ├── test_models_hertz.py
    ├── test_elastic_normal.py
    ├── test_elastic_sliding.py
    ├── test_fem_mesh.py
    ├── test_fem_calculix.py
    ├── test_vv_benchmarks.py
    └── test_cli_gui.py
```
