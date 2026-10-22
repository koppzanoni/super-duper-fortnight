import sys

import numpy as np
from PIL import Image

from conftest import ROOT, new_runtime

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
    lua_manifest = rt.execute((tmp_path / "manifest.lua").read_text(encoding="utf-8"))
    assert lua_manifest["hud_cap"]["potW"] == 1024
    assert lua_manifest["inventory"]["h"] == 1334
    assert lua_manifest["mask_circle"]["w"] == 256
    assert lua_manifest["gem_on"]["file"] == "Interface\\AddOns\\ObsidianUI\\Media\\gem_on"
