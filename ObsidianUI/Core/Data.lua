local _, ns = ...

-- Pure data: texture coordinates from the design spec, colors, class rules and slot maps.
local Data = {}
ns.Data = Data

-- Bottom HUD (full virtual texture 2692x381; left half is mirrored to the right). Spec 4.2.
Data.HUD = {
  width = 2692, height = 381, half = 1346,
  -- Ring opening is x 66-317, y 52-307; the orb tucks 4px under the ring so no gap shows.
  orb = { x = 62, y = 48, w = 260, h = 264 },
  menuCols = { 429, 488, 547 }, menuRows = { 143, 202, 262 }, menuSlot = { w = 35, h = 41 },
  barCols = { 710, 782, 853, 925, 997, 1069, 1140, 1211, 1283 }, barRows = { 114, 215 },
  barSlot = { w = 56, h = 61 },
  xp = { x = 730, y = 341, h = 16 },
}

-- Vertical bars. Spec 4.5.
Data.VBAR1 = { w = 156, h = 1279, cols = { 38 }, slot = { w = 78, h = 75 },
  rows = { 72, 168, 265, 361, 458, 554, 651, 748, 844, 941, 1037, 1133 } }
Data.VBAR2 = { w = 256, h = 1279, cols = { 38, 138 }, slot = { w = 78, h = 75 }, rows = Data.VBAR1.rows }

-- Unit frames. Spec 4.6 and 7.1.
Data.TARGET = { w = 1298, h = 458, portrait = { x = 104, y = 72, w = 296, h = 302 },
  name = { x = 490, y = 105, w = 580, h = 80 }, health = { x = 456, y = 202, w = 784, h = 55 },
  power = { x = 461, y = 272, w = 543, h = 24 } }
Data.UNIT_SMALL = { w = 1274, h = 494, portrait = { x = 67, y = 66, w = 351, h = 360 },
  name = { x = 495, y = 108, w = 735, h = 66 }, health = { x = 502, y = 208, w = 724, h = 72 },
  power = { x = 507, y = 320, w = 708, h = 40 } }
Data.FOCUS = { w = 1252, h = 486, portrait = { x = 62, y = 60, w = 358, h = 364 },
  name = { x = 492, y = 116, w = 720, h = 72 }, health = { x = 500, y = 210, w = 712, h = 68 },
  power = { x = 500, y = 296, w = 700, h = 38 } }
Data.CASTBAR = { w = 1320, h = 176, icon = { x = 56, y = 40, w = 90, h = 88 }, bar = { x = 196, y = 56, w = 1058, h = 62 } }
Data.MINIMAP = { w = 1008, h = 1012, map = { x = 86, y = 88, w = 837, h = 836 },
  plate = { x = 350, y = 10, w = 310, h = 66 },
  sockets = { { 180, 824 }, { 348, 932 }, { 660, 932 }, { 826, 824 } }, socketSize = 56 }

-- Inventory window. Spec 4.10.
Data.INV = { w = 690, h = 1334,
  title = { x = 187, y = 31, w = 315, h = 39 },
  model = { x = 168, y = 95, w = 350, h = 375 },
  -- Equipment frames and the tab row are redrawn by tools/inventory_art.py.
  equipCols = { 96.5, 591.5 }, equipTop = 106, equipPitch = 70.75, equipSize = 62,
  weapons = { 182, 294, 406 }, weaponY = 518, weaponSize = 100, weaponInset = 9,
  tabs = { 42, 151, 260, 369, 478 }, tabY = 705, tabW = 95, tabH = 34,
  sort = { x = 589, y = 705, w = 34, h = 34 },
  gridCols = { 44, 116, 189, 261, 333, 405, 478, 550 }, gridRows = { 761, 841, 918, 995, 1072, 1149 },
  gridSlot = 59, gridPitchY = 77.6,
  bags = { 42, 119, 196, 273, 350 }, bagY = 1234, bagW = 64, bagH = 66,
  gold = { x = 445, y = 1247, w = 202, h = 38 } }

-- Orb colors (Global Constraints of the plan).
Data.ORB_COLORS = {
  HEALTH = { r = 0.78, g = 0.16, b = 0.12 },
  MANA = { r = 0.18, g = 0.39, b = 0.84 },
  RAGE = { r = 0.62, g = 0.08, b = 0.05 },
  ENERGY = { r = 0.95, g = 0.80, b = 0.10 },
  FOCUS = { r = 0.95, g = 0.50, b = 0.12 },
  RUNIC_POWER = { r = 0.00, g = 0.78, b = 0.92 },
}

function Data.PowerColor(token)
  local c = Data.ORB_COLORS[token] or (PowerBarColor and PowerBarColor[token]) or Data.ORB_COLORS.MANA
  return c.r, c.g, c.b
end

-- Unit frame health: grey when tapped by someone else, class color for players, else reaction.
local HOSTILE, NEUTRAL, FRIENDLY = { 0.78, 0.16, 0.12 }, { 0.85, 0.70, 0.15 }, { 0.20, 0.62, 0.18 }
function Data.HealthColor(tapDenied, classColor, reaction)
  if tapDenied then return 0.5, 0.5, 0.5 end
  if classColor then return classColor.r, classColor.g, classColor.b end
  local c = HOSTILE
  if reaction == 4 then c = NEUTRAL elseif reaction and reaction >= 5 then c = FRIENDLY end
  return c[1], c[2], c[3]
end

-- Debuff border by dispel type (Blizzard's DebuffTypeColor), red when undispellable.
local DISPEL = { Magic = { 0.2, 0.6, 1.0 }, Curse = { 0.6, 0.0, 1.0 }, Disease = { 0.6, 0.4, 0.0 },
  Poison = { 0.0, 0.6, 0.0 } }
function Data.DebuffColor(dispelName)
  local c = dispelName and DISPEL[dispelName] or { 0.77, 0.15, 0.11 }
  return c[1], c[2], c[3]
end

-- State icons in the health orb: combat replaces resting (like the player frame), then leader.
function Data.PlayerStatusIcons(inCombat, resting, leader)
  local list = {}
  if inCombat then list[#list + 1] = "combat" elseif resting then list[#list + 1] = "rest" end
  if leader then list[#list + 1] = "leader" end
  return list
end

-- x offset for a SecureAuraHeader anchored by its first icon's TOP, so a row of `count`
-- icons (wrapping after `wrapAfter`) is centered on the anchor.
function Data.AuraRowOffset(count, wrapAfter, step)
  local n = math.min(count, wrapAfter)
  if n <= 1 then return 0 end
  return -(n - 1) * step / 2
end

-- Secondary class resources shown as gems.
local GOLD, LIGHT, PURPLE, CYAN, JADE, ARCANE =
  { 1.00, 0.76, 0.23 }, { 0.95, 0.90, 0.60 }, { 0.64, 0.21, 0.93 }, { 0.00, 0.78, 0.92 }, { 0.31, 0.88, 0.63 }, { 0.44, 0.63, 1.00 }

function Data.ClassResourceFor(classToken, specIndex, unitPowerType)
  local P = Enum.PowerType
  -- token: the powerType string UNIT_POWER_FREQUENT passes, so other resources' ticks are skipped.
  local function r(pt, token, color)
    return { powerType = pt, token = token, color = { r = color[1], g = color[2], b = color[3] } }
  end
  if classToken == "ROGUE" then return r(P.ComboPoints, "COMBO_POINTS", GOLD) end
  if classToken == "DRUID" then
    if unitPowerType == P.Energy then return r(P.ComboPoints, "COMBO_POINTS", GOLD) end
    return nil
  end
  if classToken == "PALADIN" then return r(P.HolyPower, "HOLY_POWER", LIGHT) end
  if classToken == "WARLOCK" then return r(P.SoulShards, "SOUL_SHARDS", PURPLE) end
  if classToken == "DEATHKNIGHT" then return r(P.Runes, "RUNES", CYAN) end
  if classToken == "MONK" and specIndex == 3 then return r(P.Chi, "CHI", JADE) end
  if classToken == "MAGE" and specIndex == 1 then return r(P.ArcaneCharges, "ARCANE_CHARGES", ARCANE) end
  return nil
end

-- Menu panels: 9 buttons per side. Candidates are micro button names, first existing wins.
Data.MENU_LEFT = {
  { id = "character", label = "Personagem", candidates = { "CharacterMicroButton" } },
  { id = "spellbook", label = "Grimório", candidates = { "SpellbookMicroButton", "PlayerSpellsMicroButton" } },
  { id = "talents", label = "Talentos", candidates = { "TalentMicroButton", "PlayerSpellsMicroButton" } },
  { id = "professions", label = "Profissões", candidates = { "ProfessionMicroButton" } },
  { id = "achievements", label = "Conquistas", candidates = { "AchievementMicroButton" } },
  { id = "questlog", label = "Diário de Missões", candidates = { "QuestLogMicroButton" } },
  { id = "guild", label = "Guilda e Comunidades", candidates = { "GuildMicroButton", "SocialsMicroButton" } },
  { id = "collections", label = "Coleções", candidates = { "CollectionsMicroButton" } },
  { id = "gamemenu", label = "Menu do Jogo", candidates = { "MainMenuMicroButton" } },
}
Data.MENU_RIGHT = {
  { id = "bag0", label = "Mochila", bag = 0 },
  { id = "bag1", label = "Bolsa 1", bag = 1 },
  { id = "bag2", label = "Bolsa 2", bag = 2 },
  { id = "bag3", label = "Bolsa 3", bag = 3 },
  { id = "bag4", label = "Bolsa 4", bag = 4 },
  { id = "reagent", label = "Bolsa de Reagentes", bag = 5 },
  { id = "social", label = "Social", candidates = { "FriendsMicroButton", "QuickJoinToastButton" } },
  { id = "lfg", label = "Procurar Grupo", candidates = { "LFDMicroButton", "GroupFinderMicroButton" } },
  { id = "pvp", label = "JxJ", candidates = { "PVPMicroButton", "LFDMicroButton" } },
}

Data.EQUIP_LEFT = { "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot" }
Data.EQUIP_RIGHT = { "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot" }
Data.WEAPONS = { "MainHandSlot", "SecondaryHandSlot", "RangedSlot" }

-- Central action bar: 2 rows x 18 columns -> action slots and key bindings.
Data.ACTION_LAYOUT = { {}, {} }
for c = 1, 12 do
  Data.ACTION_LAYOUT[1][c] = { bar = "main", actionID = c, binding = "ACTIONBUTTON" .. c }
  Data.ACTION_LAYOUT[2][c] = { bar = "bottomright", actionID = 48 + c, binding = "MULTIACTIONBAR2BUTTON" .. c }
end
for i = 1, 6 do
  Data.ACTION_LAYOUT[1][12 + i] = { bar = "bottomleft", actionID = 60 + i, binding = "MULTIACTIONBAR1BUTTON" .. i }
  Data.ACTION_LAYOUT[2][12 + i] = { bar = "bottomleft", actionID = 66 + i, binding = "MULTIACTIONBAR1BUTTON" .. (6 + i) }
end

Data.VBAR_ACTIONS = { {}, {} }
for i = 1, 12 do
  Data.VBAR_ACTIONS[1][i] = { actionID = 24 + i, binding = "MULTIACTIONBAR3BUTTON" .. i }
  Data.VBAR_ACTIONS[2][i] = { actionID = 36 + i, binding = "MULTIACTIONBAR4BUTTON" .. i }
end

-- State driver for the paged top row (vehicles, override, possess, stances, druid forms).
function Data.PagingDriver()
  return "[vehicleui] 12; [overridebar] 14; [possessbar] 12; [shapeshift] 13; [bonusbar:5] 11; "
    .. "[bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10; "
    .. "[bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; 1"
end

-- Alternative global names for Blizzard frames, first existing wins (checked by /obui diag).
Data.FRAME_CANDIDATES = {
  mainbar = { "MainActionBar", "MainMenuBar" },
  multibl = { "MultiBarBottomLeft" }, multibr = { "MultiBarBottomRight" },
  multir = { "MultiBarRight" }, multil = { "MultiBarLeft" },
  multibar5 = { "MultiBar5" }, multibar6 = { "MultiBar6" }, multibar7 = { "MultiBar7" },
  overridebar = { "OverrideActionBar" },
  micromenu = { "MicroMenuContainer", "MicroButtonAndBagsBar" },
  bagsbar = { "BagsBar" },
  statusbar = { "StatusTrackingBarManager", "MainStatusTrackingBarContainer" },
  playerframe = { "PlayerFrame" }, targetframe = { "TargetFrame" }, focusframe = { "FocusFrame" },
  buffframe = { "BuffFrame" }, debuffframe = { "DebuffFrame" },
  castbar = { "PlayerCastingBarFrame", "CastingBarFrame" },
  targetcastbar = { "TargetFrameSpellBar" }, focuscastbar = { "FocusFrameSpellBar" },
  stancebar = { "StanceBar", "StanceBarFrame" },
  petbar = { "PetActionBar", "PetActionBarFrame" },
  extrabutton = { "ExtraActionBarFrame" }, zoneability = { "ZoneAbilityFrame" },
  vehicleleave = { "MainMenuBarVehicleLeaveButton" },
  minimapcluster = { "MinimapCluster" },
  clock = { "TimeManagerClockButton" },
  mail = { "MiniMapMailIcon", "MiniMapMailFrame" },
  tracking = { "MiniMapTrackingButton", "MiniMapTracking" },
  calendar = { "GameTimeFrame" },
  objectivetracker = { "ObjectiveTrackerFrame", "QuestWatchFrame" },
  combinedbags = { "ContainerFrameCombinedBags" },
  queue = { "QueueStatusButton", "QueueStatusMinimapButton", "MiniMapLFGFrame" },
  difficulty = { "MiniMapInstanceDifficulty" },
  durability = { "DurabilityFrame" },
  lootrolls = { "GroupLootContainer" },
  mirrortimers = { "MirrorTimerContainer", "MirrorTimer1" },
}
