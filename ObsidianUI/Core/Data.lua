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
-- Only the slots of the Meshy vertical bar art, by tools/vbar_art.py (12 rows; one or two columns).
Data.VBAR1 = { w = 64, h = 935, cols = { 4 }, slot = { w = 56, h = 59 },
  rows = { 4, 84, 164, 244, 323, 401, 481, 559, 637, 716, 793, 871 } }
Data.VBAR2 = { w = 138, h = 935, cols = { 4, 78 }, slot = { w = 56, h = 59 }, rows = Data.VBAR1.rows }

-- Unit frames (target, focus, target-of-target, pet): the chosen party frame B art
-- (tools/unit_art.py). Ring opening x 50-186, y 20-156: the portrait tucks 3px under the ring.
-- Name plate x 208-518 y 30-70, health groove x 214-516 y 82-112, mana groove x 214-516 y 126-148.
Data.UNIT = { w = 530, h = 177, portrait = { x = 47, y = 17, w = 142, h = 142 },
  name = { x = 216, y = 32, w = 296, h = 36 }, health = { x = 214, y = 82, w = 302, h = 30 },
  power = { x = 214, y = 126, w = 302, h = 22 } }
-- Player cast bar in the unit frame style (tools/unit_art.py castbar): round icon socket x 48-173
-- y 17-143 (the icon sits just inside it, masked round), thin groove x 197-1135 y 43-124.
Data.CASTBAR = { w = 1151, h = 161, icon = { x = 50, y = 19, w = 121, h = 122 }, bar = { x = 197, y = 43, w = 938, h = 81 } }
-- Ring opening is x 85-922, y 87-925; the map tucks 3px under the ring.
Data.MINIMAP = { w = 1008, h = 1012, map = { x = 82, y = 84, w = 844, h = 844 },
  plate = { x = 350, y = 10, w = 310, h = 66 },
  sockets = { { 180, 824 }, { 348, 932 }, { 660, 932 }, { 826, 824 } }, socketSize = 56 }

-- HUD style "Moderno" (tools/modern_art.py; spec docs/superpowers/specs/2026-10-23-hud-moderno-design.md).
-- Unit frame: portrait opening inside the ring, the bar grooves, name and level spots.
Data.MODERN_UNIT = { w = 720, h = 250, ring = { x = 12, y = 12, w = 220, h = 220 },
  portrait = { x = 28, y = 28, w = 188, h = 188 }, name = { x = 250, y = 26, w = 454, h = 54 },
  health = { x = 186, y = 91, w = 508, h = 50 }, power = { x = 186, y = 157, w = 500, h = 38 },
  level = { x = 4, y = 168, w = 76, h = 76 } }
-- Cast bar: square icon socket, progress groove, name on the tab above it.
Data.MODERN_CAST = { w = 940, h = 124, icon = { x = 14, y = 14, w = 96, h = 96 },
  bar = { x = 122, y = 64, w = 784, h = 42 }, name = { x = 140, y = 12, w = 370, h = 48 } }
-- Minimap: the ring's opening, the zone plate and the round button beside it.
Data.MODERN_MAP = { w = 340, h = 360, hole = { x = 26, y = 72, w = 288, h = 286 },
  plate = { x = 10, y = 4, w = 260, h = 46 }, button = { x = 282, y = 4, w = 48, h = 48 } }
-- One action slot frame (the icon sits 10 px inside it).
Data.MODERN_SLOT = { size = 104, inset = 10 }

-- Inventory window. Spec 4.10.
Data.INV = { w = 690, h = 1334,
  title = { x = 187, y = 31, w = 315, h = 39 },
  model = { x = 168, y = 95, w = 350, h = 488 },
  -- Equipment frames and the tab row are redrawn by tools/inventory_art.py.
  equipCols = { 96.5, 591.5 }, equipTop = 104, equipPitch = 70.75, equipSize = 65,
  weapons = { 197.5, 309.5, 421.5 }, weaponY = 589, weaponSize = 69, weaponInset = 2,
  tabs = { 42, 151, 260, 369, 478 }, tabY = 705, tabW = 95, tabH = 34,
  sort = { x = 589, y = 705, w = 34, h = 34 },
  gridCols = { 44, 116, 189, 261, 333, 405, 478, 550 }, gridRows = { 761, 841, 918, 995, 1072, 1149 },
  gridSlot = 59, gridPitchY = 77.6,
  -- Bag scroll bar on the rail painted in the art (tools/inventory_art.py SCROLL_*).
  scroll = { up = { x = 629, y = 750, w = 23, h = 22 }, down = { x = 629, y = 1199, w = 23, h = 22 },
    track = { x = 634, y = 774, w = 13, h = 423 }, thumbH = 64 },
  -- Each item button's own slot frame (texture bag_slot), relative to the button.
  gridFrame = { dx = -2, dy = -4, w = 65, h = 70 },
  bags = { 42, 119, 196, 273, 350 }, bagY = 1234, bagW = 64, bagH = 66,
  gold = { x = 445, y = 1247, w = 202, h = 38 },
  -- Stats wing (art pixels of its own texture, built by tools/inventory_art.py).
  wing = { w = 400, overlap = 28, title = { x = 40, y = 33, w = 292, h = 37 },
    rows = { x0 = 52, x1 = 340, top = 104, row = 36, header = 46, gap = 14 },
    search = { x = 44, y = 1170, w = 296, h = 44 },
    buttons = { x0 = 44, x1 = 340, gap = 10, y = 1236, h = 50 } } }

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

-- Orb liquid styles (setting "orbStyle"; spec docs/superpowers/specs/2026-10-22-orbes-liquido-design.md).
-- sheet: flipbook texture; fps: flipbook speed; wisp/wisp2: strength of the wisp layers;
-- spin/spin2: their turn speed (rad/s); core: pulsing core glow; sparks: rising bubbles;
-- still: no animation, shows stillFrame.
-- Orb cap art, per side (the right one is mirrored); over: drawn above the orb liquid.
Data.CAP_STYLE_ORDER = { "classic", "relic" }
Data.CAP_STYLES = {
  classic = { label = "Clássico", left = "hud_cap", right = "hud_cap" },
  relic = { label = "Relicário", left = "hud_cap_claws", right = "hud_cap_dragon",
    overLeft = "hud_cap_claws_over", overRight = "hud_cap_dragon_over" },
}
Data.ORB_STYLE_ORDER = { "a", "b", "c", "d" }
Data.ORB_STYLE_LABELS = { a = "Redemoinho", b = "Energia", c = "Névoa", d = "Parado" }
Data.ORB_STYLES = {
  a = { sheet = "fluid_a", fps = 7, wisp = 0.62, wisp2 = 0.22, spin = 0.05, spin2 = -0.03, core = 0, sparks = false },
  b = { sheet = "fluid_b", fps = 7, wisp = 0.70, wisp2 = 0.30, spin = 0.08, spin2 = -0.045, core = 0.5, sparks = true },
  c = { sheet = "fluid_c", fps = 7, wisp = 0.55, wisp2 = 0, spin = 0.02, spin2 = 0, core = 0, sparks = false },
  d = { sheet = "fluid_a", fps = 0, wisp = 0.62, wisp2 = 0.22, spin = 0, spin2 = 0, core = 0, sparks = false,
    still = true, stillFrame = 21 },
}

function Data.OrbStyle(key)
  if Data.ORB_STYLES[key] then return key end
  return "a"
end

-- Texture coordinates of flipbook frame i (0-based, wraps) in an 8x8 sheet.
local FLIP_GRID, FLIP_FRAMES = 8, 64
function Data.FlipbookCoords(i)
  i = math.floor(i) % FLIP_FRAMES
  local col, row = i % FLIP_GRID, math.floor(i / FLIP_GRID)
  return col / FLIP_GRID, (col + 1) / FLIP_GRID, row / FLIP_GRID, (row + 1) / FLIP_GRID
end

-- Liquid tones: deep (bottom), body, wisps and surface line. Health and mana are tuned by
-- hand; other resources are derived from their color.
local function rgb(r, g, b) return { r / 255, g / 255, b / 255 } end
local PALETTES = {
  HEALTH = { deep = rgb(12, 0, 2), body = rgb(62, 2, 7), wisp = rgb(230, 46, 30), line = rgb(255, 150, 110) },
  MANA = { deep = rgb(0, 3, 16), body = rgb(5, 22, 80), wisp = rgb(44, 130, 245), line = rgb(170, 220, 255) },
}
function Data.OrbPalette(token)
  if PALETTES[token] then return PALETTES[token] end
  local r, g, b = Data.PowerColor(token)
  local function scale(k) return { r * k, g * k, b * k } end
  local function lift(k) return { r + (1 - r) * k, g + (1 - g) * k, b + (1 - b) * k } end
  return { deep = scale(0.08), body = scale(0.35), wisp = lift(0.10), line = lift(0.55) }
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
