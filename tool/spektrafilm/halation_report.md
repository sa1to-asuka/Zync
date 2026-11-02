# Spektrafilm halation calibration

Scene: 257×257 linear ProPhoto image, 5×5 highlight (value 3.0) on a 0.02
background, 8.0 µm pixel size. Compared after the full filming stage
(spectral upsampling + scatter + halation), in log10 exposure.

Reference: upstream `apply_halation_um` at commit `3bb2c2d2`.
Native: `third_party/spektrafilm_native/tests/halation_dump.cpp`.

Cases isolate the two passes:

- `scatter_only`: in-emulsion scatter with halation strength 0.
- `halation_only`: scatter disabled, strength preset 0.30 / 0.10 / 0.015.
- `no_preset`, `strong`, `weak`, `cine`: profile presets and user amount/scale.

| case | mean abs log-exposure error | max |
|---|---|---|
| cine_1.0_1.0 | 0.000126 | 0.000127 |
| halation_only | 0.000130 | 0.000133 |
| no_preset | 0.000129 | 0.000133 |
| off | 0.000127 | 0.000127 |
| scatter_only | 0.000128 | 0.000133 |
| strong_1.0_1.0 | 0.000128 | 0.000133 |
| strong_1.0_2.0 | 0.000128 | 0.000133 |
| strong_2.0_1.0 | 0.000128 | 0.000133 |
| weak_1.0_1.0 | 0.000118 | 0.000120 |

The residual equals the baseline `off` difference (1.3e-4, float32 vs float64),
i.e. the halation and scatter model matches the reference within numeric
precision.

The fix that closed the gap: the native Gaussian now follows the upstream
dispatch — Young–van Vliet IIR for σ ≥ 3 px instead of a truncated FIR kernel,
which had been losing the long tail of the exponential scatter/halation PSF.
