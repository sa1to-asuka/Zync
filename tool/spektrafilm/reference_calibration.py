"""Dump the upstream Spektrafilm result for every profile on the shared
calibration patches. Run with the isolated reference environment:

    python -I R:/Zync/tool/spektrafilm/reference_calibration.py
"""

import json
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

from spektrafilm.profiles.io import list_profiles
from spektrafilm.utils.gamut_compression import (
    InputGamutCompressSpec,
    OutputGamutCompressSpec,
)
from spektrafilm.runtime.params_builder import digest_params, init_params
from spektrafilm.runtime.pipeline import SimulationPipeline

PATCHES = json.loads((ROOT / "tool/spektrafilm/calibration_patches.json").read_text(encoding="utf-8"))["patches"]
DEFAULT_PRINT = "kodak_portra_endura"


def main():
    rows = []
    for stock in list_profiles():
        params = init_params(film_profile=stock, print_profile=DEFAULT_PRINT)
        info = params.film.info
        if info.stage != "filming" or info.support != "film":
            continue
        target = info.target_print or ""
        scan = not bool(target)
        paper = target or DEFAULT_PRINT
        if target:
            params = init_params(film_profile=stock, print_profile=target)
        params.io.scan_film = scan
        params.settings.preview_mode = False
        params.debug.deactivate_spatial_effects = True
        params.debug.deactivate_stochastic_effects = True
        params.camera.auto_exposure = False
        params.film_render.grain.active = False
        params.film_render.dir_couplers.active = True
        import os
        if os.environ.get("NO_INPUT_COMPRESS"):
            params.io.input_gamut_compress = InputGamutCompressSpec(active=False)
        if os.environ.get("NO_OUTPUT_COMPRESS"):
            params.io.output_gamut_compress = OutputGamutCompressSpec(algorithm="off")
        params = digest_params(params)
        pipeline = SimulationPipeline(params)
        for patch in PATCHES:
            image = np.array([[patch["rgb"]]], dtype=float)
            try:
                log_exposure = pipeline._filming_stage.expose(image)
                density = pipeline._filming_stage.develop(log_exposure)
                if scan:
                    print_density = density
                else:
                    print_log = pipeline._printing_stage.expose(density)
                    print_density = pipeline._printing_stage.develop(print_log)
                out = pipeline._scanning_stage.scan(print_density)[0, 0]
                rows.append({
                    "stock": stock,
                    "paper": paper,
                    "scan": scan,
                    "patch": patch["name"],
                    "loge": [round(float(v), 6) for v in log_exposure[0, 0]],
                    "density": [round(float(v), 6) for v in density[0, 0]],
                    "pdensity": [round(float(v), 6) for v in print_density[0, 0]],
                    "rgb": [round(float(v), 6) for v in out],
                })
            except Exception as error:  # noqa: BLE001
                rows.append({
                    "stock": stock,
                    "paper": paper,
                    "scan": scan,
                    "patch": patch["name"],
                    "error": str(error),
                })
    out_path = ROOT / "tool/spektrafilm/reference_calibration.json"
    out_path.write_text(json.dumps({"rows": rows}, indent=1), encoding="utf-8")
    print(f"wrote {out_path} ({len(rows)} rows)")


if __name__ == "__main__":
    main()
