"""Inventory stats panel: always open with the inventory, sections, styled buttons."""
from conftest import load_addon_file, new_runtime, toc_files


def boot(lua, ns, pre=""):
    if pre:
        lua.execute(pre)
    for f in toc_files():
        load_addon_file(lua, f, ns)
    lua.execute('STUB_FIRE("ADDON_LOADED", "ObsidianUI")')
    lua.execute('STUB_FIRE("PLAYER_LOGIN")')
    return ns


API = """
  return {
    stat = function(i) return ({ 26, 22, 67, 74, 46 })[i] end,
    armor = function() return 312 end,
    attackPower = function() return 140 end,
    crit = function() return 5.1 end,
    haste = function() return 0 end,
    mastery = function() return 0 end,
    spellPower = function() return 0 end,
    spellCrit = function() return 0 end,
    dodge = function() return 7.26 end,
    parry = function() return 0 end,
    block = function() return 0 end,
  }
"""


def rows_of(rt, api_src):
    ns = load_addon_file(rt, "Inventory/Stats.lua", rt.table())
    rows = ns.Stats.Rows(rt.execute(api_src))
    out = []
    for i in range(1, len(rows) + 1):
        r = rows[i]
        out.append(("#", r.header) if r.header else (r.label, r.value))
    return out


def test_rows_grouped_in_sections_without_useless_zeros():
    rows = rows_of(new_runtime(), API)
    headers = [v for k, v in rows if k == "#"]
    assert headers == ["Primários", "Ataque", "Defesa"]  # no spell power: no "Magia"
    d = dict(r for r in rows if r[0] != "#")
    assert d["Força"] == "26" and d["Espírito"] == "46"
    assert d["Crítico"] == "5.1%" and d["Esquiva"] == "7.3%"
    assert d["Poder de Ataque"] == "140" and d["Armadura"] == "312"
    for gone in ("Aceleração", "Maestria", "Aparar", "Bloqueio", "Poder Mágico"):
        assert gone not in d


def test_missing_api_rows_are_skipped():
    rows = rows_of(new_runtime(), API.replace("crit = function() return 5.1 end", "crit = function() return nil end"))
    assert "Crítico" not in dict(r for r in rows if r[0] != "#")


def test_game_api_reads_effective_stats(lua, ns):
    boot(lua, ns, pre="""
      function UnitStat(_, i) return 20, 26 + i, 6, 0 end
      function UnitArmor() return 300, 312 end
    """)
    api = ns.Stats.GameAPI()
    assert api.stat(1) == 27
    assert api.armor() == 312


def test_stats_panel_opens_with_inventory(lua, ns):
    boot(lua, ns)
    panel = ns.Inventory.statsPanel
    shown = {"v": False}
    panel.Show = lambda self: shown.__setitem__("v", True)
    panel.SetShown = lambda self, v: shown.__setitem__("v", bool(v))
    ns.Inventory.Open()
    assert shown["v"] is True


def test_inventory_size_setting_scales_the_window(lua, ns):
    boot(lua, ns)
    _, _, _, h1 = ns.Inventory.DefaultPlacement(1920, 1080, 270)
    ns.db.invScale = 1.2
    _, _, _, h2 = ns.Inventory.DefaultPlacement(1920, 1080, 270)
    assert abs(h2 - h1 * 1.2) < 1e-6
    assert ns.db.invScale == 1.2


def test_inventory_size_defaults_to_one(lua, ns):
    boot(lua, ns)
    assert ns.db.invScale == 1.0


def test_rows_carry_the_stat_they_show():
    rt = new_runtime()
    ns = load_addon_file(rt, "Inventory/Stats.lua", rt.table())
    rows = ns.Stats.Rows(rt.execute(API))
    byLabel = {rows[i].label: rows[i] for i in range(1, len(rows) + 1) if rows[i].label}
    assert (byLabel["Força"].key, byLabel["Força"].index) == ("stat", 1)
    assert byLabel["Espírito"].index == 5
    assert byLabel["Armadura"].key == "armor"
    assert byLabel["Crítico"].key == "crit"


# Hovering a stat shows the same tooltip as the default character sheet.
def test_hovering_a_stat_shows_the_blizzard_stat_tooltip(lua, ns):
    boot(lua, ns, pre="""
      SET_STAT, SHOWN = nil, nil
      function UnitStat(_, i) return 20, 26, 6, 0 end
      function PaperDollFrame_SetStat(f, unit, i) SET_STAT = i; f.tooltip = "Espírito 67" end
      function PaperDollStatTooltip(f) SHOWN = f.tooltip end
    """)
    ns.Inventory.Open()
    rows = ns.Inventory.statLines
    force = [rows[i] for i in range(1, len(rows) + 1) if rows[i].key == "stat" and rows[i].index == 1][0]
    force.hover.handlers.OnEnter(force.hover)
    g = lua.globals()
    assert g.SET_STAT == 1 and g.SHOWN == "Espírito 67"
