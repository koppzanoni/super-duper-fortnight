local _, ns = ...

-- Party and raid frames. Party: the Moderno unit frames (small kind) stacked down on the left,
-- shown in a party and hidden in a raid. Raid: a grid of compact cells by subgroup (a group per
-- row or per column), class-coloured health, name, a thin power line, tank/healer icon, dead and
-- offline text, a border in the colour of a debuff the player can dispel, faded when out of range.
-- The party can include you on top ("partyPlayer") and can use the raid cells instead
-- ("partyStyle" = "cells"). Every member also shows up to a few debuffs, its raid marker and its
-- ready check answer. Both are secure and only move or change out of combat. Test mode shows
-- stand-ins (party or raid) to place and size them while solo; combat ends it.
local GroupFrames = { party = {}, raid = {}, partyCells = {}, testing = nil }
ns.GroupFrames = GroupFrames

local PARTY, RAID, TEST_RAID = 4, 40, 20
local CELL_GAP = 3
local ROLE_TEX = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
local ROLE_COORDS = { TANK = { 0, 19 / 64, 22 / 64, 41 / 64 }, HEALER = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 } }
local FAKE_CLASSES = { "WARRIOR", "PRIEST", "MAGE", "HUNTER", "PALADIN", "DRUID", "ROGUE", "SHAMAN", "WARLOCK" }
local FAKE_NAMES = { "Thoradin", "Elune", "Kaelis", "Brann", "Lyra", "Garrosk", "Mirela", "Tarek", "Velis", "Durgan" }

local function db() return ns.db or {} end
local function on(key) return db()[key] ~= false end
local function scale() local _, H = UIParent:GetSize(); return H / 1080 end

-- Stand-in member i for the test mode.
local function fake(i)
  return { name = FAKE_NAMES[(i - 1) % #FAKE_NAMES + 1], class = FAKE_CLASSES[(i - 1) % #FAKE_CLASSES + 1],
    role = i % 5 == 1 and "TANK" or (i % 5 == 2 and "HEALER" or "DAMAGER"), hp = 10000 - (i * 1370) % 7000,
    power = 40 + (i * 17) % 60, dead = i == 6, group = math.floor((i - 1) / 5) + 1, level = 60,
    marker = ({ [1] = 8, [2] = 1 })[i], debuffs = i == 3 and 2 or 0 }
end

-- ------------------------------------------------------------------ holders
local partyHolder = CreateFrame("Frame", "ObsidianUIParty", UIParent, "SecureHandlerStateTemplate")
local raidHolder = CreateFrame("Frame", "ObsidianUIRaid", UIParent, "SecureHandlerStateTemplate")
partyHolder:SetSize(1, 1)
raidHolder:SetSize(1, 1)
GroupFrames.partyHolder, GroupFrames.raidHolder = partyHolder, raidHolder

-- ------------------------------------------------------------------ raid cells
local function edge(c, layer)
  local t = c:CreateTexture(nil, layer)
  t:SetColorTexture(1, 1, 1, 1)
  return t
end

-- ------------------------------------------------------------------ debuffs, marker, ready check
local MAX_DEBUFFS = 3
local MARKER_TEX = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local readyActive = false

-- Debuff icons (in the action slots' frame), the raid marker and the ready check icon on a cell
-- or a party frame. host: what the icons draw over (the cell's health bar or the frame).
local function addExtras(owner, host)
  owner.debuffs = {}
  for i = 1, MAX_DEBUFFS do
    local d = CreateFrame("Frame", nil, owner)
    d:SetFrameLevel(host:GetFrameLevel() + 3)
    d.icon = d:CreateTexture(nil, "ARTWORK")
    d.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    d.border = d:CreateTexture(nil, "OVERLAY")
    d.border:SetAllPoints(d)
    ns.Media.Apply(d.border, ns.ModernTex("mod_slot"))
    d.count = d:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    d.count:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", 0, 0)
    d:Hide()
    owner.debuffs[i] = d
  end
  local top = CreateFrame("Frame", nil, owner)
  top:SetAllPoints(owner)
  top:SetFrameLevel(host:GetFrameLevel() + 4)
  owner.marker = top:CreateTexture(nil, "OVERLAY")
  owner.marker:SetTexture(MARKER_TEX)
  owner.marker:Hide()
  owner.ready = top:CreateTexture(nil, "OVERLAY")
  owner.ready:Hide()
end

local function sizeDebuff(d, size)
  d:SetSize(size, size)
  local inset = size * ns.Data.MODERN_SLOT.inset / ns.Data.MODERN_SLOT.size
  d.icon:ClearAllPoints()
  d.icon:SetPoint("TOPLEFT", d, "TOPLEFT", inset, -inset)
  d.icon:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -inset, inset)
  ns.Look.SetFont(d.count, math.max(8, size * 0.42))
end

-- Cell: the name across the top; along the bottom the role icon and the marker on the left and
-- the debuffs on the right, growing left; the ready check in the middle.
local function placeCellExtras(c, h)
  local size = math.max(9, h * 0.36)
  for i, d in ipairs(c.debuffs) do
    sizeDebuff(d, size)
    d:ClearAllPoints()
    d:SetPoint("BOTTOMRIGHT", c.health, "BOTTOMRIGHT", -(i - 1) * size, 0)
  end
  c.marker:SetSize(h * 0.36, h * 0.36)
  c.marker:ClearAllPoints()
  c.marker:SetPoint("BOTTOMLEFT", c.role, "BOTTOMRIGHT", 1, 0)
  c.ready:SetSize(h * 0.6, h * 0.6)
  c.ready:ClearAllPoints()
  c.ready:SetPoint("CENTER", c, "CENTER", 0, 0)
end

-- Party frame: debuffs in a row to its right, marker over the portrait, ready check on it.
local function placeFrameExtras(f)
  local h = f:GetHeight()
  local size = h * 0.42
  for i, d in ipairs(f.debuffs) do
    sizeDebuff(d, size)
    d:ClearAllPoints()
    d:SetPoint("LEFT", f, "RIGHT", 4 + (i - 1) * (size + 2), 0)
  end
  f.marker:SetSize(h * 0.3, h * 0.3)
  f.marker:ClearAllPoints()
  f.marker:SetPoint("CENTER", f.portrait, "TOP", 0, 0)
  f.ready:SetSize(h * 0.5, h * 0.5)
  f.ready:ClearAllPoints()
  f.ready:SetPoint("CENTER", f.portrait, "CENTER", 0, 0)
end

local function showDebuffs(owner, list)
  for i, d in ipairs(owner.debuffs) do
    local aura = list[i]
    d:SetShown(aura ~= nil)
    if aura then
      d.icon:SetTexture(aura.icon)
      -- stacks may be secret: shown when the text API takes them, else left out
      if not pcall(function() d.count:SetText((aura.applications or 0) > 1 and aura.applications or "") end) then
        d.count:SetText("")
      end
    end
  end
end

local function updateDebuffs(owner)
  local list = {}
  if on("groupDebuffs") and UnitExists(owner.unit) then
    local ok, got = pcall(ns.Data.UnitAuraList, owner.unit, "HARMFUL", MAX_DEBUFFS)
    if ok then list = got end
  end
  showDebuffs(owner, list)
end

local function showMarker(owner, index)
  owner.marker:SetShown(index ~= nil)
  if index then SetRaidTargetIconTexture(owner.marker, index) end
end

local function updateMarker(owner)
  -- the index may come secret: no marker then, rather than an error
  if not pcall(function() showMarker(owner, UnitExists(owner.unit) and GetRaidTargetIndex(owner.unit) or nil) end) then
    owner.marker:Hide()
  end
end

local READY_TEX = { ready = "READY_CHECK_READY_TEXTURE", notready = "READY_CHECK_NOT_READY_TEXTURE",
  waiting = "READY_CHECK_WAITING_TEXTURE" }
local function updateReady(owner)
  local status = readyActive and UnitExists(owner.unit) and GetReadyCheckStatus(owner.unit)
  local tex = status and READY_TEX[status] and _G[READY_TEX[status]]
  owner.ready:SetShown(tex ~= nil and tex ~= false)
  if tex then owner.ready:SetTexture(tex) end
end

local function updateExtras(owner)
  updateDebuffs(owner)
  updateMarker(owner)
  updateReady(owner)
end

local function fakeExtras(owner, d)
  local list = {}
  if on("groupDebuffs") then
    for i = 1, d.debuffs do list[i] = { icon = 136000 + i, applications = i } end
  end
  showDebuffs(owner, list)
  showMarker(owner, d.marker)
  owner.ready:Hide()
end

local function newCell(name, unit, parent)
  local c = CreateFrame("Button", name, parent, "SecureUnitButtonTemplate")
  c.unit, c.isCell = unit, true
  c:SetAttribute("unit", c.unit)
  c:SetAttribute("type1", "target")
  c:SetAttribute("type2", "togglemenu")
  c:RegisterForClicks("AnyUp")
  c.bg = c:CreateTexture(nil, "BACKGROUND")
  c.bg:SetAllPoints(c)
  c.bg:SetColorTexture(0, 0, 0, 0.6)
  c.health = CreateFrame("StatusBar", nil, c)
  c.health:SetMinMaxValues(0, 1)
  c.power = CreateFrame("StatusBar", nil, c)
  c.power:SetMinMaxValues(0, 1)
  -- a thin light rim like the other Moderno pieces; the dispel border sits over it
  c.rim, c.dispel = {}, {}
  for k = 1, 4 do
    c.rim[k] = edge(c, "BORDER"); c.rim[k]:SetVertexColor(1, 1, 1, 0.1)
    c.dispel[k] = edge(c.health, "OVERLAY"); c.dispel[k]:Hide()
  end
  c.name = c.health:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  c.name:SetWordWrap(false)
  c.status = c.health:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  -- a hard shadow keeps white text readable on the light class colours (priest, paladin)
  for _, t in ipairs({ c.name, c.status }) do t:SetShadowColor(0, 0, 0, 1); t:SetShadowOffset(1, -1) end
  c.role = c.health:CreateTexture(nil, "OVERLAY")
  c.role:SetTexture(ROLE_TEX)
  c:SetScript("OnEnter", function(self)
    if not UnitExists(self.unit) then return end
    GameTooltip_SetDefaultAnchor(GameTooltip, self)
    if GameTooltip:SetUnit(self.unit) then GameTooltip:Show() end
  end)
  c:SetScript("OnLeave", GameTooltip_Hide)
  addExtras(c, c.health)
  return c
end
for i = 1, RAID do GroupFrames.raid[i] = newCell("ObsidianUIRaid" .. i, "raid" .. i, raidHolder) end
-- party cells: you first, then party1..4
for i, unit in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
  GroupFrames.partyCells[i] = newCell("ObsidianUIPartyCell" .. i, unit, partyHolder)
end

local function frameEdges(list, owner, t)
  list[1]:ClearAllPoints(); list[1]:SetPoint("TOPLEFT", owner); list[1]:SetPoint("TOPRIGHT", owner); list[1]:SetHeight(t)
  list[2]:ClearAllPoints(); list[2]:SetPoint("BOTTOMLEFT", owner); list[2]:SetPoint("BOTTOMRIGHT", owner); list[2]:SetHeight(t)
  list[3]:ClearAllPoints(); list[3]:SetPoint("TOPLEFT", owner); list[3]:SetPoint("BOTTOMLEFT", owner); list[3]:SetWidth(t)
  list[4]:ClearAllPoints(); list[4]:SetPoint("TOPRIGHT", owner); list[4]:SetPoint("BOTTOMRIGHT", owner); list[4]:SetWidth(t)
end

local function sizeCell(c, w, h)
  c:SetSize(w, h)
  local powerH = math.max(2, h * 0.12)
  c.health:ClearAllPoints()
  c.health:SetPoint("TOPLEFT", c, "TOPLEFT", 1, -1)
  c.health:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -1, 1 + powerH)
  c.power:ClearAllPoints()
  c.power:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 1, 1)
  c.power:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -1, 1)
  c.power:SetHeight(powerH)
  c.health:SetStatusBarTexture(ns.Look.BarTexture())
  c.power:SetStatusBarTexture(ns.Look.BarTexture())
  frameEdges(c.rim, c, 1)
  frameEdges(c.dispel, c.health, 2)
  placeCellExtras(c, h)
  local font = math.max(8, math.min(12, h * 0.3))
  ns.Look.SetFont(c.name, font)
  ns.Look.SetFont(c.status, font * 0.9)
  c.name:SetWidth(w - 6)
  c.font = font
  c.status:ClearAllPoints()
  c.status:SetPoint("TOP", c.name, "BOTTOM", 0, 0)
  local icon = math.max(8, h * 0.32)
  c.role:SetSize(icon, icon)
  c.role:ClearAllPoints()
  c.role:SetPoint("BOTTOMLEFT", c.health, "BOTTOMLEFT", 2, 2)
end

local function setRole(c, role)
  local coords = ROLE_COORDS[role]
  c.role:SetShown(coords ~= nil)
  if coords then c.role:SetTexCoord(coords[1], coords[2], coords[3], coords[4]) end
end

-- Name at the top of the health area (the debuffs take the bottom), the status line under it.
-- Dead or offline: grey bar.
local GREY = { 0.3, 0.3, 0.32 }
local function setStatus(c, text)
  c.status:SetText(text)
  c.name:ClearAllPoints()
  c.name:SetPoint("TOP", c.health, "TOP", 0, -2)
  if text ~= "" then c.health:SetStatusBarColor(GREY[1], GREY[2], GREY[3]) end
end

local function classColor(class)
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if c then return c.r, c.g, c.b end
  return 0.38, 0.84, 0.2
end

-- Real unit: values straight into the bars (secret in combat is fine there); flags inside pcall.
local function fillCell(c)
  local unit = c.unit
  if not UnitExists(unit) then return end
  local _, class = UnitClass(unit)
  c.health:SetStatusBarColor(classColor(class))
  c.health:SetMinMaxValues(0, UnitHealthMax(unit))
  c.health:SetValue(UnitHealth(unit))
  local pType, token = UnitPowerType(unit)
  c.power:SetMinMaxValues(0, UnitPowerMax(unit, pType))
  c.power:SetValue(UnitPower(unit, pType))
  c.power:SetStatusBarColor(ns.Data.PowerColor(token))
  c.name:SetText(UnitName(unit) or "")
  local ok, status = pcall(function()
    if not UnitIsConnected(unit) then return "Desconectado" end
    if UnitIsDeadOrGhost(unit) then return "Morto" end
    return ""
  end)
  setStatus(c, ok and status or "")
  setRole(c, UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit))
end

local function fakeCell(c, d)
  c.health:SetStatusBarColor(classColor(d.class))
  c.health:SetMinMaxValues(0, 10000)
  c.health:SetValue(d.dead and 0 or d.hp)
  c.power:SetMinMaxValues(0, 100)
  c.power:SetValue(d.power)
  c.power:SetStatusBarColor(ns.Data.PowerColor("MANA"))
  c.name:SetText(d.name)
  setStatus(c, d.dead and "Morto" or "")
  setRole(c, d.role)
  fakeExtras(c, d)
  c:SetAlpha(1)
end

-- A debuff the player can dispel paints the border in its type's colour.
local function updateDispel(c)
  local list = UnitExists(c.unit) and ns.Data.UnitAuraList(c.unit, "HARMFUL|RAID", 1) or {}
  local aura = list[1]
  local ok, r, g, b = false
  if aura then ok, r, g, b = pcall(ns.Data.DebuffColor, aura.dispelName) end
  for _, t in ipairs(c.dispel) do
    t:SetShown(ok and true or false)
    if ok then t:SetVertexColor(r, g, b, 1) end
  end
end

-- Out of range: faded. UnitInRange is secret in combat; the frame takes it as it is.
local function updateRange(c)
  if not UnitExists(c.unit) or UnitIsUnit and UnitIsUnit(c.unit, "player") then c:SetAlpha(1); return end
  pcall(function()
    local inRange, checked = UnitInRange(c.unit)
    if issecretvalue and issecretvalue(inRange) then
      c:SetAlphaFromBoolean(inRange, 1, 0.4)
    else
      c:SetAlpha((checked and not inRange) and 0.4 or 1)
    end
  end)
end

-- Cell i's subgroup and its place in it, in roster order.
local function arrangement()
  local place, counts, groups = {}, {}, 1
  for i = 1, RAID do
    local group
    if GroupFrames.testing == "raid" then
      group = i <= TEST_RAID and fake(i).group or nil
    elseif GetRaidRosterInfo then
      group = select(3, GetRaidRosterInfo(i))
    end
    if group then
      counts[group] = (counts[group] or 0) + 1
      place[i] = { group, counts[group] }
      groups = math.max(groups, group)
    end
  end
  return place, groups
end

local function layoutRaid()
  local s = scale()
  local w, h = (db().raidW or 72) * s, (db().raidH or 36) * s
  local gap = CELL_GAP * s
  local columns = db().raidGrowth == "columns"
  local place, groups = arrangement()
  for i, c in ipairs(GroupFrames.raid) do
    sizeCell(c, w, h)
    local p = place[i] or { 8, 5 }
    local along, across = p[2] - 1, p[1] - 1 -- member within the group, group
    local x, y = along, across
    if columns then x, y = across, along end
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", raidHolder, "TOPLEFT", x * (w + gap), -y * (h + gap))
  end
  local wide, tall = 5, groups
  if columns then wide, tall = groups, 5 end
  raidHolder:SetSize(wide * (w + gap) - gap, tall * (h + gap) - gap)
end

-- ------------------------------------------------------------------ party
local function cellStyle() return db().partyStyle == "cells" end

-- The party members in use, in order: you (when asked for) and party1..4, as frames or cells.
local function partyMembers()
  local list, withMe = {}, db().partyPlayer == true
  if cellStyle() then
    for i, c in ipairs(GroupFrames.partyCells) do
      if i > 1 or withMe then list[#list + 1] = c end
    end
  else
    if withMe and GroupFrames.me then list[1] = GroupFrames.me end
    for _, f in ipairs(GroupFrames.party) do list[#list + 1] = f end
  end
  return list
end

local function layoutParty()
  local s = scale()
  local list = partyMembers()
  if cellStyle() then
    local w, h = (db().raidW or 72) * s, (db().raidH or 36) * s
    local gap = CELL_GAP * s
    local down = db().raidGrowth == "columns"
    for i, c in ipairs(list) do
      sizeCell(c, w, h)
      c:ClearAllPoints()
      if down then c:SetPoint("TOPLEFT", partyHolder, "TOPLEFT", 0, -(i - 1) * (h + gap))
      else c:SetPoint("TOPLEFT", partyHolder, "TOPLEFT", (i - 1) * (w + gap), 0) end
    end
    local n = #list
    if down then partyHolder:SetSize(w, n * (h + gap) - gap) else partyHolder:SetSize(n * (w + gap) - gap, h) end
    return
  end
  local prev
  for _, f in ipairs(list) do
    if f.debuffs then placeFrameExtras(f) end
    f:ClearAllPoints()
    if prev then f:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -10 * s)
    else f:SetPoint("TOPLEFT", partyHolder, "TOPLEFT", 0, 0) end
    prev = f
  end
  local w, h = list[1]:GetSize()
  partyHolder:SetSize(w, #list * h + (#list - 1) * 10 * s)
end

-- ------------------------------------------------------------------ visibility and test mode
local function watch(f, yes)
  if yes then RegisterUnitWatch(f) else UnregisterUnitWatch(f) end
end

local function apply()
  local test = GroupFrames.testing
  UnregisterStateDriver(partyHolder, "visibility")
  UnregisterStateDriver(raidHolder, "visibility")
  -- the party style not in use stays hidden; the one in use follows its units (or the test)
  local used = {}
  for i, m in ipairs(partyMembers()) do
    used[m] = true
    watch(m, test ~= "party")
    if test == "party" then
      m:Show()
      if m.isCell then fakeCell(m, fake(i)) else ns.UnitFrames.Fake(m, fake(i)); fakeExtras(m, fake(i)) end
    end
  end
  local all = { GroupFrames.me }
  for _, f in ipairs(GroupFrames.party) do all[#all + 1] = f end
  for _, c in ipairs(GroupFrames.partyCells) do all[#all + 1] = c end
  for _, m in ipairs(all) do
    if not used[m] then UnregisterUnitWatch(m); m:Hide() end
  end
  for i, c in ipairs(GroupFrames.raid) do
    watch(c, test ~= "raid")
    if test == "raid" then c:SetShown(i <= TEST_RAID); if i <= TEST_RAID then fakeCell(c, fake(i)) end end
  end
  if test then
    partyHolder:SetShown(test == "party")
    raidHolder:SetShown(test == "raid")
  else
    if on("party_on") then RegisterStateDriver(partyHolder, "visibility", "[group:raid] hide; [group:party] show; hide")
    else partyHolder:Hide() end
    if on("raid_on") then RegisterStateDriver(raidHolder, "visibility", "[group:raid] show; hide")
    else raidHolder:Hide() end
  end
  layoutRaid()
  layoutParty()
  ns.Movers.Register("party", "Grupo", partyHolder, function(f)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 18 * scale(), -380 * scale())
  end)
  ns.Movers.Register("raid", "Raide", raidHolder, function(f)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 18 * scale(), -380 * scale())
  end)
  ns.Movers.Place("party")
  ns.Movers.Place("raid")
  if not test then GroupFrames.Update() end
end

-- Refill everything from the roster (names, classes, roles; bars follow their own events).
function GroupFrames.Update()
  if GroupFrames.testing then return end
  for _, m in ipairs(partyMembers()) do
    if m.isCell then fillCell(m); updateDispel(m); updateRange(m) else ns.UnitFrames.Update(m) end
    updateExtras(m)
  end
  for _, c in ipairs(GroupFrames.raid) do fillCell(c); updateDispel(c); updateRange(c); updateExtras(c) end
end

-- "party", "raid" or nil (back to the real group). Out of combat only.
function GroupFrames.Test(kind)
  if InCombatLockdown() then return end
  GroupFrames.testing = kind
  apply()
end

function GroupFrames.Refresh() ns.RunOutOfCombat(apply) end

-- ------------------------------------------------------------------ setup and events
ns.On("PLAYER_LOGIN", function()
  ns.RunOutOfCombat(function()
    for i = 1, PARTY do
      GroupFrames.party[i] = ns.UnitFrames.Create("party" .. i, "modernSmall")
      GroupFrames.party[i]:SetParent(partyHolder)
    end
    GroupFrames.me = ns.UnitFrames.Create("player", "modernSmall", nil, "partyplayer")
    GroupFrames.me:SetParent(partyHolder)
    for _, f in ipairs({ GroupFrames.me, unpack(GroupFrames.party) }) do
      f:Resize(select(2, UIParent:GetSize()))
      addExtras(f, f)
    end
    -- Blizzard's own party and raid frames give way to these (back after a reload when switched off).
    if on("party_on") then
      ns.HideFrame((ns.Resolve.First(ns.Data.FRAME_CANDIDATES.partyframe)))
      ns.HideFrame((ns.Resolve.First(ns.Data.FRAME_CANDIDATES.compactparty)))
    end
    if on("raid_on") then
      ns.HideFrame((ns.Resolve.First(ns.Data.FRAME_CANDIDATES.raidmanager)))
      ns.HideFrame((ns.Resolve.First(ns.Data.FRAME_CANDIDATES.raidcontainer)))
    end
    apply()
    table.insert(ns.HUD.onResize, GroupFrames.Refresh)
  end)
end)

ns.On("GROUP_ROSTER_UPDATE", function()
  GroupFrames.Update()
  ns.RunOutOfCombat(layoutRaid) -- subgroups changed: cells move after combat
end)
ns.On("PLAYER_ENTERING_WORLD", GroupFrames.Update)
ns.On("PLAYER_REGEN_DISABLED", function()
  if GroupFrames.testing then GroupFrames.testing = nil; apply() end
end)

-- The raid or party cell showing a unit.
local PARTY_CELL = { player = 1, party1 = 2, party2 = 3, party3 = 4, party4 = 5 }
local function cellFor(unit)
  if not unit then return nil end
  if PARTY_CELL[unit] then return cellStyle() and GroupFrames.partyCells[PARTY_CELL[unit]] or nil end
  local i = unit:match("^raid(%d+)$")
  return i and GroupFrames.raid[tonumber(i)]
end
for _, ev in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
  "UNIT_NAME_UPDATE", "UNIT_CONNECTION", "UNIT_FLAGS" }) do
  ns.On(ev, function(_, unit)
    if GroupFrames.testing then return end
    local c = cellFor(unit)
    if c then fillCell(c) end
    -- you inside the party: a second frame the unit frames' own events do not reach
    if unit == "player" and GroupFrames.me and GroupFrames.me:IsVisible() then ns.UnitFrames.UpdateValues(GroupFrames.me) end
  end)
end
-- Everything showing a unit: its cell and, in the frames style, its party frame.
local function ownersFor(unit)
  local list = {}
  local c = cellFor(unit)
  if c then list[1] = c end
  if not cellStyle() then
    local i = unit and unit:match("^party(%d)$")
    local f = (i and GroupFrames.party[tonumber(i)]) or (unit == "player" and GroupFrames.me)
    if f and f:IsVisible() then list[#list + 1] = f end
  end
  return list
end
local function eachMember(fn)
  for _, m in ipairs(partyMembers()) do fn(m) end
  for _, c in ipairs(GroupFrames.raid) do fn(c) end
end

ns.On("UNIT_AURA", function(_, unit)
  if GroupFrames.testing then return end
  for _, o in ipairs(ownersFor(unit)) do
    if o.isCell then updateDispel(o) end
    updateDebuffs(o)
  end
end)
ns.On("RAID_TARGET_UPDATE", function()
  if not GroupFrames.testing then eachMember(updateMarker) end
end)
ns.On("READY_CHECK", function()
  readyActive = true
  eachMember(updateReady)
end)
ns.On("READY_CHECK_CONFIRM", function(_, unit)
  for _, o in ipairs(ownersFor(unit)) do updateReady(o) end
end)
-- the answers stay a few seconds after the check ends, like Blizzard's
ns.On("READY_CHECK_FINISHED", function()
  C_Timer.After(6, function()
    readyActive = false
    eachMember(updateReady)
  end)
end)
ns.On("UNIT_CONNECTION", function(_, unit) local f = ns.UnitFrames.frames[unit]; if f then ns.UnitFrames.Update(f) end end)

-- Range has no event: checked twice a second for the shown cells.
local elapsed = 0
CreateFrame("Frame"):SetScript("OnUpdate", function(_, dt)
  elapsed = elapsed + dt
  if elapsed < 0.5 or GroupFrames.testing then return end
  elapsed = 0
  for _, list in ipairs({ GroupFrames.raid, GroupFrames.partyCells }) do
    for _, c in ipairs(list) do
      if c:IsVisible() then updateRange(c) end
    end
  end
end)

-- The edit mode shows the party stand-ins while solo, and takes them away after.
local startedByEdit = false
table.insert(ns.EditMode.onStart, function()
  if not GroupFrames.testing and not IsInGroup() then
    startedByEdit = true
    GroupFrames.Test("party")
  end
end)
table.insert(ns.EditMode.onStop, function()
  if startedByEdit then
    startedByEdit = false
    if GroupFrames.testing == "party" then ns.RunOutOfCombat(function() GroupFrames.Test(nil) end) end
  end
end)
