"""Dump the upstream halation-exposed log exposure for the shared test scene.

    python -I R:/Zync/tool/spektrafilm/reference_halation.py
"""

import pathlib
import sys
import types

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
REFERENCE = ROOT.parent / "third_party"
sys.path.insert(0, str(REFERENCE / "reference-env"))
sys.path.insert(0, str(REFERENCE / "spektrafilm-upstream" / "src"))

for name in ["exiv2", "rawpy", "lensfunpy", "pyconify"]:
    sys.modules[name] = types.ModuleType(name)
oiio = types.ModuleType("OpenImageIO")
for attr in ["ImageSpec", "ImageInput", "ImageOutput", "ImageBuf", "ImageBufAlgo"]:
    setattr(oiio, attr, type(attr, (), {}))
for attr in ["DOUBLE", "FLOAT", "HALF", "UINT8", "UINT16", "INT8", "INT16",
             "UINT32", "INT32", "STRING", "TypeDesc", "ROI", "UNKNOWN"]:
    setattr(oiio, attr, 0)
oiio.OpenImageIOError = Exception
sys.modules["OpenImageIO"] = oiio

import opt_einsum
sys.modules["opt_einsum"] = opt_einsum

try:
    import numba  # noqa: F401
except ImportError:
    numba = types.ModuleType("numba")
    def njit(*args, **kwargs):
        if args and callable(args[0]):
            return args[0]
        return lambda fn: fn
    numba.njit = njit
    numba.prange = range
    sys.modules["numba"] = numba

from spektrafilm.runtime.params_builder import digest_params, init_params
from spektrafilm.runtime.pipeline import SimulationPipeline

# (id, stock, amount, scale, strength override, sigma override, scatter override)
CASES = [
    ("strong_1.0_1.0", "kodak_portra_400", 1.0, 1.0, None, None, None),
    ("strong_2.0_1.0", "kodak_portra_400", 2.0, 1.0, None, None, None),
    ("strong_1.0_2.0", "kodak_portra_400", 1.0, 2.0, None, None, None),
    ("weak_1.0_1.0", "kodak_gold_200", 1.0, 1.0, None, None, None),
    ("cine_1.0_1.0", "kodak_vision3_500t", 1.0, 1.0, None, None, None),
    ("no_preset", "kodak_portra_400", 1.0, 1.0, (0.30, 0.10, 0.015), 65.0, None),
    ("off", "kodak_portra_400", 0.0, 1.0, None, None, None),
    ("scatter_only", "kodak_portra_400", 1.0, 1.0, (0.0, 0.0, 0.0), 65.0, None),
    ("halation_only", "kodak_portra_400", 1.0, 1.0, (0.30, 0.10, 0.015), 65.0, 0.0),
]
SIZE = 257
SPOT = 5
BACKGROUND = 0.02
SPOT_VALUE = 3.0
PIXEL_SIZE_UM = 8.0


def build_image():
    image = np.full((SIZE, SIZE, 3), BACKGROUND, dtype=float)
    image[128:128 + SPOT, 128:128 + SPOT, :] = SPOT_VALUE
    return image


def main():
    image = build_image()
    rows = []
    for case_id, stock, amount, scale, strength, sigma, scatter in CASES:
        params = init_params(film_profile=stock, print_profile="kodak_portra_endura")
        params.settings.preview_mode = False
        params.debug.deactivate_spatial_effects = False
        params.debug.deactivate_stochastic_effects = True
        params.camera.auto_exposure = False
        params.camera.film_format_mm = PIXEL_SIZE_UM * SIZE / 1000.0
        params = digest_params(params)
        params.film_render.halation.active = amount > 0
        params.film_render.halation.halation_amount = amount
        params.film_render.halation.halation_spatial_scale = scale
        if strength is not None:
            params.film_render.halation.halation_strength = strength
            params.film_render.halation.halation_first_sigma_um = (sigma, sigma, sigma)
        if scatter is not None:
            params.film_render.halation.scatter_amount = scatter
        pipeline = SimulationPipeline(params)
        preprocessed = pipeline._preprocess(image)
        log_exposure = pipeline._filming_stage.expose(preprocessed)
        for y in range(113, 144):
            for x in range(113, 144):
                value = log_exposure[y, x]
                rows.append(
                    f"{case_id}\t{x}\t{y}\t{value[0]:.8f}\t{value[1]:.8f}\t{value[2]:.8f}"
                )
    out = ROOT / "tool/spektrafilm/reference_halation.tsv"
    out.write_text("\n".join(rows) + "\n", encoding="utf-8")
    print(f"wrote {out} ({len(rows)} rows)")


if __name__ == "__main__":
    main()
