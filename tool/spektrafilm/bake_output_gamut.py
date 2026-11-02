"""Bake the upstream output gamut compression (CAM16-UCS, sRGB) into a
float32 3D LUT for the native engine.

    python -I R:/Zync/tool/spektrafilm/bake_output_gamut.py
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

from spektrafilm.utils.gamut_compression import (
    OutputGamutCompressSpec,
    compress_rgb,
)

SIZE = 81
MINIMUM = -0.1
MAXIMUM = 1.5


def main():
    spec = OutputGamutCompressSpec()
    # Cube-root spaced nodes concentrate resolution on dark values where the
    # CAM16 compression curves most; linear spacing leaves visible error there.
    axis = np.linspace(0.0, 1.0, SIZE) ** 3 * (MAXIMUM - MINIMUM) + MINIMUM
    r, g, b = np.meshgrid(axis, axis, axis, indexing="ij")
    grid = np.stack((r, g, b), axis=-1)
    compressed = compress_rgb(grid, spec, output_color_space="sRGB")
    out = ROOT / "third_party/spektrafilm_native/data/output_gamut_srgb.bin"
    np.asarray(compressed, dtype="<f4").tofile(out)
    header = {
        "size": SIZE,
        "min": MINIMUM,
        "max": MAXIMUM,
        "algorithm": spec.algorithm,
        "knee": list(spec.knee),
        "lightness_compression": list(spec.lightness_compression or []),
        "mapping": "cbrt",
    }
    (out.with_suffix(".json")).write_text(json.dumps(header, indent=2), encoding="utf-8")
    print(f"wrote {out} ({out.stat().st_size} bytes)")
    # Sanity: identity-ish in the interior for neutral values.
    print("check mid gray:", compress_rgb(np.array([[[0.184, 0.184, 0.184]]]), spec, output_color_space="sRGB")[0, 0])
    print("check white:", compress_rgb(np.array([[[1.0, 1.0, 1.0]]]), spec, output_color_space="sRGB")[0, 0])


if __name__ == "__main__":
    main()
