import json
import pathlib
import sys
import types

ROOT = pathlib.Path(__file__).resolve().parents[2]
REFERENCE = ROOT.parent / "third_party"
sys.path.insert(0, str(REFERENCE / "reference-env"))
sys.path.insert(0, str(REFERENCE / "spektrafilm-upstream" / "src"))
package = types.ModuleType("spektrafilm")
package.__path__ = [str(REFERENCE / "spektrafilm-upstream" / "src" / "spektrafilm")]
sys.modules["spektrafilm"] = package
for name in ["spektrafilm.utils", "spektrafilm.model", "spektrafilm.runtime"]:
    module = types.ModuleType(name)
    module.__path__ = [
        str(REFERENCE / "spektrafilm-upstream" / "src" / name.replace(".", "/"))
    ]
    sys.modules[name] = module
sys.modules["exiv2"] = types.ModuleType("exiv2")
sys.modules["rawpy"] = types.ModuleType("rawpy")
sys.modules["lensfunpy"] = types.ModuleType("lensfunpy")
sys.modules["OpenImageIO"] = types.ModuleType("OpenImageIO")
sys.modules["OpenImageIO"].ImageSpec = type("ImageSpec", (), {})
sys.modules["OpenImageIO"].ImageInput = type("ImageInput", (), {})
sys.modules["OpenImageIO"].ImageOutput = type("ImageOutput", (), {})
sys.modules["OpenImageIO"].ImageBuf = type("ImageBuf", (), {})
sys.modules["OpenImageIO"].ImageBufAlgo = type("ImageBufAlgo", (), {})
sys.modules["OpenImageIO"].OpenImageIOError = Exception
for key in [
    "DOUBLE", "FLOAT", "HALF", "UINT8", "UINT16", "INT8", "INT16",
    "UINT32", "INT32", "STRING", "TypeDesc", "ROI", "UNKNOWN",
]:
    setattr(sys.modules["OpenImageIO"], key, 0)
sys.modules["pyconify"] = types.ModuleType("pyconify")
sys.modules["opt_einsum"] = types.ModuleType("opt_einsum")
sys.modules["opt_einsum"].contract = __import__("numpy").einsum
sys.modules["numba"] = types.ModuleType("numba")
sys.modules["numba"].njit = lambda *args, **kwargs: (
    args[0] if args and callable(args[0]) else (lambda fn: fn)
)
sys.modules["numba"].prange = range

from spektrafilm.config import STANDARD_OBSERVER_CMFS
from spektrafilm.model.color_filters import (
    custom_dichroic_filters,
    schott_kg3_heat_filter,
)
from spektrafilm.model.illuminants import standard_illuminant

out = ROOT / "third_party" / "spektrafilm_native" / "data"
payload = {
    "wavelengths": [380 + 5 * i for i in range(81)],
    "cmfs": STANDARD_OBSERVER_CMFS[:].tolist(),
    "dichroics": custom_dichroic_filters.filters.tolist(),
    "kg3": schott_kg3_heat_filter.transmittance.tolist(),
    "illuminants": {
        key: standard_illuminant(key).tolist()
        for key in ["D50", "D55", "D65", "T", "K75P", "TH-KG3"]
    },
}
(out / "spectral_constants.json").write_text(
    json.dumps(payload, separators=(",", ":"))
)
print("Generated exact upstream constants")
