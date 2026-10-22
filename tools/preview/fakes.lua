-- Fake game state for the preview: a level 58 druid-like caster in combat with an elite wolf.
function InCombatLockdown() return false end
function issecretvalue() return false end
function GetBuildInfo() return "1.60.1", "70532", "", 16001 end
function UnitExists(u) return u == "player" or u == "target" or u == "focus" or u == "pet" or u == "targettarget" end
local HP = { player = { 28400, 39500 }, target = { 412000, 606000 }, focus = { 8000, 20000 }, pet = { 8500, 10000 },
  targettarget = { 28400, 39500 } }
function UnitHealth(u) return (HP[u] or { 1, 1 })[1] end
function UnitHealthMax(u) return (HP[u] or { 1, 1 })[2] end
function UnitHealthPercent(u) local h = HP[u] or { 1, 1 }; return h[1] / h[2] * 100 end
function UnitPowerType(u) if u == "pet" then return 2, "FOCUS" end return 0, "MANA" end
local PW = { player = { 11000, 20000 }, target = { 45, 100 }, focus = { 16000, 20000 }, pet = { 60, 100 },
  targettarget = { 11000, 20000 } }
function UnitPower(u, t) if t == 4 then return 3 end return (PW[u] or { 1, 1 })[1] end
function UnitPowerMax(u, t) if t == 4 then return 5 end return (PW[u] or { 1, 1 })[2] end
function UnitPowerPercent(u) local p = PW[u] or { 1, 1 }; return p[1] / p[2] * 100 end
function AbbreviateNumbers(n) if n >= 1000 then return string.format("%.1fK", n / 1000) end return tostring(n) end
local NAMES = { player = "Você", target = "Ravenfang Alpha", focus = "Xamã Sombrio", pet = "Lobo", targettarget = "Você" }
function UnitName(u) return NAMES[u] end
function UnitLevel(u) if u == "target" then return 62 end return 58 end
function GetMaxPlayerLevel() return 60 end
function UnitClassification(u) if u == "target" then return "elite" end return "normal" end
function UnitClass() return "Ladino", "ROGUE" end
function GetSpecialization() return 1 end
function UnitXP() return 62 end
function UnitXPMax() return 100 end
function GetXPExhaustion() return 10 end
function SetPortraitTexture(tex, u) tex:SetTexture("PORTRAIT:" .. u) end
local ICON_ACTIONS = 26
function GetActionTexture(a)
  if not a then return nil end
  local i = (a - 1) % 60
  if a <= 12 or (a >= 49 and a <= 56) or (a >= 61 and a <= 66) or (a >= 25 and a <= 30) then return "ICON:" .. (i % 24) end
  return nil
end
function GetBindingKey(b)
  local n = tonumber(b:match("(%d+)$"))
  if b:find("^ACTIONBUTTON") then return ({ "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" })[n] end
  if b:find("^MULTIACTIONBAR1") then return "F" .. n end
  if b:find("^MULTIACTIONBAR2") then return "S" .. n end
  return nil
end
function GetBindingText(k) return k end
function GetMinimapZoneText() return "Raven Hill" end
function GetMoney() return 12453210 end
function GetMoneyString() return "1.245 |cffffd100o|r 32 |cffc0c0c0p|r 10 |cffb87333c|r" end
function GetCursorPosition() return 0, 0 end
function GetInventorySlotInfo(name) return ({ HeadSlot = 1, NeckSlot = 2, ShoulderSlot = 3, BackSlot = 15, ChestSlot = 5,
  ShirtSlot = 4, TabardSlot = 19, WristSlot = 9, HandsSlot = 10, WaistSlot = 6, LegsSlot = 7, FeetSlot = 8,
  Finger0Slot = 11, Finger1Slot = 12, Trinket0Slot = 13, Trinket1Slot = 14, MainHandSlot = 16, SecondaryHandSlot = 17,
  RangedSlot = 18 })[name] end
function GetInventoryItemTexture(_, slot)
  if slot == 4 or slot == 19 then return nil end
  if slot >= 30 then return "ICON:bag" end
  return "ICON:" .. (slot % 24)
end
function GetInventoryItemQuality(_, slot) return ({ 4, 3, 2, 4, 1, 3, 4, 2, 5, 3 })[slot % 10 + 1] end
ITEM_QUALITY_COLORS = { [0] = { r = 0.62, g = 0.62, b = 0.62 }, [1] = { r = 1, g = 1, b = 1 }, [2] = { r = 0.12, g = 1, b = 0 },
  [3] = { r = 0, g = 0.44, b = 0.87 }, [4] = { r = 0.64, g = 0.21, b = 0.93 }, [5] = { r = 1, g = 0.5, b = 0 } }
C_Container = {
  GetContainerNumSlots = function(bag) if bag == 0 then return 16 elseif bag <= 4 then return 16 elseif bag == 5 then return 0 end return 0 end,
  GetContainerItemInfo = function(bag, slot)
    local k = bag * 16 + slot
    if k > 14 then return nil end
    return { iconFileID = "ICON:" .. ((k * 5) % 24), stackCount = ({ 1, 20, 1, 12, 87, 3, 1, 200, 54, 1, 5, 1, 1, 9 })[k] or 1,
      quality = ({ 4, 1, 3, 1, 2, 3, 0, 1, 1, 2, 4, 1, 3, 2 })[k] or 1, itemID = k }
  end,
  ContainerIDToInventoryID = function(bag) return 30 + bag end,
}
C_Item = { GetItemInfoInstant = function(id) return id, "", "", "", 1, ({ 2, 0, 4, 0, 7, 3, 15, 7, 7, 4, 2, 0, 4, 5 })[id] or 0, 0 end }
function SetItemButtonTexture(b, t) b.icon:SetTexture(t) end
function SetItemButtonCount(b, n) b.Count:SetText(n and n > 1 and n or "") end
C_UnitAuras = {
  GetAuraDataByIndex = function(unit, i, filter)
    if unit == "target" and i <= 3 then return { icon = "ICON:" .. (i + 2), applications = (i == 2) and 2 or 0, duration = 10, expirationTime = 15, auraInstanceID = i } end
    if unit == "player" and filter == "HELPFUL" and i <= 5 then return { icon = "ICON:" .. (i + 5), applications = 0, duration = 60, expirationTime = 70, auraInstanceID = i } end
    if unit == "player" and filter == "HARMFUL" and i <= 2 then return { icon = "ICON:" .. (i + 7), applications = i, duration = 6, expirationTime = 9, auraInstanceID = 10 + i } end
    return nil
  end,
}
C_Timer = { After = function(_, fn) fn() end }
function GetTime() return 100 end
function GetRuneCooldown() return 0, 0, true end
function IsModifiedClick() return false end
function hooksecurefunc() end
function RegisterStateDriver() end
function RegisterUnitWatch() end
function print() end
SlashCmdList = {}
UISpecialFrames = {}
Enum = { PowerType = { Mana = 0, Rage = 1, Focus = 2, Energy = 3, ComboPoints = 4, Runes = 5, RunicPower = 6,
  SoulShards = 7, HolyPower = 9, Chi = 12, ArcaneCharges = 16 } }
PowerBarColor = setmetatable({}, { __index = function() return { r = 0.5, g = 0.5, b = 0.5 } end })
CurveConstants = { ScaleTo100 = 1 }
-- Blizzard's player cast bar, mid-cast.
PlayerCastingBarFrame = CreateFrame("StatusBar", "PlayerCastingBarFrame", UIParent)
PlayerCastingBarFrame:SetMinMaxValues(0, 1); PlayerCastingBarFrame:SetValue(0.58)
PlayerCastingBarFrame.Icon = PlayerCastingBarFrame:CreateTexture(nil, "OVERLAY"); PlayerCastingBarFrame.Icon:SetTexture("ICON:3")
PlayerCastingBarFrame.Text = PlayerCastingBarFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
PlayerCastingBarFrame.Text:SetText("Bola de Fogo")
-- Reactions and classes for health colors (hostile wolf, friendly pet, the player is a rogue).
function UnitIsTapDenied() return false end
function UnitIsPlayer(u) return u == "player" or u == "targettarget" end
local REACTION = { target = 2, focus = 2, pet = 5, targettarget = 5 }
function UnitReaction(u) return REACTION[u] end
RAID_CLASS_COLORS = { ROGUE = { r = 1.0, g = 0.96, b = 0.41 } }
-- The wolf is casting too: Blizzard's target cast bar, adopted by our target frame.
TargetFrameSpellBar = CreateFrame("StatusBar", "TargetFrameSpellBar", UIParent)
TargetFrameSpellBar:SetMinMaxValues(0, 1); TargetFrameSpellBar:SetValue(0.35)
TargetFrameSpellBar.Text = TargetFrameSpellBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
TargetFrameSpellBar.Text:SetText("Uivo Aterrorizante")
TargetFrameSpellBar.Text:SetPoint("CENTER")
-- Player state shown in the health orb: in combat and leading a group.
function UnitAffectingCombat(u) return u == "player" end
function IsResting() return false end
function UnitIsGroupLeader(u) return u == "player" end
