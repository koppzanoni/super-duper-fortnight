import sys

import numpy as np
from PIL import Image

from conftest import ROOT, load_addon_file, new_runtime

sys.path.insert(0, str(ROOT / "tools"))
import export_textures as ex  # noqa: E402


def test_pot_padding():
    img = Image.new("RGBA", (1346, 381), (10, 20, 30, 255))
    padded, w, h = ex.pad_pot(img)
    assert padded.size == (2048, 512)
    assert (w, h) == (1346, 381)
    assert padded.getpixel((2000, 500))[3] == 0


def test_defringe_removes_pink():
    img = Image.new("RGBA", (1, 1), (200, 40, 190, 128))
    r, g, b, a = ex.defringe(img).getpixel((0, 0))
    assert min(r, b) - g <= 10
    assert a == 128


def test_defringe_keeps_opaque_pixels():
    img = Image.new("RGBA", (1, 1), (200, 40, 190, 255))
    assert ex.defringe(img).getpixel((0, 0)) == (200, 40, 190, 255)


def test_mask_circle_alpha():
    m = ex.mask_circle(64)
    assert m.getpixel((32, 32))[3] == 255
    assert m.getpixel((0, 0))[3] == 0


def test_export_manifest(tmp_path):
    manifest = ex.export_all(tmp_path)
    assert (manifest["mod_unit"]["w"], manifest["mod_unit"]["h"]) == (720, 250)
    assert (tmp_path / "mod_unit.tga").exists()
    rt = new_runtime(with_stub=False)
    ns = rt.table()
    load_addon_file(rt, tmp_path / "manifest.lua", ns)
    lua_manifest = ns.MediaManifest
    assert lua_manifest["mod_unit"]["potW"] == 1024
    assert lua_manifest["inventory"]["h"] == 1334
    assert lua_manifest["mask_circle"]["w"] == 256
    assert lua_manifest["gem_on"]["file"] == "Interface\\AddOns\\ObsidianUI\\Media\\gem_on"


# In-game: the liquid looked smaller than the ring opening (dark band all around).
RING_OPENING = (66, 317, 52, 307)  # transparent hole in hud_cap: x0, x1, y0, y1


def _radius_alpha(img, frac):
    a = np.asarray(img)[..., 3]
    c = (img.width - 1) / 2
    return int(a[int(c), int(c + frac * c)])

