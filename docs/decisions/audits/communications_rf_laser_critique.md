# Audit Critique: RF and Laser Communications Models & Calculations

**Target Domain**: RF and Laser Communications, Jamming, and Line-of-Sight Geometry  
**Status**: COMPLETE CRITICAL ARCHITECTURAL AUDIT  
**Auditor**: Communications & RF/Laser Systems Auditor  

---

## 1. Ray-Sphere & Ray-Ellipsoid Intersection Math

### 1.1. Sphere-Based Approximation Flaws
The current analysis document (Section 4.3.1) uses a **ray-sphere intersection** model to check for line-of-sight (LOS) occlusion by celestial bodies:
$$\|\mathbf{p}_{close} - \mathbf{c}_k\| < R_k$$
While this is computationally simple, it is highly inaccurate for ellipsoidal bodies like Earth (WGS84) or Mars (MOLA Areoid). 
* **Earth (WGS84) Eccentricity**: Earth's equatorial radius ($a = 6378.137\text{ km}$) and polar radius ($b \approx 6356.752\text{ km}$) differ by **$21.385\text{ km}$**. 
* **Impact**: 
  * If a spherical model with radius $R_k = a$ is used, links passing near the polar regions will report false-positive occlusions (blocking valid links).
  * If $R_k = b$ is used, links passing near the equatorial plane will report false-negatives (showing clear links that are physically blocked by the equatorial bulge).
  * For safety-critical telemetry, a $21\text{ km}$ error margin is unacceptable.

### 1.2. Exact Ray-Ellipsoid Intersection Formulation
For any planet or moon modeled as a triaxial or biaxial ellipsoid centered at $\mathbf{c}_k$ with semi-axes $a, b, c$, the surface is defined by:
$$\frac{x^2}{a^2} + \frac{y^2}{b^2} + \frac{z^2}{c^2} = 1 \implies (\mathbf{x} - \mathbf{c}_k)^T \mathbf{M} (\mathbf{x} - \mathbf{c}_k) = 1$$
where $\mathbf{M} = \text{diag}\left(\frac{1}{a^2}, \frac{1}{b^2}, \frac{1}{c^2}\right)$.

Let the emitter be at $\mathbf{r}_i$ and the receiver at $\mathbf{r}_j$. Translate coordinates relative to the planet's center $\mathbf{c}_k$:
$$\mathbf{r}_i' = \mathbf{r}_i - \mathbf{c}_k$$
$$\mathbf{r}_j' = \mathbf{r}_j - \mathbf{c}_k$$
The ray segment is parameterized as:
$$\mathbf{p}(t) = \mathbf{r}_i' + t \mathbf{d}, \quad t \in [0, 1] \quad \text{where } \mathbf{d} = \mathbf{r}_j' - \mathbf{r}_i' = \mathbf{r}_j - \mathbf{r}_i$$
Substituting the ray into the ellipsoid equation yields:
$$(\mathbf{r}_i' + t \mathbf{d})^T \mathbf{M} (\mathbf{r}_i' + t \mathbf{d}) = 1$$
$$t^2 (\mathbf{d}^T \mathbf{M} \mathbf{d}) + 2 t (\mathbf{r}_i'^T \mathbf{M} \mathbf{d}) + (\mathbf{r}_i'^T \mathbf{M} \mathbf{r}_i' - 1) = 0$$
This is a standard quadratic equation $A t^2 + B t + C = 0$ where:
* $A = \mathbf{d}^T \mathbf{M} \mathbf{d} = \frac{d_x^2}{a^2} + \frac{d_y^2}{b^2} + \frac{d_z^2}{c^2}$
* $B = 2 \mathbf{r}_i'^T \mathbf{M} \mathbf{d} = 2 \left( \frac{r'_{i,x} d_x}{a^2} + \frac{r'_{i,y} d_y}{b^2} + \frac{r'_{i,z} d_z}{c^2} \right)$
* $C = \mathbf{r}_i'^T \mathbf{M} \mathbf{r}_i' - 1 = \frac{(r'_{i,x})^2}{a^2} + \frac{(r'_{i,y})^2}{b^2} + \frac{(r'_{i,z})^2}{c^2} - 1$

The discriminant is:
$$\Delta = B^2 - 4AC$$
* **If $\Delta < 0$**: No intersection (link is clear).
* **If $\Delta \ge 0$**: Calculate the intersection parameters:
  $$t_1 = \frac{-B - \sqrt{\Delta}}{2A}, \quad t_2 = \frac{-B + \sqrt{\Delta}}{2A}$$
  Because $A > 0$, $t_1 \le t_2$. The line segment $[0, 1]$ intersects the ellipsoid if and only if:
  $$t_1 \le 1 \quad \text{and} \quad t_2 \ge 0$$
  This condition must be implemented in the GPU compute shader for correct narrow-phase occlusion checking.

### 1.3. Atmospheric Grazing Height & Refraction Corrections
* **Grazing Mask**: A laser or RF beam passing too close to the surface will suffer severe atmospheric attenuation, refraction, and scintillation. We must define a minimum grazing altitude $h_{mask}$ (e.g., $100\text{ km}$ for optical, $20\text{ km}$ for RF). 
* **Remediation**: The shape matrix $\mathbf{M}$ must use the expanded semi-axes:
  $$a' = a + h_{mask}, \quad b' = b + h_{mask}, \quad c' = c + h_{mask}$$
* **Refraction**: Ground-to-space links undergo bending due to the refractive index gradient $n(h)$ of the atmosphere. The straight-line ray approximation underestimates path length and overestimates elevation angle. For elevations $\theta_{el} < 10^\circ$, a refraction bending model (e.g., Bennett's formula or ITU-R P.834) must be applied to the ray geometry on the CPU before GPU upload.

---

## 2. Antenna Gain & Radiation Pattern Approximations

### 2.1. Dimensional & Physical Errors in Received Power
The proposed SINR formula is:
$$\text{SINR} = \frac{\frac{P_i G_t G_r(0)}{d_{ij}^2}}{\frac{P_k G_{t\_inf} G_r(\theta_{inf})}{d_{kj}^2} + N_0}$$
This formulation contains a critical **dimensional mismatch**:
* The numerator is written as $\frac{P_i G_t G_r(0)}{d_{ij}^2}$. Assuming $P_i$ is in Watts (W) and gains are dimensionless ratios, the unit of this expression is **$\text{W/m}^2$**, which represents **Power Flux Density (PFD)**, not received power.
* The noise term $N_0$ is traditionally represented in Watts (W) or Watts/Hz (W/Hz). Adding PFD ($\text{W/m}^2$) to Noise ($W$) is mathematically incorrect.
* **Friis Transmission Equation Correction**: The actual received power $P_{rx}$ is a function of the wavelength $\lambda$ (or frequency $f$):
  $$P_{rx} = P_{tx} G_{tx} G_{rx} \left( \frac{\lambda}{4 \pi d} \right)^2 = P_{tx} G_{tx} G_{rx} \frac{c^2}{(4 \pi f d)^2}$$
  The wavelength term $\left(\frac{\lambda}{4\pi}\right)^2$ (representing the effective aperture area of an isotropic antenna) is missing. Omitting this makes the model frequency-agnostic, which is a major failure since a Ka-band link ($30\text{ GHz}$) and an L-band link ($1.5\text{ GHz}$) would calculate identical path losses despite a $26\text{ dB}$ difference in free-space path loss (FSPL).

### 2.2. Antenna Radiation Patterns
The current model refers to $G_r(\theta)$ but does not define it. To compute co-channel interference accurately, the shader must implement mathematical approximations of real-world antenna gain patterns:

1. **Gaussian Beam Pattern (For high-gain directional antennas)**:
   $$G(\theta) = G_{max} \exp\left( -4 \ln(2) \left(\frac{\theta}{\theta_{3dB}}\right)^2 \right) \quad [\text{linear scale}]$$
   where $\theta_{3dB}$ is the half-power beamwidth (HPBW), which can be approximated by:
   $$\theta_{3dB} \approx 1.22 \frac{\lambda}{D} \quad [\text{rad}]$$
2. **Airy Pattern (Circular Aperture Diffraction Limit)**:
   $$G(\theta) = G_{max} \left( \frac{2 J_1(x)}{x} \right)^2 \quad \text{where } x = \frac{\pi D}{\lambda} \sin\theta$$
   where $J_1(x)$ is the first-order Bessel function of the first kind.
3. **ITU-R S.580 Reference Envelope (Standard for Satellite Earth Stations)**:
   For off-axis angles:
   $$G(\theta) = \begin{cases} 
   G_{max} - 2.5 \times 10^{-3} \left(\frac{D}{\lambda} \theta\right)^2 & \text{for } 0 \le \theta < \theta_m \\
   29 - 25 \log_{10}\theta & \text{for } \theta_m \le \theta < 48^\circ \\
   -10 & \text{for } 48^\circ \le \theta \le 180^\circ 
   \end{cases} \quad [\text{dBi}]$$

---

## 3. Angular Separation Calculations

### 3.1. Vector Formulation & Boresight Alignment
The proposed angular separation formula is:
$$\theta_{inf} = \arccos(\mathbf{u}_{sig} \cdot \mathbf{u}_{inf})$$
This assumes the receiver antenna's boresight is always perfectly aligned with the signal vector $\mathbf{u}_{sig}$. 
In reality, directional tracking antennas (especially on moving platforms like LEO satellites or aircraft) have a tracking/pointing error vector. Let $\mathbf{b}_j$ be the unit vector of the receiver antenna's boresight. The pointing errors must be separated:
* **Signal Angle of Arrival (AoA) Offset**: $\theta_{sig} = \arccos(\mathbf{b}_j \cdot \mathbf{u}_{sig})$
* **Interferer AoA Offset**: $\theta_{inf} = \arccos(\mathbf{b}_j \cdot \mathbf{u}_{inf})$

The received signal power and interference power must be scaled by their respective gains relative to the boresight direction:
* $P_{rx} \propto G_r(\theta_{sig})$
* $I_{inf} \propto G_r(\theta_{inf})$

### 3.2. GPU Numerical Stability
In WGSL/WebGPU, evaluating $\theta = \arccos(\mathbf{u}_1 \cdot \mathbf{u}_2)$ is highly problematic:
1. **NaN Vulnerability**: Floating-point precision errors can cause $\mathbf{u}_1 \cdot \mathbf{u}_2$ to evaluate to $1.0000001$ when collinear. In `acos()`, any input outside $[-1, 1]$ yields `NaN`.
2. **Computational Expense**: Transcendental functions like `acos` require significant GPU instruction cycles.
3. **Remediation**: Use `atan2` or clamp the dot product to $[-1, 1]$:
   ```wgsl
   let dot_prod = clamp(dot(u_sig, u_inf), -1.0, 1.0);
   let theta = acos(dot_prod);
   ```
   For pattern evaluation, if the antenna gain pattern is a function of $\cos\theta$ (or can be approximated as such), avoid `acos` altogether to optimize GPU pipelines.

---

## 4. Electromagnetic Jamming & Co-Channel Interference

### 4.1. Incomplete Noise Environments
The denominator uses a generic constant $+ N_0$. This is mathematically incomplete. In a realistic RF link budget, the total noise power $N$ in the receiver passband is:
$$N = k_B T_{sys} B \quad [\text{W}]$$
where:
* $k_B = 1.380649 \times 10^{-23}\text{ J/K}$ (Boltzmann's constant).
* $B$ is the receiver noise bandwidth in Hz.
* $T_{sys}$ is the equivalent system noise temperature:
  $$T_{sys} = T_{ant} + T_{rx} = T_{ant} + (F - 1)T_0 \quad [\text{K}]$$
  where $F$ is the receiver Noise Figure (linear scale), $T_0 = 290\text{ K}$, and $T_{ant}$ is the antenna noise temperature (combining cosmic background, atmospheric emission, and ground thermal noise).

### 4.2. Frequency-Dependent Rejection (FDR)
The jamming model assumes the interferer's power is fully co-channel. In reality, jammers and adjacent-channel networks exhibit frequency offsets. We must introduce a **Frequency-Dependent Rejection (FDR)** factor (or Spectral Overlap Factor $\chi \in [0, 1]$) representing the integration of the interferer's transmit power spectral density $S_{inf}(f)$ with the receiver filter response $H_{rx}(f)$:
$$\chi = \frac{\int_{-\infty}^{\infty} S_{inf}(f) |H_{rx}(f)|^2 df}{\int_{-\infty}^{\infty} S_{inf}(f) df}$$
The effective interference power $I_{effective}$ is then:
$$I_{effective} = I_{raw} \cdot \chi$$

### 4.3. Polarization Mismatch Loss
The current formula ignores polarization vectors. Polarization mismatch between the signal wave and the receiving antenna results in a loss factor $L_{pol} \in [0, 1]$:
$$L_{pol} = |\mathbf{e}_{tx} \cdot \mathbf{e}_{rx}^*|^2$$
where $\mathbf{e}$ represents the complex polarization unit vector (e.g., circular or linear). 
* Circular-to-Linear mismatch introduces a static **$3\text{ dB}$ loss**.
* Cross-polarization mismatch (e.g., RHCP transmitter to LHCP receiver) can introduce **$20\text{ to } 30\text{ dB}$ of isolation**, which is vital for calculating co-channel reuse interference.

---

## 5. Free Space Optical (FSOC / Laser) Communication Gaps

The proposal and analysis documents completely fail to outline the math for **Laser Link Quality**, mentioning only a "geometric visibility factor [0.0 - 1.0]". Laser link budgets do not conform to Friis RF formulas and must be modeled separately:

### 5.1. Laser Path Loss (Beam Divergence Model)
Because laser beams are highly collimated, propagation is not modeled using isotropic gain. Instead, the beam expands as a cone with a full-angle divergence $\theta_{div}$ (typically $10\text{ to } 100\ \mu\text{rad}$).
At distance $d$, the beam spot diameter is $D_{spot} \approx \theta_{div} d$.
The received optical power $P_{rx}$ captured by a receiver aperture of diameter $D_{rx}$ is:
$$P_{rx} = P_{tx} \cdot \eta_{tx} \eta_{rx} \cdot \left( \frac{D_{rx}}{\theta_{div} d} \right)^2 \cdot \tau_{atm}$$
where $\eta_{tx}, \eta_{rx}$ are optical efficiencies, and $\tau_{atm}$ is the atmospheric transmission coefficient modeled via the Beer-Lambert law:
$$\tau_{atm} = \exp(-\gamma(h) \cdot d_{atm})$$
where $\gamma(h)$ is the altitude-dependent attenuation coefficient (combining Mie and Rayleigh scattering).

### 5.2. Optical Noise & SNR
Unlike RF systems where thermal noise dominates, optical receivers (PIN or APD photodiodes) are limited by shot noise and background solar illumination:
1. **Solar Background Noise**:
   $$P_{bg} = H_{sun}(\lambda) \cdot \Delta \lambda \cdot \left(\frac{\pi}{4} D_{rx}^2\right) \cdot \left(\frac{\pi}{4} \theta_{fov}^2\right) \cdot \eta_{rx} \quad [\text{W}]$$
   where $H_{sun}(\lambda)$ is the solar spectral irradiance ($\text{W/m}^2/\text{nm}$), $\Delta \lambda$ is the optical filter bandwidth, and $\theta_{fov}$ is the receiver field-of-view angle.
2. **Photocurrent SNR**:
   The electrical SNR at the output of the photodiode (responsivity $R$ in A/W, gain $M$, excess noise factor $F_A$) is:
   $$\text{SNR}_{elec} = \frac{(M \cdot R \cdot P_{rx})^2}{2 q B M^2 F_A (R P_{rx} + R P_{bg} + I_{dark}) + \frac{4 k_B T_e B}{R_L}}$$
   where $q$ is the electron charge, $B$ is the bandwidth, $I_{dark}$ is the dark current, and $R_L$ is the load resistance. This is fundamentally different from RF SINR.

### 5.3. Atmospheric Scintillation (Turbulence Fading)
For ground-to-space links, refractive index fluctuations cause amplitude scintillation. The scintillation index $\sigma_I^2$ (variance of intensity) for spherical waves is:
$$\sigma_I^2 = 1.23 C_n^2 k^{7/6} L^{11/6}$$
A scintillation fade margin $A_{fade}$ (in dB) must be included to achieve target outage probabilities (e.g., $99.9\%$ link availability):
$$A_{fade} \approx 10 \sqrt{\sigma_I^2} \quad [\text{dB}]$$

---

## 6. Actionable Remediations

### 6.1. Corrected RF SINR Equation
Implement the following comprehensive formula for RF links:
$$\text{SINR}_{RF} = \frac{P_i G_t(\theta_{tx}) G_r(\theta_{rx}) L_{pol} \left(\frac{c}{4 \pi f_{sig} d_{ij}}\right)^2 \frac{1}{L_{atm\_sig}}}{k_B T_{sys} B + \sum_{k} P_k G_{t\_inf}(\theta_{tx\_inf}) G_r(\theta_{rx\_inf}) L_{pol\_inf} \chi_k \left(\frac{c}{4 \pi f_{inf\_k} d_{kj}}\right)^2 \frac{1}{L_{atm\_inf\_k}}}$$

### 6.2. GPU (WGSL) Ray-Ellipsoid Occlusion Code
Integrate this exact, branch-optimized ray-ellipsoid occlusion algorithm into the compute shader:

```wgsl
struct Ellipsoid {
    center: vec3<f32>,
    inv_axes_sq: vec3<f32>, // Vector containing: (1/(a^2), 1/(b^2), 1/(c^2))
};

// Returns true if ray from start to end is occluded by the ellipsoid
fn check_ellipsoid_occlusion(start: vec3<f32>, end: vec3<f32>, body: Ellipsoid) -> bool {
    let r_start = start - body.center;
    let d = end - start;

    // A = d^T * M * d
    let A = dot(d * d, body.inv_axes_sq);
    
    // B = 2 * r_start^T * M * d
    let B = 2.0 * dot(r_start * d, body.inv_axes_sq);
    
    // C = r_start^T * M * r_start - 1.0
    let C = dot(r_start * r_start, body.inv_axes_sq) - 1.0;

    let discriminant = B * B - 4.0 * A * C;
    if (discriminant < 0.0) {
        return false; // No real roots, no intersection
    }

    let sqrt_disc = sqrt(discriminant);
    let t1 = (-B - sqrt_disc) / (2.0 * A);
    let t2 = (-B + sqrt_disc) / (2.0 * A);

    // Occluded if the intersection interval overlaps with the [0, 1] segment
    return (t1 <= 1.0) && (t2 >= 0.0);
}
```
