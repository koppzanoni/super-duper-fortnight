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
    for key in ("hole", "plate"):
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


# ------------------------------------------------------------------ action bar grid
import preview_render  # noqa: E402


def preview(db=None, vbars=False):
    rt = preview_render.run_addon(vbars=vbars, db=db)
    return rt, rt.globals().PREVIEW_NS


def rect(region):
    return tuple(region.Rect(region).values())


MODERN = {}


def test_bar_geometry(pure):
    from conftest import load_pure
    L = load_pure(pure, "Core/Layout.lua").Layout
    g = L.ModernBar(1080, 1, 2, 12)
    assert (g.slot, g.gap, g.numbers, g.bottom) == (54, 7, 18, L.MARGIN)  # the screen margin
    assert g.width == 12 * 54 + 11 * 7 and g.height == 18 + 2 * 54 + 7
    assert L.ModernBar(1080, 1, 4, 18).rows == 2               # 36 buttons at most
    small = L.ModernBar(1080, 0.5, 3, 4)
    assert small.slot == 27 and small.height == 9 + 3 * 27 + 2 * 3.5


def test_modern_bar_is_a_grid_in_reading_order():
    _, ns = preview(MODERN)
    b = ns.ActionBars.buttons
    row1 = [rect(b[i]) for i in range(1, 13)]
    row2 = [rect(b[i]) for i in range(19, 31)]
    assert len({round(r[1]) for r in row1}) == 1 and len({round(r[1]) for r in row2}) == 1
    assert row1[0][1] > row2[0][1]                            # main bar on top
    steps = {round(row1[i + 1][0] - row1[i][0], 1) for i in range(11)}
    assert steps == {54 + 7}
    # centered at the bottom of the screen
    left, right = row1[0][0], row1[-1][0] + row1[-1][2]
    assert abs((left + right) / 2 - 960) < 1


def test_buttons_outside_the_grid_are_hidden_and_unbound():
    _, ns = preview(MODERN)
    b = ns.ActionBars.buttons
    for i in list(range(13, 19)) + list(range(31, 37)):
        assert b[i].obEnabled is False and not b[i].IsVisible(b[i]), i
    for i in list(range(1, 13)) + list(range(19, 31)):
        assert b[i].obEnabled is True and b[i].IsVisible(b[i]), i


def test_rows_and_columns_come_from_the_settings():
    _, ns = preview({"modernRows": 3, "modernCols": 12})
    b = ns.ActionBars.buttons
    assert all(b[i].obEnabled for i in range(1, 37))
    assert rect(b[13])[1] < rect(b[19])[1]                    # bottom left bar is the third row


def test_slots_have_frames_in_the_chosen_colour():
    _, ns = preview(MODERN)
    slot = ns.ActionBars.buttons[1].obModernSlot
    assert slot.IsVisible(slot) and str(slot.file).endswith("mod_slot_black")
    _, ns = preview({"modernColor": "blue"})
    assert str(ns.ActionBars.buttons[1].obModernSlot.file).endswith("mod_slot")


def test_key_numbers_sit_above_the_first_row():
    _, ns = preview(MODERN)
    b = ns.ActionBars.buttons[1]
    hk = b.HotKey
    assert hk.points[1].point == "BOTTOM" and hk.points[1].relPoint == "TOP"


# ------------------------------------------------------------------ the rest of the stone HUD
def visible(region):
    return bool(region.IsVisible(region))


def test_xp_bar_runs_under_the_action_bar():
    _, ns = preview(MODERN)
    bar = rect(ns.ActionBars.modernFrame)
    xp = rect(ns.XPBar.xp)
    assert xp[1] + xp[3] <= bar[1]                            # below the slots
    # as wide as the slots' visible frames: from the first button's edge to the last one's
    buttons = [rect(b) for b in ns.ActionBars.buttons.values() if visible(b)]
    left = min(r[0] for r in buttons)
    right = max(r[0] + r[2] for r in buttons)
    assert abs(xp[0] - (left - 1)) < 1 and abs(xp[0] + xp[2] - (right + 1)) < 1


def test_menu_is_one_row_at_the_bottom_right():
    _, ns = preview(MODERN)
    shown = [ns.MenuPanels.byId[i] for i in ns.Data.MODERN_MENU.values()]
    rects = [rect(b) for b in shown]
    assert all(visible(b) for b in shown)
    assert len({round(r[1]) for r in rects}) == 1             # one row
    assert all(rects[i + 1][0] > rects[i][0] for i in range(len(rects) - 1))
    assert rects[-1][0] + rects[-1][2] <= 1920 and rects[0][0] > 1300
    assert not visible(ns.MenuPanels.byId["bag1"])
    assert visible(ns.MenuPanels.band) and str(ns.MenuPanels.band.file).endswith("mod_menu_black")


def test_menu_row_is_centred_in_its_band():
    _, ns = preview(MODERN)
    band = rect(ns.MenuPanels.bandFrame)
    shown = [rect(ns.MenuPanels.byId[i]) for i in ns.Data.MODERN_MENU.values()]
    left = shown[0][0] - band[0]
    right = band[0] + band[2] - (shown[-1][0] + shown[-1][2])
    assert abs(left - right) < 0.5


def test_nothing_in_the_art_is_cut_by_its_texture_edge():
    """The level circle under the portrait ring (and its rim) stays inside the unit frame
    texture; the minimap ring stays inside its texture. Only the faint tail of a soft shadow
    may reach an edge."""
    import numpy as np
    faint = 32
    for art in (modern_art.unit_frame(), modern_art.minimap_ring(), modern_art.cast_bar()):
        a = np.asarray(art)[..., 3]
        assert max(a[:2].max(), a[-2:].max(), a[:, :2].max(), a[:, -2:].max()) < faint


def test_minimap_is_round_and_its_name_centred_over_it():
    m = modern_art.MAP
    x0, y0, x1, y1 = m["hole"]
    assert x1 - x0 == y1 - y0                                 # a square opening: the map is not squashed
    px0, _, px1, _ = m["plate"]
    assert (px0 + px1) / 2 == (x0 + x1) / 2


# ------------------------------------------------------------------ unit frames
def frames(ns):
    return ns.UnitFrames.frames


def test_player_top_left_target_beside_it_mirrored():
    _, ns = preview(MODERN)
    p, t = frames(ns).player, frames(ns).target
    pr, tr = rect(p), rect(t)
    assert pr[0] < 40 and pr[1] + pr[3] > 1040                # top left
    assert tr[0] > pr[0] + pr[2] and abs(tr[1] - pr[1]) < 1   # beside it, same height
    tc = list(t.art.tc.values())
    assert tc[0] > tc[1]                                      # art flipped
    assert rect(t.portrait)[0] > rect(t.health)[0]            # portrait on the right
    assert t.health.reverse                                   # fills from the portrait side


def test_bars_start_at_the_ring_edge():
    _, ns = preview(MODERN)
    p = frames(ns).player
    ring_right = rect(p.portrait)[0] + rect(p.portrait)[2]
    assert rect(p.health)[0] >= ring_right - 1


def test_target_of_target_small_under_the_target_portrait():
    _, ns = preview(MODERN)
    t, tot = frames(ns).target, frames(ns).targettarget
    tr, sr = rect(t), rect(tot)
    assert sr[2] < tr[2] * 0.6                                # smaller
    assert sr[1] + sr[3] < tr[1] + tr[3] * 0.2                # below it
    assert abs((sr[0] + sr[2]) - (tr[0] + tr[2])) < tr[2] * 0.1  # right edges lined up
    assert list(tot.art.tc.values())[0] > list(tot.art.tc.values())[1]


def test_texts_numbers_and_level_badge():
    _, ns = preview(MODERN)
    p = frames(ns).player
    assert "/" in p.hpText.text and "/" in p.powerText.text
    assert p.levelText.text == "58"
    lv, badge = rect(p.levelText), rect(p.levelBadge)
    assert abs((lv[0] + lv[2] / 2) - (badge[0] + badge[2] / 2)) < 2


def test_small_frames_have_no_level_circle_too_small_for_its_number():
    """Focus, pet and target of target: a level circle of ~10 px cannot hold a readable number,
    so they use the art without it and hide the number; player and target keep theirs."""
    _, ns = preview(MODERN)
    f = frames(ns)
    for key in ("focus", "pet", "targettarget"):
        assert str(f[key].art.file).endswith("mod_unit_small_black"), key
        assert not visible(f[key].levelText), key
    for key in ("player", "target"):
        assert str(f[key].art.file).endswith("mod_unit_black"), key
        assert visible(f[key].levelText), key
        assert rect(f[key].levelBadge)[2] >= 16                      # room for the number


def test_arcane_ring_is_a_setting():
    _, ns = preview(MODERN)
    a = frames(ns).player.arcane
    assert a is not None and visible(a) and str(a.file).endswith("mod_arcane")
    _, ns = preview({"arcaneRing": False})
    assert not visible(frames(ns).player.arcane)


def test_target_cast_bar_under_its_debuffs_left_of_its_target():
    _, ns = preview(MODERN)
    t, tot = frames(ns).target, frames(ns).targettarget
    bar = ns.Resolve.First(ns.Data.FRAME_CANDIDATES.targetcastbar)[0]  # (frame, name)
    debuff = ns.UnitFrames.debuffs[1]
    assert rect(bar)[1] + rect(bar)[3] <= rect(debuff)[1] + 0.5      # cast bar below the debuffs
    assert rect(bar)[0] + rect(bar)[2] <= rect(tot)[0]               # stops before the target's target


def test_player_health_is_green():
    _, ns = preview(MODERN)
    vc = list(frames(ns).player.health.GetStatusBarTexture(frames(ns).player.health).vc.values())
    assert vc[1] > vc[0] and vc[1] > vc[2]


# ------------------------------------------------------------------ cast bar
def test_lag_and_queue_fractions(pure):
    from conftest import load_pure
    ns = load_pure(pure, "Core/Layout.lua")
    L = ns.Layout
    assert abs(L.CastLag(0.12, 2.5) - 0.048) < 1e-9
    assert L.CastLag(3, 2.5) == 1
    assert L.CastLag(0.1, 0) is None
    assert abs(L.CastQueue(400, 2.5) - 0.84) < 1e-9
    assert L.CastQueue(400, 0.3) is None


def castbar(ns):
    return ns.Resolve.First(ns.Data.FRAME_CANDIDATES.castbar)[0]


def test_cast_bar_in_the_modern_look():
    _, ns = preview(MODERN)
    bar = castbar(ns)
    assert str(ns.CastBar.art.file).endswith("mod_cast_black")
    fill = bar.GetStatusBarTexture(bar)
    assert str(fill.file).endswith("mod_gloss")
    vc = list(fill.vc.values())
    assert vc[2] > vc[0]                                      # blue


CAST = """
  function GetTime() return T end
  function UnitCastingInfo(u) return "Bola de Fogo", "", 1, START_MS, END_MS end
  function GetNetStats() return 0, 0, 30, 150 end
  C_CVar = { GetCVar = function(k) if k == "SpellQueueWindow" then return "400" end end }
"""


def cast(rt, sent=True):
    rt.execute(CAST)
    g = rt.globals()
    g.T, g.START_MS, g.END_MS = 10.0, 10120, 12620
    if sent:
        rt.execute('PREVIEW_FIRE("UNIT_SPELLCAST_SENT", "player")')
    g.T = 10.12
    rt.execute('PREVIEW_FIRE("UNIT_SPELLCAST_START", "player")')


def test_latency_zone_is_the_measured_ping_in_green():
    rt, ns = preview(MODERN)
    cast(rt)
    bar, lag = castbar(ns), ns.CastBar.lag
    assert visible(lag)
    assert abs(rect(lag)[2] - rect(bar)[2] * 0.12 / 2.5) < 0.6
    assert abs((rect(lag)[0] + rect(lag)[2]) - (rect(bar)[0] + rect(bar)[2])) < 0.6   # at the end
    vc = list(lag.vc.values()) if lag.color is None else list(lag.color.values())
    assert vc[1] > vc[0] and vc[1] > vc[2]                    # green
    assert "120" in ns.CastBar.lagText.text


def test_latency_falls_back_to_the_world_ping():
    rt, ns = preview(MODERN)
    cast(rt, sent=False)
    assert abs(ns.CastBar.latency - 0.150) < 1e-9


def test_queue_mark_at_the_spell_queue_window():
    rt, ns = preview(MODERN)
    cast(rt)
    bar, q = castbar(ns), ns.CastBar.queue
    assert visible(q) and rect(q)[2] >= 1 and rect(q)[3] > rect(bar)[3]
    assert abs(rect(q)[0] + rect(q)[2] / 2 - (rect(bar)[0] + rect(bar)[2] * 0.84)) < 1


def test_secret_cast_times_hide_the_zone_instead_of_erroring():
    rt, ns = preview(MODERN)
    rt.execute(CAST)
    rt.execute('function UnitCastingInfo() error("secret value") end')
    rt.execute('PREVIEW_FIRE("UNIT_SPELLCAST_START", "player")')
    assert not visible(ns.CastBar.lag) and not visible(ns.CastBar.queue)


# ------------------------------------------------------------------ minimap
def test_minimap_in_the_modern_ring():
    _, ns = preview(MODERN)
    m = ns.Minimap
    assert str(m.ring.file).endswith("mod_map_black")
    c = rect(m.frame)
    assert c[0] + c[2] <= 1920 and c[1] + c[3] <= 1080
    assert c[2] < 0.21 * 1080


# ------------------------------------------------------------------ vertical bars, settings
def test_vertical_bars_are_slot_columns_in_modern():
    _, ns = preview({"vbar1": True, "vbar2": True}, vbars=True)
    vb = ns.VerticalBars
    first, last = vb.bars[1][1], vb.bars[1][12]
    assert visible(first.obModernSlot)
    top, bottom = rect(first), rect(last)
    assert top[1] > bottom[1] and bottom[1] > ns.HUD.h       # a column, above the action bar
    assert rect(vb.bars[2][1])[0] > top[0]                    # second column to the right


def test_theme_and_colour_changes_ask_for_a_reload(lua, ns):
    loaded(lua, ns)
    lua.execute('STUB_FIRE("PLAYER_LOGIN")')
    assert lua.eval('type(rawget(StaticPopupDialogs, "OBSIDIANUI_RELOAD"))') == "table"
    assert lua.eval('type(rawget(rawget(StaticPopupDialogs, "OBSIDIANUI_RELOAD"), "OnAccept"))') == "function"


# ------------------------------------------------------------------ every setting in the game's panel
SETTINGS_PANEL = """
  PANEL = {}
  POPUPS = {}
  function StaticPopup_Show(name) POPUPS[#POPUPS + 1] = name end
  local function setting(key)
    local s = { key = key }
    s.SetValueChangedCallback = function(self, fn) self.cb = fn end
    return s
  end
  Settings = {
    RegisterVerticalLayoutCategory = function()
      return { GetID = function() return 1 end }, { AddInitializer = function() end }
    end,
    RegisterAddOnSetting = function(cat, variable, key) local s = setting(key); PANEL[key] = s; return s end,
    CreateCheckbox = function() end,
    CreateSlider = function() end,
    CreateSliderOptions = function() return { SetLabelFormatter = function() end } end,
    CreateControlTextContainer = function() return { Add = function() end, GetData = function() return {} end } end,
    CreateDropdown = function() end,
    RegisterAddOnCategory = function() end,
  }
  MinimalSliderWithSteppersMixin = { Label = { Right = 1 } }
"""


def change(rt, ns, key, value):
    """What the game's settings panel does: store the value, call the setting's callback."""
    ns.db[key] = value
    s = rt.globals().PANEL[key]
    assert s is not None, f"setting {key} is not in the panel"
    s.cb(s, value)


def panel():
    rt = preview_render.run_addon(vbars=False, pre=SETTINGS_PANEL)
    return rt, rt.globals().PREVIEW_NS


def test_the_panel_lists_every_setting():
    rt, _ = panel()
    keys = set(rt.globals().PANEL.keys())
    assert keys == {"vbar1", "vbar2", "showHotkeys", "modernColor", "arcaneRing", "modernRows", "modernCols",
                    "scale", "invScale"}


def test_rows_columns_and_scale_relayout_the_bar_live():
    rt, ns = panel()
    b = ns.ActionBars.buttons
    assert not b[13].obEnabled
    change(rt, ns, "modernRows", 3)
    assert b[13].obEnabled and visible(b[13])
    change(rt, ns, "modernCols", 8)
    assert abs(rect(ns.ActionBars.modernFrame)[2] - (8 * 54 + 7 * 7)) < 1
    w = rect(b[1])[2]
    change(rt, ns, "scale", 0.8)
    assert abs(rect(b[1])[2] - w * 0.8) < 0.5


def test_vertical_bars_and_hotkeys_switch_live():
    rt, ns = panel()
    change(rt, ns, "vbar1", True)
    assert visible(ns.VerticalBars.container) and ns.VerticalBars.bars[1][1].obEnabled
    change(rt, ns, "vbar1", False)
    assert not visible(ns.VerticalBars.container)
    change(rt, ns, "showHotkeys", False)
    assert not visible(ns.ActionBars.buttons[1].HotKey)


def test_arcane_ring_switches_live_and_colour_asks_for_a_reload():
    rt, ns = panel()
    change(rt, ns, "arcaneRing", False)
    assert not visible(frames(ns).player.arcane)
    change(rt, ns, "arcaneRing", True)
    assert visible(frames(ns).player.arcane)
    change(rt, ns, "modernColor", "blue")
    assert list(rt.globals().POPUPS.values()) == ["OBSIDIANUI_RELOAD"]


def test_inventory_size_applies_live():
    rt, ns = panel()
    ns.Inventory.Open()
    w = rect(ns.Inventory.frame)[2]
    change(rt, ns, "invScale", 1.2)
    assert rect(ns.Inventory.frame)[2] > w * 1.1


def test_no_power_text_when_the_unit_has_no_power():
    # NPCs without mana showed "0 / 0" on the target's second bar.
    rt = preview_render.run_addon(vbars=False, pre="""
      local base = UnitPowerMax
      function UnitPowerMax(u, t) if u == "target" then return 0 end return base(u, t) end
    """)
    t = frames(rt.globals().PREVIEW_NS).target
    assert t.powerText.text == ""


# ------------------------------------------------------------------ the screen grid
def visible_box(region, edge, tex_w, mirror=False):
    """A piece's visible box (left, top, right, bottom from the screen's top left), without the
    transparent edges of its texture."""
    l, b, w, h = rect(region)
    u = w / tex_w
    el, er = (edge.r, edge.l) if mirror else (edge.l, edge.r)
    return l + el * u, 1080 - (b + h) + edge.t * u, l + w - er * u, 1080 - b - edge.b * u


def test_everything_sits_on_one_screen_grid():
    """One margin to every screen edge, one gap between neighbours, two between groups; nothing
    overlaps."""
    _, ns = preview(vbars=True)
    D, M, G = ns.Data.ART_EDGE, ns.Layout.MARGIN, ns.Layout.GAP
    f = frames(ns)
    player = visible_box(f.player, D.unit, 720)
    target = visible_box(f.target, D.unit, 720, True)
    tot = visible_box(f.targettarget, D.unitSmall, 720, True)
    focus = visible_box(f.focus, D.unitSmall, 720)
    pet = visible_box(f.pet, D.unitSmall, 720)
    mp = visible_box(ns.Minimap.frame, D.map, 340)
    band = ns.MenuPanels.bandFrame
    k = rect(band)[3] / 92
    bl, bb, bw, bh = rect(band)
    menu = (bl + 6 * k, 1080 - (bb + bh) + 10 * k, bl + bw - 6 * k, 1080 - bb - 10 * k)
    il, ib, iw, ih = rect(ns.InfoBar.frame)
    info = (il, 1080 - (ib + ih), il + iw, 1080 - ib)
    xl, xb, xw, xh = rect(ns.DataBars.holder)
    near = lambda a, b: abs(a - b) < 1
    assert near(player[0], M) and near(player[1], M)
    assert near(mp[1], M) and near(1920 - mp[2], M)
    assert near(1920 - menu[2], M) and near(1080 - menu[3], M)
    assert near(xb, M)                                                       # the XP bar's foot
    assert near(1920 - rect(ns.VerticalBars.container)[0] - rect(ns.VerticalBars.container)[2], M)
    assert near(target[0] - player[2], 2 * G) and near(focus[1] - player[3], 2 * G)
    assert near(pet[1] - focus[3], G) and near(tot[1] - target[3], G) and near(tot[2], target[2])
    assert near(menu[1] - info[3], G) and near(info[2], menu[2])
    cast, res = rect(ns.CastBar.art), rect(ns.ClassResource.holder)
    u = cast[2] / 940
    cast_foot = 1080 - cast[1] - D.cast.b * u
    assert near((1080 - res[1] - res[3]) - cast_foot, G)
