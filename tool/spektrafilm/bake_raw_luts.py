"""Bake the per-film Hanatos 2025 spectral LUTs exactly as the upstream
runtime builds them (including the default input gamut compression).

    python -I R:/Zync/tool/spektrafilm/bake_raw_luts.py
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

from spektrafilm.profiles.io import list_profiles, load_profile
from spektrafilm.utils.spectral_upsampling import compute_hanatos2025_tc_lut
from spektrafilm.utils.gamut_compression import InputGamutCompressSpec


def main():
    out_dir = ROOT / "third_party/spektrafilm_native/data/raw_luts"
    out_dir.mkdir(parents=True, exist_ok=True)
    compression = InputGamutCompressSpec()
    count = 0
    for stock in list_profiles():
        profile = load_profile(stock)
        if profile.info.stage != "filming" or profile.info.support != "film":
            continue
        sensitivity = 10 ** np.asarray(profile.data.log_sensitivity)
        adaptation = profile.hanatos2025_adaptation()
        adaptation.apply_window = True
        adaptation.apply_surface = False
        lut = compute_hanatos2025_tc_lut(
            sensitivity, adaptation, gamut_compress=compression
        )
        np.asarray(lut, dtype="<f4").tofile(out_dir / f"{stock}.bin")
        count += 1
        print(f"baked {stock} {lut.shape}")
    print(f"wrote {count} LUTs to {out_dir}")


if __name__ == "__main__":
    main()
