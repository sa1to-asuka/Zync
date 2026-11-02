# spektrafilm_native

Standalone spectral film engine used by Zync. It implements the physical
pipeline of the upstream Spektrafilm project for Android.

- Upstream: https://github.com/andreavolpato/spektrafilm
- Pinned commit: `3bb2c2d2801ff68b92019cf1dbcbb133d60832bc` (0.3.4)
- Code license: GPL-3.0 (see `LICENSE`)
- Spectral profiles and LUTs: CC BY-SA 4.0 (see `SPEKTRAFILM_LICENSE.txt`)
- Attribution: "Derived from spektrafilm by Andrea Volpato
  (https://github.com/andreavolpato/spektrafilm), licensed CC BY-SA 4.0."

## What is ported

The native stages follow the upstream reference implementation:

1. **Filming**
   - scene-linear ProPhoto RGB to film raw exposure through the Hanatos 2025
     spectral upsampling LUT, including the per-profile spectral window
     normalization;
   - exposure compensation;
   - in-emulsion scatter (Gaussian core plus exponential tail mixture) and
     multi-bounce halation with the upstream material presets;
   - log10 exposure.
2. **Development**
   - tabulated characteristic density curves per layer;
   - DIR couplers with layer coupling matrix, Gaussian plus exponential-tail
     spatial diffusion, and re-exposure through the pre-coupler curves;
   - density-driven silver-halide grain.
3. **Printing**
   - the film dye densities are projected through the enlarger illuminant,
     dichroic C/M/Y filters and the per-film/paper neutral filter database
     onto the paper layer sensitivities;
   - midgray exposure normalization;
   - the paper density-curve CDF model.
4. **Scanning**
   - density to XYZ through the viewing illuminant and CIE 1931 observer;
   - chromatic adaptation to the output white point;
   - sRGB encoding.

`Settings::scanFilm` reproduces the upstream negative-scan mode.

## RAW input

For RAW exports the app calls LibRaw with `output_color = ProPhoto`,
`gamm = 1`, `no_auto_bright = 1` and 16-bit output, writing a linear
ProPhoto RGB cache. `nativeRenderRaw` feeds those values directly to the
engine, so the simulation sees scene-linear data instead of an sRGB JPEG.
JPEG previews still go through the sRGB entry point.

## Known deviations

- Grain uses the single-layer particle model. The upstream optional
  three-sublayer dye-cloud grain is not ported yet.
- Output gamut compression approximates the upstream CAM16-UCS chroma and
  lightness compression with a perceptual highlight roll-off. In-gamut
  colors are unchanged.
- Camera / enlarger diffusion filters and print glare are not applied.
- Auto exposure is off by default; exposure is user controlled.
- The print and scanner stages use 33³ LUTs instead of direct 81-band
  evaluation. Reference tests keep the error below 1e-3 in RGB for the
  calibrated gray ramp.

## Data

`data/` contains unmodified upstream profile JSON files plus:

- `irradiance_xy_tc.npy` (upstream float16 spectral upsampling LUT);
- `neutral_print_filters.json`;
- `spectral_constants.json` generated once from upstream
  `colour`-computed CMFs, illuminants, dichroic filters and the Schott KG3
  curve. Values are exported as-is;
- `raw_luts/<stock>.bin`: per-film 192×192×3 float32 Hanatos 2025 LUTs baked
  with `compute_hanatos2025_tc_lut`, including the default input gamut
  compression, exactly as the upstream runtime builds them;
- `output_gamut_srgb.bin` + `.json`: the upstream CAM16-UCS output gamut
  compression (chroma knee plus lightness compression) baked as an
  81³ float32 LUT over linear sRGB in [-0.1, 1.5] with cube-root node spacing.
  The native engine samples it trilinearly instead of reimplementing CAM16.

`CHANGELOG.txt` records the format-only changes.

## Calibration

`tool/spektrafilm/reference_calibration.py` runs the upstream pipeline for
all 20 film profiles on 13 linear ProPhoto patches (gray ramp plus skin, sky,
foliage, red, warm highlight and teal shadow), each with its target print or
negative-scan mode.

`tests/calibrate_dump.cpp` prints the native engine's log exposure, film
density, print density and final RGB for the same patches.
`tool/spektrafilm/compare_calibration.py` reports per-stock error.

Result after the LUT baking: mean absolute RGB error 0.0017, per-stock maximum
0.003–0.029, with the largest residuals in the darkest patches (values below
0.05) where the baked CAM16 compression has the coarsest relative resolution.

Halation and scatter are calibrated separately against
`apply_halation_um` on a synthetic highlight scene
(`tool/spektrafilm/reference_halation.py` / `tests/halation_dump.cpp`).
After switching large-sigma blurs to the upstream Young–van Vliet IIR path,
every case (strong / weak / cine presets, user amount and radius, scatter-only,
halation-only) matches the reference within 1.3e-4 in log exposure, which is
the float32-vs-float64 baseline. See `tool/spektrafilm/halation_report.md`.


## Build

The library is built by the app's CMake project:

```
android/app/src/main/cpp/CMakeLists.txt -> target spektrafilm
```

It has no dependency on LibRaw or other app native libraries.

## Reference validation

`tests/color_convert_test.cpp` pins `Engine::srgbToProPhoto` against reference
values (sRGB → linear → XYZ D65 → Bradford D50 → linear ProPhoto), and
`tests/srgb_pipeline_test.cpp` checks that an sRGB gradient survives the whole
pipeline with normal contrast instead of collapsing to white.

`tool/spektrafilm/reference_stages.py` runs the upstream Python pipeline and
prints per-stage values. `tests/stage_test.cpp` prints the same stages from
this engine. For Kodak Portra 400 + Portra Endura on four gray samples the
stages agree within ~1e-3, and the final sRGB values agree within ~0.001.
