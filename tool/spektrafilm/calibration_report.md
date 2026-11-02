# Spektrafilm calibration report

Reference: upstream commit `3bb2c2d2801ff68b92019cf1dbcbb133d60832bc`
Python pipeline, default input/output gamut compression, DIR couplers on,
grain and spatial effects off.

Native engine: `third_party/spektrafilm_native`, same profiles, same patches
(linear ProPhoto gray ramp plus skin / sky / foliage / red / warm highlight /
teal shadow).

Each stock uses its target print paper, or negative direct scan when the
profile has no target print.

```
stock                            patches     mean      max  worst
fujifilm_velvia_100                   13   0.0039   0.0285  gray_0.02
kodak_verita_200d                     13   0.0026   0.0160  gray_0.02
kodak_vision3_500t                    13   0.0024   0.0156  teal_shadow
kodak_vision3_250d                    13   0.0024   0.0156  teal_shadow
kodak_vision3_200t                    13   0.0024   0.0152  teal_shadow
kodak_ektachrome_100                  13   0.0018   0.0149  teal_shadow
kodak_vision3_50d                     13   0.0024   0.0141  teal_shadow
fujifilm_pro_400h                     13   0.0016   0.0100  teal_shadow
fujifilm_provia_100f                  13   0.0012   0.0097  teal_shadow
fujifilm_xtra_400                     13   0.0017   0.0094  teal_shadow
kodak_portra_800_push2                13   0.0015   0.0086  foliage
fujifilm_c200                         13   0.0016   0.0084  teal_shadow
kodak_portra_800_push1                13   0.0014   0.0071  foliage
kodak_ektar_100                       13   0.0011   0.0055  foliage
kodak_portra_400                      13   0.0011   0.0050  foliage
kodak_gold_200                        13   0.0011   0.0044  foliage
kodak_ultramax_400                    13   0.0011   0.0040  foliage
kodak_portra_800                      13   0.0011   0.0039  foliage
kodak_portra_160                      13   0.0011   0.0036  foliage
kodak_kodachrome_64                   13   0.0012   0.0031  foliage

overall max 0.0285  mean 0.0017  stocks 20  rows 260
```

Residuals are dominated by the baked CAM16-UCS compression LUT in the darkest
patches (final RGB below 0.05), where relative resolution is coarsest.
