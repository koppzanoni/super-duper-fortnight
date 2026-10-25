local _, ns = ...

-- Pure data: texture coordinates of the HUD art, colors, class rules and slot maps.
local Data = {}
ns.Data = Data

-- Resource colours (bars, fills).
Data.POWER_COLORS = {
  HEALTH = { r = 0.78, g = 0.16, b = 0.12 },
  MANA = { r = 0.18, g = 0.39, b = 0.84 },
  RAGE = { r = 0.62, g = 0.08, b = 0.05 },
  ENERGY = { r = 0.95, g = 0.80, b = 0.10 },
  FOCUS = { r = 0.95, g = 0.50, b = 0.12 },
  RUNIC_POWER = { r = 0.00, g = 0.78, b = 0.92 },
}

function Data.PowerColor(token)
  local c = Data.POWER_COLORS[token] or (PowerBarColor and PowerBarColor[token]) or Data.POWER_COLORS.MANA
  return c.r, c.g, c.b
end

-- HUD (tools/modern_art.py; spec docs/superpowers/specs/2026-10-23-hud-moderno-design.md).
-- Unit frame: portrait opening inside the ring, the bar grooves, name and level spots.
Data.MODERN_UNIT = { w = 720, h = 250, ring = { x = 12, y = 12, w = 220, h = 220 },
  portrait = { x = 28, y = 28, w = 188, h = 188 }, name = { x = 250, y = 26, w = 454, h = 54 },
  health = { x = 186, y = 91, w = 508, h = 50 }, power = { x = 186, y = 157, w = 500, h = 38 },
  level = { x = 103, y = 212, w = 38, h = 38 } }
-- Cast bar: one panel with the square icon socket, the progress groove and the name above it.
Data.MODERN_CAST = { w = 940, h = 132, icon = { x = 22, y = 22, w = 88, h = 88 },
  bar = { x = 134, y = 68, w = 776, h = 40 }, name = { x = 140, y = 16, w = 480, h = 40 } }
-- Minimap: the ring's opening, the zone plate and the round button beside it.
Data.MODERN_MAP = { w = 340, h = 376, hole = { x = 26, y = 72, w = 288, h = 286 },
  plate = { x = 10, y = 4, w = 260, h = 46 }, button = { x = 282, y = 4, w = 48, h = 48 } }
Data.MODERN_MAP.map = Data.MODERN_MAP.hole
-- Socket centers (clock, mail, tracking, calendar): the clock under the ring,
-- mail and tracking on its lower edge, the calendar in the round button beside the zone plate.
Data.MODERN_MAP.sockets = { { 170, 378 }, { 62, 318 }, { 278, 318 }, { 306, 28 } }
Data.MODERN_MAP.socketSize = 44
-- One action slot frame (the icon sits 10 px inside it).
Data.MODERN_SLOT = { size = 104, inset = 10 }

-- Moderno inventory (prototype in the sketch): one wide window in design units, the character on
-- the left (model, 8 + 8 equipment slots, 3 weapons, the Attributes/Reputation/Currency tabs and
-- the stats in two columns) and the bags on the right (search and sort, filter tabs, a grid of 9
-- columns with a thin scroll bar, the equipped bags, free slots and gold).
Data.INV = { w = 1240, h = 780,
  head = 48, title = { x = 24, y = 9, w = 760, h = 30 }, close = { x = 1186, y = 9, w = 30, h = 30 },
  model = { x = 112, y = 60, w = 356, h = 440 },
  equipCols = { 63, 517 }, equipTop = 60, equipPitch = 64, equipSize = 58, -- columns by their centre
  weapons = { 183, 259, 335 }, weaponY = 510, weaponSize = 58,
  charTabs = { x = 34, y = 584, w = 110, h = 30, gap = 6 },
  stats = { x = 34, y = 624, w = 512, h = 126, padX = 14, padY = 8, colGap = 28, maxRow = 22 },
  sep = 578,
  search = { x = 598, y = 60, w = 568, h = 34 }, sort = { x = 1180, y = 60, w = 34, h = 34 },
  tabs = { x = 598, y = 106, w = 616, h = 30, gap = 6 },
  grid = { x = 598, y = 150, cols = 9, rows = 7, slot = 62, gap = 6 },
  scroll = { x = 1214, y = 150, w = 5, h = 470, thumbH = 120 },
  bags = { x = 598, y = 702, size = 40, gap = 6 }, free = { x = 838, y = 702, w = 160, h = 40 },
  gold = { x = 1014, y = 702, w = 200, h = 40 } }

-- Bank (Inventory/Bank.lua), in the inventory's design units. One bank pane, placed by the chosen
-- model: window (its own window left of the inventory), side (over the character half), inside
-- (over the bag grid, the search and the gold stay). Pane rows: bar (Personagem/Conta, deposit,
-- sort), the grid (as many columns as fit), the foot (bank bags, free slots).
Data.BANK_STYLES = { { "window", "Janela própria" }, { "side", "Ao lado das bolsas" }, { "inside", "Dentro do inventário" } }
Data.BANK = { win = { w = 1000, head = 48, pane = { x = 20, y = 60, w = 960, h = 700 } },
  side = { x = 16, y = 60, w = 552, h = 690 }, inside = { x = 598, y = 106, w = 616, h = 636 },
  bar = 34, kindW = 124, depositW = 150, gap = 12, foot = 40, bag = 40, bagGap = 6, freeW = 200,
  switch = { w = 104, h = 30, gap = 6, right = 1176 } }

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

-- Auras of a unit for one filter, in game order, at most `max`. Counted by hand: in combat,
-- indexed iteration over GetUnitAuras' list can yield secret indexes.
function Data.UnitAuraList(unit, filter, max)
  local list = {}
  if C_UnitAuras.GetUnitAuras then
    for _, aura in ipairs(C_UnitAuras.GetUnitAuras(unit, filter) or {}) do
      list[#list + 1] = aura
      if #list >= max then break end
    end
  else
    for i = 1, max do
      local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
      if not aura then break end
      list[i] = aura
    end
  end
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
  -- Same 5 bags as the inventory footer (no reagent bags in this game's content).
  { id = "journal", label = "Guia de Aventura", candidates = { "EJMicroButton" } },
  -- No social micro button on this client (the chat's social button has no plain icon).
  { id = "social", label = "Social", candidates = { "FriendsMicroButton", "QuickJoinToastButton" },
    icon = "Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon" },
  { id = "lfg", label = "Procurar Grupo", candidates = { "LFDMicroButton", "GroupFinderMicroButton" } },
  { id = "pvp", label = "JxJ", candidates = { "PVPMicroButton", "LFDMicroButton" } },
}

-- Moderno: the micro menu is one row (bottom right); these entries of the two lists above, in order.
Data.MODERN_MENU = { "character", "spellbook", "talents", "achievements", "questlog", "guild", "collections",
  "lfg", "journal", "gamemenu" }

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
  partyframe = { "PartyFrame" }, compactparty = { "CompactPartyFrame" },
  raidmanager = { "CompactRaidFrameManager" }, raidcontainer = { "CompactRaidFrameContainer" },
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
