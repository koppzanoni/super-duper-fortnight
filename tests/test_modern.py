"""HUD style "Moderno" (docs/superpowers/specs/2026-10-23-hud-moderno-design.md)."""
import sys

from conftest import ROOT, load_addon_file, new_runtime, toc_files

sys.path.insert(0, str(ROOT / "tools"))
import export_textures as ex  # noqa: E402
import modern_art  # noqa: E402


def data():
    rt = new_runtime()
    return load_addon_file(rt, "Core/Data.lua", rt.table()).Data


def box(r):
    """A Data rect {x, y, w, h} as modern_art's (x0, y0, x1, y1)."""
    return (r.x, r.y, r.x + r.w, r.y + r.h)


def test_unit_spec_matches_the_art():
    s = data().MODERN_UNIT
    u = modern_art.UNIT
    assert (s.w, s.h) == (u["w"], u["h"])
    for key in ("portrait", "health", "power", "name", "level", "ring"):
        assert box(s[key]) == u[key], key


def test_cast_spec_matches_the_art():
    s = data().MODERN_CAST
    c = modern_art.CASTBAR
    assert (s.w, s.h) == (c["w"], c["h"])
    for key in ("icon", "bar", "name"):
        assert box(s[key]) == c[key], key


def test_minimap_spec_matches_the_art():
    s = data().MODERN_MAP
    m = modern_art.MAP
    assert (s.w, s.h) == (m["w"], m["h"])
    for key in ("hole", "plate", "button"):
        assert box(s[key]) == m[key], key


def test_modern_textures_are_exported(tmp_path):
    manifest = ex.export_all(tmp_path)
    for name in ("mod_unit", "mod_cast", "mod_slot", "mod_map", "mod_menu"):
        for color in ("", "_black"):
            assert name + color in manifest, name + color
    assert manifest["mod_unit"]["w"] == modern_art.UNIT["w"]
    assert "mod_arcane" in manifest and "mod_gloss" in manifest


def loaded(lua, ns, db=None):
    for f in toc_files():
        load_addon_file(lua, f, ns)
    lua.execute('STUB_FIRE("ADDON_LOADED", "ObsidianUI")')
    for k, v in (db or {}).items():
        ns.db[k] = v
    return ns


def test_stone_stays_the_default(lua, ns):
    loaded(lua, ns)
    assert ns.db.hudTheme == "obsidian"
    assert ns.db.modernColor == "black"
    assert ns.db.arcaneRing is True
    assert (ns.db.modernRows, ns.db.modernCols) == (2, 12)
