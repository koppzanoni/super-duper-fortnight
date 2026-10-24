"""Tooltips (HUD/Tooltip.lua) in the Moderno look."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402

# GameTooltip shaped like the game's (SharedTooltipTemplates.xml / GameTooltip.xml) and the
# TooltipDataProcessor hooks recorded so a test can run them.
TIP = r"""
  POST = {}
  TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) POST[kind] = fn end }
  Enum.TooltipDataType = { Item = 0, Spell = 1, Unit = 2 }
  HOOKS = {}
  function hooksecurefunc(a, b, c) if type(a) == "string" then HOOKS[a] = b end end
  function GameTooltip_SetDefaultAnchor(tip, parent) tip:ClearAllPoints(); tip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -100, 100) end
  function SharedTooltip_SetBackdropStyle() end
  local function tooltip(name)
    local t = CreateFrame("Frame", name, UIParent)
    t:SetSize(220, 90)
    t:SetPoint("CENTER")
    t.NineSlice = CreateFrame("Frame", nil, t)
    t.NineSlice:SetAllPoints(t)
    t.StatusBar = CreateFrame("StatusBar", name .. "StatusBar", t)
    t.StatusBar:SetStatusBarTexture("bar")
    _G[name .. "TextLeft1"] = t:CreateFontString(name .. "TextLeft1", "OVERLAY", "GameTooltipHeaderText")
    _G[name .. "TextLeft1"]:SetText("Lyra")
    t.LINES = {}
    function t:AddLine(text, r, g, b) self.LINES[#self.LINES + 1] = { text, r, g, b } end
    function t:GetUnit() return self.UNITNAME, self.UNIT end
    function t:GetItem() return "Espada", self.LINK end
    function t:SetOwner(owner, anchor, x, y) self.anchor = anchor end
    return t
  end
  GameTooltip = tooltip("GameTooltip")
  ItemRefTooltip = tooltip("ItemRefTooltip")
  ShoppingTooltip1 = tooltip("ShoppingTooltip1")
  ITEM_QUALITY_COLORS = { [1] = { r = 1, g = 1, b = 1 }, [4] = { r = 0.64, g = 0.21, b = 0.93 } }
  function C_Item.GetItemQualityByID(link) return link == "epic" and 4 or 1 end
  local base = { UnitIsPlayer = UnitIsPlayer, UnitClass = UnitClass, UnitName = UnitName, UnitExists = UnitExists }
  function UnitIsPlayer(u) if u == "mouseover" then return true end return base.UnitIsPlayer(u) end
  function UnitClass(u) if u == "mouseover" then return "Mago", "MAGE" end return base.UnitClass(u) end
  function UnitExists(u) if u == "mouseover" or u == "mouseovertarget" then return true end return base.UnitExists(u) end
  function UnitName(u) if u == "mouseovertarget" then return "Você" end if u == "mouseover" then return "Lyra" end return base.UnitName(u) end
  RAID_CLASS_COLORS.MAGE = { r = 0.25, g = 0.78, b = 0.92 }
"""


def preview(db=None):
    rt = preview_render.run_addon(vbars=False, db=dict({"installed": True}, **(db or {})),
                                  pre="C_Item = C_Item or {}\n" + TIP)
    return rt, rt.globals().PREVIEW_NS, rt.globals()


def rim(tip):
    return list(tip.obRim[1].color.values())[:3]


def test_black_panel_instead_of_the_games_border():
    _, ns, g = preview()
    for tip in (g.GameTooltip, g.ItemRefTooltip, g.ShoppingTooltip1):
        assert tip.NineSlice.alpha == 0 and tip.obFill is not None
    g.HOOKS.SharedTooltip_SetBackdropStyle(g.GameTooltip)
    assert g.GameTooltip.NineSlice.alpha == 0                            # stays hidden after the game restyles


def test_item_rim_in_its_quality_colour():
    _, ns, g = preview()
    tip = g.GameTooltip
    tip.LINK = "epic"
    g.POST[0](tip, {})
    r, gg, b = rim(tip)
    assert abs(r - 0.64) < 0.01 and abs(b - 0.93) < 0.01
    tip.LINK = "plain"
    g.POST[0](tip, {})
    assert rim(tip) != [0.64, 0.21, 0.93]


def test_player_name_and_rim_in_class_colour_and_their_target():
    _, ns, g = preview()
    tip = g.GameTooltip
    tip.UNITNAME, tip.UNIT = "Lyra", "mouseover"
    g.POST[2](tip, {})
    name = g.GameTooltipTextLeft1
    r, gg, b = name.GetTextColor(name)
    assert abs(r - 0.25) < 0.01 and abs(b - 0.92) < 0.01
    assert any("Alvo" in l[1] and "Você" in l[1] for l in tip.LINES.values())


def test_health_bar_in_the_look():
    _, ns, g = preview()
    bar = g.GameTooltip.StatusBar
    assert bar.GetStatusBarTexture(bar).file != "bar"
    assert bar.backing is not None


def test_anchor_at_the_cursor():
    _, ns, g = preview({"tipAnchor": "cursor"})
    tip = g.GameTooltip
    g.HOOKS.GameTooltip_SetDefaultAnchor(tip, g.UIParent)
    assert tip.anchor == "ANCHOR_CURSOR_RIGHT"


def test_hidden_over_the_world_in_combat():
    rt, ns, g = preview({"tipCombat": False})
    tip = g.GameTooltip
    rt.execute("function InCombatLockdown() return true end; function GameTooltip:GetOwner() return UIParent end")
    tip.Show(tip)
    tip.hooks.OnShow(tip)
    assert not tip.IsShown(tip)
    rt.execute("BUTTON = CreateFrame('Button', nil, UIParent); function GameTooltip:GetOwner() return BUTTON end")
    tip.Show(tip)
    tip.hooks.OnShow(tip)
    assert tip.IsShown(tip)                                              # buttons keep theirs


def test_switched_off():
    _, ns, g = preview({"tip_on": False})
    assert (g.GameTooltip.NineSlice.alpha or 1) == 1 and g.GameTooltip.obFill is None


def test_panel_page():
    _, ns, g = preview()
    ns.Panel.Open("tooltip")
    labels = [r.row.label for r in ns.Panel.rows.values() if r.row is not None]
    assert "Posição" in labels and "Em combate" in labels
