"""Profiles (Core/Profiles.lua): saved settings sets, per character and per specialization, by
content (solo, group, raid, PvP), presets, and export/import text."""
import sys

from conftest import ROOT, load_pure

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402

GAME = """
  ME = "Elanora"; REALM = "Ventobravo"; SPEC = 1
  GROUP = false; RAID = false; INSTANCE = "none"
  function UnitName(u) if u == "player" then return ME end return "x" end
  function GetRealmName() return REALM end
  function GetSpecialization() return SPEC end
  function IsInGroup() return GROUP end
  function IsInRaid() return RAID end
  function IsInInstance() return INSTANCE ~= "none", INSTANCE end
  POPUPS = {}
  function StaticPopup_Show(n) POPUPS[#POPUPS + 1] = n end
"""


def boot(saved=None, db=None):
    pre = GAME
    if saved:
        pre += "\nObsidianUIDB = " + saved
    rt = preview_render.run_addon(vbars=False, db=db, pre=pre)
    return rt, rt.globals().PREVIEW_NS


def rect(region):
    return tuple(region.Rect(region).values())


# ------------------------------------------------------------------ text format (pure)
def test_serialize_round_trip(pure):
    P = load_pure(pure, "Core/Serialize.lua").Serialize
    t = pure.eval('{ a = 1, b = "x \\"y\\"\\n", c = true, d = { 1, 2, { e = -0.5 } }, ["f g"] = false }')
    back = P.Decode(P.Encode(t))
    assert back.a == 1 and back.b == 'x "y"\n' and back.c is True and back["f g"] is False
    assert back.d[3].e == -0.5 and back.d[2] == 2


def test_decode_never_runs_code(pure):
    P = load_pure(pure, "Core/Serialize.lua").Serialize
    pure.execute("PWNED = false")
    for evil in ('{ a = (function() PWNED = true end)() }', 'os.exit()', '{ a = PWNED }', '{ a = 1 } PWNED = true'):
        ok, _ = pure.eval("function(P, s) return pcall(P.Decode, s) end")(P, evil)
        assert ok is False
    assert pure.globals().PWNED is False


def test_text_is_printable_and_prefixed(pure):
    P = load_pure(pure, "Core/Serialize.lua").Serialize
    s = P.Pack(pure.eval('{ x = "olá", n = 3 }'))
    assert s.startswith("OBUI1:") and all(32 < ord(ch) < 127 for ch in s)
    back = P.Unpack(s)
    assert back.x == "olá" and back.n == 3


# ------------------------------------------------------------------ profiles
def test_first_run_makes_a_default_profile():
    _, ns = boot()
    assert ns.db.activeProfile == "Padrão"
    assert ns.db.profiles["Padrão"] is not None
    assert ns.Profiles.Current() == "Padrão"


def test_new_profile_switch_and_back_live():
    _, ns = boot()
    ns.Profiles.New("Compacto")
    ns.Profiles.Switch("Compacto")
    ns.db.modernCols = 8
    ns.Profiles.Save()
    ns.HUD.Layout()
    assert abs(rect(ns.ActionBars.modernFrame)[2] - (8 * 54 + 7 * 7)) < 1
    ns.Profiles.Switch("Padrão")
    assert ns.db.modernCols == 12
    assert abs(rect(ns.ActionBars.modernFrame)[2] - (12 * 54 + 11 * 7)) < 1
    ns.Profiles.Switch("Compacto")
    assert ns.db.modernCols == 8


def test_block_log_is_account_data_not_a_setting():
    rt, ns = boot()
    rt.execute('PREVIEW_NS.db.blockLog = { "01:07:00 FORBIDDEN UseAction() combate=false abertas=" }')
    ns.Profiles.New("Compacto")
    ns.Profiles.Switch("Compacto")
    assert ns.db.blockLog[1].startswith("01:07:00")              # kept across a switch
    ns.Profiles.Save()
    assert ns.db.profiles["Compacto"].blockLog is None           # never saved (or exported) in a profile


def test_copy_and_delete():
    _, ns = boot()
    ns.db.scale = 0.8
    ns.Profiles.Save()
    ns.Profiles.New("Cópia", "Padrão")
    assert ns.db.profiles["Cópia"].scale == 0.8
    assert ns.Profiles.Delete("Padrão") is False            # the default and the active one stay
    assert ns.Profiles.Delete("Cópia") is True and ns.db.profiles["Cópia"] is None


def test_each_character_remembers_its_profile():
    rt, ns = boot()
    ns.Profiles.New("Alt")
    ns.Profiles.Switch("Alt")
    ns.db.modernRows = 3
    ns.Profiles.Save()
    saved = ns.Profiles.Dump()                               # what the game writes to disk
    rt2, ns2 = boot(saved=saved)                             # same character logs in again
    assert ns2.Profiles.Current() == "Alt" and ns2.db.modernRows == 3
    rt3, ns3 = boot(saved=saved.replace('"Elanora - Ventobravo"', '"Outro - Ventobravo"'))
    assert ns3.db.modernRows == 3                            # an unknown character keeps what is loaded


def test_specialization_switches_the_profile():
    rt, ns = boot()
    ns.Profiles.New("Fogo")
    ns.Profiles.SetSpecProfile(2, "Fogo")
    rt.globals().SPEC = 2
    rt.execute('PREVIEW_FIRE("PLAYER_SPECIALIZATION_CHANGED", "player")')
    assert ns.Profiles.Current() == "Fogo"
    rt.globals().SPEC = 1
    rt.execute('PREVIEW_FIRE("ACTIVE_TALENT_GROUP_CHANGED")')
    assert ns.Profiles.Current() == "Fogo"                   # spec 1 has no profile of its own


def test_content_switch_only_when_turned_on():
    rt, ns = boot()
    ns.Profiles.New("Raide")
    ns.Profiles.SetContentProfile("raid", "Raide")
    rt.globals().RAID, rt.globals().GROUP = True, True
    rt.execute('PREVIEW_FIRE("GROUP_ROSTER_UPDATE")')
    assert ns.Profiles.Current() == "Padrão"
    ns.Profiles.SetAutoContent(True)
    rt.execute('PREVIEW_FIRE("GROUP_ROSTER_UPDATE")')
    assert ns.Profiles.Current() == "Raide" and ns.Profiles.Content() == "raid"
    rt.globals().INSTANCE = "pvp"
    assert ns.Profiles.Content() == "pvp"


def test_presets_apply_to_the_current_profile():
    _, ns = boot()
    ns.Profiles.ApplyPreset("Compacto")
    assert ns.db.scale == 0.85 and ns.db.modernCols == 10
    ns.Profiles.ApplyPreset("Healer")
    assert ns.db.layout.player is not None and ns.db.modernRows == 3


def test_export_and_import():
    rt, ns = boot()
    ns.db.modernCols = 9
    ns.db.layout = rt.table_from({"map": rt.table_from({"x": 900, "y": 600})})
    full = ns.Profiles.Export("all")
    layout = ns.Profiles.Export("layout")
    rt2, ns2 = boot()
    assert ns2.Profiles.Import(layout) == "layout"
    assert ns2.db.layout.map.x == 900 and ns2.db.modernCols == 12
    assert ns2.Profiles.Import(full) == "all"
    assert ns2.db.modernCols == 9
    ok, err = rt2.eval("function(P, s) return pcall(P.Import, s) end")(ns2.Profiles, "lixo")
    assert ok is False


def test_switching_to_another_colour_asks_for_a_reload():
    rt, ns = boot()
    ns.Profiles.New("Azul")
    ns.Profiles.Switch("Azul")
    ns.db.modernColor = "blue"
    ns.Profiles.Save()
    ns.Profiles.Switch("Padrão")
    assert "OBSIDIANUI_RELOAD" in list(rt.globals().POPUPS.values())
