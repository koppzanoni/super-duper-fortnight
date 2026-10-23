"""PoE2-style orb liquid: styles, palettes, flipbook playback, settings."""
import pytest

from conftest import load_pure


@pytest.fixture
def D(pure):
    return load_pure(pure, "Core/Data.lua").Data


def rgb255(c):
    return [round(c[i] * 255) for i in (1, 2, 3)]


def test_style_fallback(D):
    assert D.OrbStyle("b") == "b"
    assert D.OrbStyle(None) == "a" and D.OrbStyle("zzz") == "a"
    assert [D.ORB_STYLE_ORDER[i] for i in range(1, 5)] == ["a", "b", "c", "d"]
    assert D.ORB_STYLE_LABELS.d == "Parado"


def test_style_values_match_the_approved_preview(D):
    a, b, d = D.ORB_STYLES.a, D.ORB_STYLES.b, D.ORB_STYLES.d
    assert (a.sheet, a.fps, a.wisp, a.wisp2, a.spin, a.spin2) == ("fluid_a", 7, 0.62, 0.22, 0.05, -0.03)
    assert b.sparks and b.core == 0.5 and not a.sparks
    assert D.ORB_STYLES.c.sheet == "fluid_c" and D.ORB_STYLES.c.wisp2 == 0
    assert d.still and d.sheet == "fluid_a" and d.stillFrame == 21 and not a.still


def test_flipbook_coords(D):
    assert D.FlipbookCoords(0) == (0, 0.125, 0, 0.125)
    assert D.FlipbookCoords(9) == (0.125, 0.25, 0.125, 0.25)
    assert D.FlipbookCoords(63) == (0.875, 1, 0.875, 1)
    assert D.FlipbookCoords(64) == D.FlipbookCoords(0)


def test_health_and_mana_palettes_are_exact(D):
    h = D.OrbPalette("HEALTH")
    assert (rgb255(h.deep), rgb255(h.body), rgb255(h.wisp), rgb255(h.line)) == \
        ([12, 0, 2], [62, 2, 7], [230, 46, 30], [255, 150, 110])
    m = D.OrbPalette("MANA")
    assert (rgb255(m.deep), rgb255(m.body), rgb255(m.wisp), rgb255(m.line)) == \
        ([0, 3, 16], [5, 22, 80], [44, 130, 245], [170, 220, 255])


def test_other_power_palette_is_derived(D):
    p = D.OrbPalette("RAGE")  # ORB_COLORS.RAGE = 0.62, 0.08, 0.05
    assert abs(p.deep[1] - 0.62 * 0.08) < 1e-9 and abs(p.body[1] - 0.62 * 0.35) < 1e-9
    assert abs(p.wisp[1] - (0.62 + 0.38 * 0.10)) < 1e-9 and abs(p.line[1] - (0.62 + 0.38 * 0.55)) < 1e-9


# ---- Orbs (HUD/Orbs.lua) ----
from conftest import load_addon_file, toc_files  # noqa: E402

# Frames and textures record their setters (the plain stub returns stubs and keeps nothing).
RECORD = """
  local SETTERS = { "SetPoint", "ClearAllPoints", "SetClipsChildren", "SetTexCoord", "SetRotation",
    "SetAlpha", "SetVertexColor", "SetTexture", "SetBlendMode", "SetSize", "SetAllPoints",
    "SetStatusBarColor", "SetGradient" }
  local function instrument(o)
    o.last, o.points, o.shown = {}, {}, true
    for _, name in ipairs(SETTERS) do
      o[name] = function(self, ...)
        self.last[name] = { ... }
        if name == "SetPoint" then table.insert(self.points, { ... }) end
        if name == "ClearAllPoints" then self.points = {} end
      end
    end
    o.Show = function(self) self.shown = true end
    o.Hide = function(self) self.shown = false end
    o.SetShown = function(self, v) self.shown = v and true or false end
    local ct = o.CreateTexture
    o.CreateTexture = function(self, ...) local t = ct(self, ...); instrument(t); return t end
    return o
  end
  local cf = CreateFrame
  function CreateFrame(...) return instrument(cf(...)) end
"""


def boot(lua, ns, pre="", db=None):
    lua.execute(RECORD + pre)
    for f in toc_files():
        load_addon_file(lua, f, ns)
    lua.execute('STUB_FIRE("ADDON_LOADED", "ObsidianUI")')
    for k, v in (db or {}).items():
        ns.db[k] = v
    lua.execute('STUB_FIRE("PLAYER_LOGIN")')
    lua.execute('STUB_FIRE("PLAYER_ENTERING_WORLD")')
    return ns


def last(region, name):
    args = region.last[name]
    return tuple(args[i] for i in range(1, len(args) + 1))


def coords(ns, i):
    return tuple(ns.Data.FlipbookCoords(i))


def test_empty_part_is_transparent(lua, ns):
    boot(lua, ns)
    assert ns.Orbs.health.bg is None


def test_liquid_is_clipped_to_the_fill(lua, ns):
    boot(lua, ns)
    o = ns.Orbs.health
    assert last(o.clip, "SetClipsChildren") == (True,)
    lua.globals().O = o
    has = lua.eval("""function(point, rel)
      for _, p in ipairs(O.clip.points) do
        if p[1] == point and p[2] == O[rel] and p[3] == point then return true end
      end
      return false
    end""")
    assert has("TOPLEFT", "fill") and has("TOPRIGHT", "fill")
    assert has("BOTTOMLEFT", "well") and has("BOTTOMRIGHT", "well")


def test_step_plays_the_flipbook_with_crossfade(lua, ns):
    boot(lua, ns)
    ns.Orbs.SetStyle("a")
    o = ns.Orbs.health
    o.t = 0
    o.Step(o, 1.0)  # t = 1 s at 7 fps: frame 7, no blend yet
    w1, w2 = o.wisp[1], o.wisp[2]
    assert last(w1, "SetTexCoord") == coords(ns, 7) and last(w2, "SetTexCoord") == coords(ns, 8)
    assert last(w1, "SetAlpha") == (0.62,) and last(w2, "SetAlpha") == (0,)
    assert abs(last(w1, "SetRotation")[0] - 0.05) < 1e-9
    assert last(o.wisp2[1], "SetTexCoord") == coords(ns, 39)
    assert abs(last(o.wisp2[1], "SetRotation")[0] + 0.03) < 1e-9
    o.Step(o, 1 / 14)  # half a frame later: crossfade halfway
    assert abs(last(w1, "SetAlpha")[0] - 0.31) < 1e-6 and abs(last(w2, "SetAlpha")[0] - 0.31) < 1e-6


def test_still_style_has_no_onupdate_and_resumes(lua, ns):
    boot(lua, ns)
    ns.Orbs.SetStyle("d")
    o = ns.Orbs.health
    assert o.well.handlers.OnUpdate is None
    assert last(o.wisp[1], "SetTexCoord") == coords(ns, 21) and last(o.wisp[1], "SetAlpha") == (0.62,)
    assert last(o.wisp[2], "SetAlpha") == (0,)
    ns.Orbs.SetStyle("a")
    assert o.well.handlers.OnUpdate is not None


def test_sparks_only_in_energy_style(lua, ns):
    boot(lua, ns)
    o = ns.Orbs.power
    for style in ("b", "a", "b"):
        ns.Orbs.SetStyle(style)
    assert len(o.sparks) == 6 and all(s.shown for s in o.sparks.values())
    ns.Orbs.SetStyle("a")
    assert not any(s.shown for s in o.sparks.values())


def test_saved_style_applied_on_login_with_fallback(lua, ns):
    boot(lua, ns, db={"orbStyle": "zzz"})
    assert ns.Orbs.health.style == "a" and ns.Orbs.power.style == "a" and ns.db.orbStyle == "a"


def test_saved_style_is_used(lua, ns):
    boot(lua, ns, db={"orbStyle": "c"})
    assert ns.Orbs.health.style == "c" and ns.Orbs.power.style == "c"


def test_power_type_change_recolors_and_keeps_style(lua, ns):
    boot(lua, ns, pre='function UnitPowerType() return 1, "RAGE" end')
    ns.Orbs.SetStyle("c")
    lua.execute('STUB_FIRE("UNIT_DISPLAYPOWER", "player")')
    o = ns.Orbs.power
    wisp = ns.Data.OrbPalette("RAGE").wisp
    assert last(o.wisp[1], "SetVertexColor")[:3] == (wisp[1], wisp[2], wisp[3])
    assert o.style == "c"


def test_health_uses_the_health_palette(lua, ns):
    boot(lua, ns)
    o = ns.Orbs.health
    wisp, body = ns.Data.OrbPalette("HEALTH").wisp, ns.Data.OrbPalette("HEALTH").body
    assert last(o.wisp[1], "SetVertexColor")[:3] == (wisp[1], wisp[2], wisp[3])
    assert last(o.bar, "SetStatusBarColor")[:3] == (body[1], body[2], body[3])


# ---- Setting (Settings/Settings.lua) ----
SETTINGS_STUB = """
  DROPDOWNS, CALLBACKS = {}, {}
  local function setting(key)
    return { SetValueChangedCallback = function(self, fn) CALLBACKS[key] = fn end }
  end
  Settings = {
    RegisterVerticalLayoutCategory = function(name)
      return { GetID = function() return 1 end }, { AddInitializer = function() end }
    end,
    RegisterAddOnSetting = function(cat, variable, key, tbl, kind, label, default)
      local s = setting(key); s.kind, s.default, s.label = kind, default, label; return s
    end,
    CreateCheckbox = function() end,
    CreateSlider = function() end,
    CreateSliderOptions = function() return { SetLabelFormatter = function() end } end,
    CreateControlTextContainer = function()
      local c = { list = {} }
      function c:Add(value, label) table.insert(self.list, { value = value, label = label }) end
      function c:GetData() return self.list end
      return c
    end,
    CreateDropdown = function(cat, s, options, tooltip)
      table.insert(DROPDOWNS, { setting = s, options = options, tooltip = tooltip })
    end,
    RegisterAddOnCategory = function() end,
  }
  MinimalSliderWithSteppersMixin = { Label = { Right = 1 } }
"""


def test_style_dropdown_in_settings(lua, ns):
    boot(lua, ns, pre=SETTINGS_STUB)
    g = lua.globals()
    dd = g.DROPDOWNS[1]
    assert dd.setting.label == "Estilo dos orbes" and dd.setting.default == "a" and dd.setting.kind == "string"
    opts = dd.options()
    assert [(opts[i].value, opts[i].label) for i in range(1, 5)] == [
        ("a", "A — Redemoinho"), ("b", "B — Energia"), ("c", "C — Névoa"), ("d", "D — Parado")]
    assert dd.tooltip == "Como o líquido dos orbes de vida e recurso se mexe. D fica parado."
    got = []
    ns.Orbs.SetStyle = lambda key: got.append(key)
    g.CALLBACKS["orbStyle"](None, "c")
    assert got == ["c"]
