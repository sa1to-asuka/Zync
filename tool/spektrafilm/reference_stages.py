import sys
import types

import numpy as np

REFERENCE = r"R:\third_party"
sys.path.insert(0, REFERENCE + r"\reference-env")
sys.path.insert(0, REFERENCE + r"\spektrafilm-upstream\src")

# Optional GUI / RAW / acceleration modules that are not needed for the
# numerical reference run.
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

try:
    import skimage  # noqa: F401
except ImportError:
    skimage = types.ModuleType("skimage")
    transform = types.ModuleType("skimage.transform")
    def rescale(image, scale, channel_axis=None, order=1):
        return image
    transform.rescale = rescale
    skimage.transform = transform
    sys.modules["skimage"] = skimage
    sys.modules["skimage.transform"] = transform

from spektrafilm.runtime.pipeline import SimulationPipeline
from spektrafilm.runtime.params_builder import digest_params, init_params


def build(film="kodak_portra_400", paper="kodak_portra_endura"):
    params = init_params(film_profile=film, print_profile=paper)
    params.settings.preview_mode = False
    params.debug.deactivate_spatial_effects = True
    params.debug.deactivate_stochastic_effects = True
    params.camera.auto_exposure = False
    params.film_render.grain.active = False
    params.film_render.dir_couplers.active = not __import__("os").environ.get("NO_DIR")
    return digest_params(params)


def main():
    params = build()
    pipeline = SimulationPipeline(params)
    film_stage = pipeline._filming_stage

    rows = [0.02, 0.184, 0.5, 1.0]
    image = np.zeros((len(rows), 1, 3))
    for i, value in enumerate(rows):
        image[i, :, :] = value

    log_exposure = film_stage.expose(image)
    density = film_stage.develop(log_exposure)
    print_stage = pipeline._printing_stage
    print_log = print_stage.expose(density)
    print_density = print_stage.develop(print_log)
    scan_stage = pipeline._scanning_stage
    cmy_to_xyz = scan_stage._return_callable_cmy_to_log_xyz()
    xyz_values = 10 ** cmy_to_xyz(print_density)
    rgb = scan_stage.scan(print_density)
    for i, value in enumerate(rows):
        le = log_exposure[i, 0]; d = density[i, 0]
        pl = print_log[i, 0]; pd = print_density[i, 0]; c = rgb[i, 0]
        xv = xyz_values[i,0]
        print(f"XYZ {xv[0]:.5f} {xv[1]:.5f} {xv[2]:.5f}")
        print(f"{value:.3f} | logE {le[0]:.5f} {le[1]:.5f} {le[2]:.5f} | D {d[0]:.5f} {d[1]:.5f} {d[2]:.5f} | pLog {pl[0]:.5f} {pl[1]:.5f} {pl[2]:.5f} | pD {pd[0]:.5f} {pd[1]:.5f} {pd[2]:.5f} | RGB {c[0]:.5f} {c[1]:.5f} {c[2]:.5f}")

    # Neutral enlarger filters actually selected.
    print("neutral filters:", params.enlarger.c_filter_neutral,
          params.enlarger.m_filter_neutral, params.enlarger.y_filter_neutral)


if __name__ == "__main__":
    main()
