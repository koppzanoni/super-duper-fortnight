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
    assert manifest["hud_cap"]["w"] == 656
    assert manifest["hud_bar"]["w"] == 684
    assert (manifest["hud_connector"]["w"], manifest["hud_connector"]["h"]) == (333, 381)
    assert (tmp_path / "hud_cap.tga").exists()
    rt = new_runtime(with_stub=False)
    ns = rt.table()
    load_addon_file(rt, tmp_path / "manifest.lua", ns)
    lua_manifest = ns.MediaManifest
    assert lua_manifest["hud_cap"]["potW"] == 1024
    assert lua_manifest["inventory"]["h"] == 1334
    assert lua_manifest["mask_circle"]["w"] == 256
    assert lua_manifest["gem_on"]["file"] == "Interface\\AddOns\\ObsidianUI\\Media\\gem_on"


def test_vignette_dark_edge_clear_center():
    v = ex.vignette(128)
    assert v.getpixel((64, 64))[3] == 0
    assert v.getpixel((64, 2))[3] > 120
    assert v.getpixel((64, 2))[:3] == (0, 0, 0)


def test_ring_glow_peaks_near_rim():
    r = ex.ring_glow(128)
    assert r.getpixel((64, 64))[3] == 0
    rim = max(r.getpixel((64, y))[3] for y in range(0, 12))
    assert rim > 200


# In-game: the liquid looked smaller than the ring opening (dark band all around).
RING_OPENING = (66, 317, 52, 307)  # transparent hole in hud_cap: x0, x1, y0, y1


def test_orb_rect_tucks_under_the_ring_opening():
    rt = new_runtime()
    ns = load_addon_file(rt, "Core/Data.lua", rt.table())
    o = ns.Data.HUD.orb
    x0, x1, y0, y1 = RING_OPENING
    assert o.x <= x0 - 3 and o.x + o.w >= x1 + 4
    assert o.y <= y0 - 3 and o.y + o.h >= y1 + 4


def _radius_alpha(img, frac):
    a = np.asarray(img)[..., 3]
    c = (img.width - 1) / 2
    return int(a[int(c), int(c + frac * c)])


def test_vignette_only_darkens_the_rim():
    img = ex.vignette()
    assert _radius_alpha(img, 0.80) == 0
    assert _radius_alpha(img, 0.99) > 100


def test_liquid_body_is_bright_inside_the_circle():
    img = np.asarray(ex.liquid()).astype(float)
    size = img.shape[0]
    y, x = np.mgrid[0:size, 0:size]
    c = (size - 1) / 2
    inside = np.sqrt((x - c) ** 2 + (y - c) ** 2) < c * 0.95
    assert img[..., 0][inside].min() >= 0.45 * 255


# In-game: black triangles at the orb corners (the vignette was black outside the circle).
def test_vignette_clear_outside_the_circle():
    img = ex.vignette(128)
    assert img.getpixel((0, 0))[3] == 0
    assert img.getpixel((127, 127))[3] == 0


# In-game: a dark band of uneven width showed between the map and the ring. A thicker inner rim
# (stone with a bronze edge) drawn over the map's outer edge narrows the opening and hides it.
def test_map_rim_covers_the_map_edge():
    img = ex.map_rim(512)
    a = np.asarray(img)[..., 3]
    c = 255.5
    def alpha_at(frac):
        return int(a[int(c), int(c + frac * c)])
    assert alpha_at(0.0) == 0 and alpha_at(0.8) == 0       # map visible inside
    assert alpha_at(0.95) == 255                           # rim covers the edge band
    rgb = np.asarray(img)[int(c), int(c + 0.89 * c), :3]
    assert rgb[0] > rgb[2] + 40                             # bronze line at the inner edge


def test_minimap_draws_the_rim(lua=None):
    from conftest import new_runtime, toc_files
    rt = new_runtime()
    ns = rt.table()
    for f in toc_files():
        load_addon_file(rt, f, ns)
    rt.execute('STUB_FIRE("ADDON_LOADED", "ObsidianUI")')
    rt.execute('STUB_FIRE("PLAYER_LOGIN")')
    assert ns.Minimap.rim is not None
