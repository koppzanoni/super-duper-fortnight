"""Automation (HUD/Automation.lua): merchants, social requests, cinematics, loot, errors, AFK screen."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402

GAME = """
CALLS = {}
local function call(name, ...) CALLS[#CALLS + 1] = name; CALLS[name] = { ... } end
JUNK, REPAIR_COST, GUILD_REPAIR, GUILD_MONEY, MONEY = 2, 12000, true, -1, 500000
C_MerchantFrame = { GetNumJunkItems = function() return JUNK end, IsSellAllJunkEnabled = function() return true end,
  SellAllJunkItems = function() call("SellAllJunkItems") end }
function CanMerchantRepair() return true end
function GetRepairAllCost() return REPAIR_COST, REPAIR_COST > 0 end
function CanGuildBankRepair() return GUILD_REPAIR end
function GetGuildBankWithdrawMoney() return GUILD_MONEY end
function GetMoney() return MONEY end
function RepairAllItems(guild) call("RepairAllItems", guild) end
FRIENDS, GUILD, BNET = { ["Player-1"] = true }, { ["Player-2"] = true }, {}
C_FriendList = { IsFriend = function(g) return FRIENDS[g] or false end }
function IsGuildMember(g) return GUILD[g] or false end
C_BattleNet = { GetGameAccountInfoByGUID = function(g) return BNET[g] end }
function AcceptGroup() call("AcceptGroup") end
DIALOGS = {}
function StaticPopup_FindVisible(which) return DIALOGS[which] end
function StaticPopup_Hide(which) call("StaticPopup_Hide:" .. which); if DIALOGS[which] then DIALOGS[which].hidden = true end end
function CancelDuel() call("CancelDuel") end
COMBAT_UNITS = {}
function UnitAffectingCombat(u) return COMBAT_UNITS[u] or false end
function GetCorpseRecoveryDelay() return 0 end
function AcceptResurrect() call("AcceptResurrect") end
INSTANCE = "none"
function IsInInstance() return INSTANCE ~= "none", INSTANCE end
SELF_RES = {}
C_DeathInfo = { GetSelfResurrectOptions = function() return SELF_RES end }
DEAD = true
function UnitIsDead() return DEAD end
function UnitIsGhost() return false end
function RepopMe() call("RepopMe") end
function StopCinematic() call("StopCinematic") end
MAP = 1415
C_Map = { GetBestMapForUnit = function() return MAP end }
function GetSubZoneText() return "Vale" end
MovieFrame = CreateFrame("Frame", "MovieFrame", UIParent)
function MovieFrame:PlayMovie(id) self.playing = id end
function MovieFrame:FinishMovie() call("FinishMovie"); self.playing = nil end
HOOKS = {}
function hooksecurefunc(a, b, c)
  if type(a) == "table" then HOOKS[b] = c; local orig = a[b]; a[b] = function(...) if orig then orig(...) end; c(...) end
  else HOOKS[a] = b end
end
LOOT = { { locked = false }, { locked = false }, { locked = true } }
function GetNumLootItems() return #LOOT end
function GetLootSlotInfo(i) return nil, nil, 1, nil, nil, LOOT[i].locked end
function LootSlot(i) CALLS[#CALLS + 1] = "LootSlot" .. i end
AUTOLOOT = true
function GetCVarBool(name) if name == "autoLootDefault" then return AUTOLOOT end return false end
function IsModifiedClick() return false end
UIErrorsFrame = CreateFrame("Frame", "UIErrorsFrame", UIParent)
UIErrorsFrame.events = { UI_ERROR_MESSAGE = true }
function UIErrorsFrame:RegisterEvent(e) self.events[e] = true end
function UIErrorsFrame:UnregisterEvent(e) self.events[e] = nil end
WorldFrame = CreateFrame("Frame", "WorldFrame")
WorldFrame.parent = nil -- not under UIParent, like the game
AFK = false
function UnitIsAFK() return AFK end
function MoveViewLeftStart(s) call("MoveViewLeftStart", s) end
function MoveViewLeftStop() call("MoveViewLeftStop") end
"""


def preview(db=None):
    rt = preview_render.run_addon(vbars=False, db=dict({"installed": True}, **(db or {})), pre=GAME)
    g = rt.globals()
    g.CALLS = rt.eval("{}")
    return rt, g.PREVIEW_NS, g


def calls(g):
    return [g.CALLS[i] for i in range(1, len([k for k in g.CALLS.keys() if isinstance(k, int)]) + 1)]


def fire(g, *args):
    g.PREVIEW_FIRE(*args)


def visible(region):
    return bool(region.IsVisible(region))


def test_merchant_sells_junk_and_repairs_with_the_guild_first():
    _, ns, g = preview()
    fire(g, "MERCHANT_SHOW")
    assert "SellAllJunkItems" in calls(g)
    assert "RepairAllItems" in calls(g) and g.CALLS.RepairAllItems[1] is True


def test_repair_with_own_gold_when_the_guild_cannot():
    _, ns, g = preview()
    g.GUILD_REPAIR = False
    fire(g, "MERCHANT_SHOW")
    assert g.CALLS.RepairAllItems[1] in (None, False)
    _, ns, g = preview()
    g.GUILD_MONEY = 100                                   # guild allowance too small
    fire(g, "MERCHANT_SHOW")
    assert g.CALLS.RepairAllItems[1] in (None, False)
    _, ns, g = preview()
    g.GUILD_REPAIR, g.MONEY = False, 50                   # not enough gold: nothing
    fire(g, "MERCHANT_SHOW")
    assert "RepairAllItems" not in calls(g)


def test_merchant_options_off():
    _, ns, g = preview({"autoJunk": False, "autoRepair": "off"})
    fire(g, "MERCHANT_SHOW")
    assert calls(g) == []
    _, ns, g = preview({"autoRepair": "self"})
    fire(g, "MERCHANT_SHOW")
    assert g.CALLS.RepairAllItems[1] in (None, False)
    _, ns, g = preview()
    g.JUNK, g.REPAIR_COST = 0, 0
    fire(g, "MERCHANT_SHOW")
    assert calls(g) == []


def test_invites_from_friends_and_guild_are_accepted():
    rt, ns, g = preview()
    g.DIALOGS = rt.eval('{ PARTY_INVITE = {} }')
    fire(g, "PARTY_INVITE_REQUEST", "Ana", False, False, False, True, False, "Player-1")
    assert "AcceptGroup" in calls(g)
    assert g.DIALOGS.PARTY_INVITE.inviteAccepted == 1 and g.DIALOGS.PARTY_INVITE.hidden   # no decline on hide
    _, ns, g = preview()
    fire(g, "PARTY_INVITE_REQUEST", "Bia", False, False, False, True, False, "Player-2")
    assert "AcceptGroup" in calls(g)


def test_invites_from_strangers_are_left_alone():
    _, ns, g = preview()
    fire(g, "PARTY_INVITE_REQUEST", "Zé", False, False, False, True, False, "Player-9")
    assert "AcceptGroup" not in calls(g)
    _, ns, g = preview({"autoInvite": False})
    fire(g, "PARTY_INVITE_REQUEST", "Ana", False, False, False, True, False, "Player-1")
    assert "AcceptGroup" not in calls(g)


def test_duels_declined_only_when_asked():
    _, ns, g = preview()
    fire(g, "DUEL_REQUESTED", "Zé")
    assert "CancelDuel" not in calls(g)
    _, ns, g = preview({"noDuel": True})
    fire(g, "DUEL_REQUESTED", "Zé")
    assert "CancelDuel" in calls(g) and "StaticPopup_Hide:DUEL_REQUESTED" in calls(g)


def test_resurrection_accepted_out_of_combat():
    _, ns, g = preview()
    fire(g, "RESURRECT_REQUEST", "Ana")
    assert "AcceptResurrect" in calls(g) and "StaticPopup_Hide:RESURRECT" in calls(g)
    rt, ns, g = preview()
    rt.execute('COMBAT_UNITS.Ana = true')
    fire(g, "RESURRECT_REQUEST", "Ana")
    assert "AcceptResurrect" not in calls(g)               # a battle res is the player's call


def test_spirit_released_in_battlegrounds_without_a_soulstone():
    _, ns, g = preview()
    fire(g, "PLAYER_DEAD")
    assert "RepopMe" not in calls(g)                       # not in the open world
    _, ns, g = preview()
    g.INSTANCE = "pvp"
    fire(g, "PLAYER_DEAD")
    assert "RepopMe" in calls(g)
    rt, ns, g = preview()
    g.INSTANCE = "pvp"
    g.SELF_RES = rt.eval("{ { name = 'Pedra da Alma' } }")
    fire(g, "PLAYER_DEAD")
    assert "RepopMe" not in calls(g)


def test_cinematics_skipped_the_second_time():
    _, ns, g = preview()
    fire(g, "CINEMATIC_START", True)
    assert "StopCinematic" not in calls(g)
    fire(g, "CINEMATIC_START", True)
    assert "StopCinematic" in calls(g)
    assert len(list(ns.db.seenCinematics.keys())) == 1


def test_movies_skipped_the_second_time():
    _, ns, g = preview()
    g.MovieFrame.PlayMovie(g.MovieFrame, 16)
    assert "FinishMovie" not in calls(g)
    g.MovieFrame.PlayMovie(g.MovieFrame, 16)
    assert "FinishMovie" in calls(g)


def test_seen_cinematics_are_account_data_not_profile():
    _, ns, _ = preview()
    ns.db.seenCinematics = {"x": True}
    assert "seenCinematics" not in list(ns.Profiles.Snapshot().keys())


def test_fast_loot_takes_every_free_slot():
    _, ns, g = preview()
    fire(g, "LOOT_READY", True)
    assert calls(g) == ["LootSlot2", "LootSlot1"]           # from the end, skipping the locked one
    _, ns, g = preview()
    g.AUTOLOOT = False
    fire(g, "LOOT_READY", False)
    assert calls(g) == []


def test_red_errors_hidden_in_combat_when_asked():
    _, ns, g = preview()
    fire(g, "PLAYER_REGEN_DISABLED")
    assert g.UIErrorsFrame.events.UI_ERROR_MESSAGE
    _, ns, g = preview({"hideErrors": True})
    fire(g, "PLAYER_REGEN_DISABLED")
    assert not g.UIErrorsFrame.events.UI_ERROR_MESSAGE
    fire(g, "PLAYER_REGEN_ENABLED")
    assert g.UIErrorsFrame.events.UI_ERROR_MESSAGE


def test_afk_screen():
    _, ns, g = preview()
    g.AFK = True
    fire(g, "PLAYER_FLAGS_CHANGED", "player")
    assert visible(ns.Automation.afk) and not g.UIParent.IsShown(g.UIParent)
    assert "MoveViewLeftStart" in calls(g)
    g.AFK = False
    fire(g, "PLAYER_FLAGS_CHANGED", "player")
    assert not visible(ns.Automation.afk) and g.UIParent.IsShown(g.UIParent)
    assert "MoveViewLeftStop" in calls(g)


def test_afk_screen_gives_way_to_combat_and_instances():
    _, ns, g = preview()
    g.AFK = True
    fire(g, "PLAYER_FLAGS_CHANGED", "player")
    fire(g, "PLAYER_REGEN_DISABLED")
    assert not visible(ns.Automation.afk) and g.UIParent.IsShown(g.UIParent)
    _, ns, g = preview()
    g.AFK, g.INSTANCE = True, "raid"
    fire(g, "PLAYER_FLAGS_CHANGED", "player")
    assert not visible(ns.Automation.afk)
    _, ns, g = preview({"afkScreen": False})
    g.AFK = True
    fire(g, "PLAYER_FLAGS_CHANGED", "player")
    assert not visible(ns.Automation.afk) and g.UIParent.IsShown(g.UIParent)


def test_panel_page():
    _, ns, _ = preview()
    ns.Panel.Open("automation")
    labels = [r.row.label for r in ns.Panel.rows.values() if r.row is not None]
    for label in ("Vender lixo sozinho", "Reparar sozinho", "Aceitar convite de amigos e guilda", "Recusar duelos",
                  "Aceitar ressurreição fora de combate", "Liberar o espírito sozinho em campo de batalha",
                  "Pular cinemáticas já vistas", "Saquear rápido", "Ocultar erros vermelhos em combate",
                  "Tela de ausente"):
        assert label in labels, label
