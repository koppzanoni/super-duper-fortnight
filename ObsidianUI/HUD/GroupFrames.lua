local _, ns = ...

-- Party and raid frames. Party: the Moderno unit frames (small kind) stacked down on the left,
-- shown in a party and hidden in a raid. Raid: a grid of compact cells by subgroup (a group per
-- row or per column), class-coloured health, name, a thin power line, tank/healer icon, dead and
-- offline text, a border in the colour of a debuff the player can dispel, faded when out of range.
-- Both are secure and only move or change out of combat. Test mode shows stand-ins (party or
-- raid) to place and size them while solo; combat ends it.
local GroupFrames = { party = {}, raid = {}, testing = nil }
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
    power = 40 + (i * 17) % 60, dead = i == 6, group = math.floor((i - 1) / 5) + 1, level = 60 }
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

local function newCell(i)
  local c = CreateFrame("Button", "ObsidianUIRaid" .. i, raidHolder, "SecureUnitButtonTemplate")
  c.unit = "raid" .. i
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
  return c
end
for i = 1, RAID do GroupFrames.raid[i] = newCell(i) end

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
  c.role:SetPoint("TOPLEFT", c.health, "TOPLEFT", 2, -2)
end

local function setRole(c, role)
  local coords = ROLE_COORDS[role]
  c.role:SetShown(coords ~= nil)
  if coords then c.role:SetTexCoord(coords[1], coords[2], coords[3], coords[4]) end
end

-- Name centred; with a status line under it, both together centred in the health area. Dead or
-- offline: grey bar.
local GREY = { 0.3, 0.3, 0.32 }
local function setStatus(c, text)
  c.status:SetText(text)
  c.name:ClearAllPoints()
  c.name:SetPoint("CENTER", c.health, "CENTER", 0, text ~= "" and (c.font or 10) * 0.45 or 0)
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
local function layoutParty()
  local s = scale()
  local prev
  for _, f in ipairs(GroupFrames.party) do
    f:ClearAllPoints()
    if prev then f:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -10 * s)
    else f:SetPoint("TOPLEFT", partyHolder, "TOPLEFT", 0, 0) end
    prev = f
  end
  local first = GroupFrames.party[1]
  local w, h = first:GetSize()
  partyHolder:SetSize(w, PARTY * h + (PARTY - 1) * 10 * s)
end

-- ------------------------------------------------------------------ visibility and test mode
local function watch(f, yes)
  if yes then RegisterUnitWatch(f) else UnregisterUnitWatch(f) end
end

local function apply()
  local test = GroupFrames.testing
  UnregisterStateDriver(partyHolder, "visibility")
  UnregisterStateDriver(raidHolder, "visibility")
  for i, f in ipairs(GroupFrames.party) do
    watch(f, test ~= "party")
    if test == "party" then f:Show(); ns.UnitFrames.Fake(f, fake(i)) end
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
  for _, f in ipairs(GroupFrames.party) do ns.UnitFrames.Update(f) end
  for _, c in ipairs(GroupFrames.raid) do fillCell(c); updateDispel(c); updateRange(c) end
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
    for _, f in ipairs(GroupFrames.party) do f:Resize(select(2, UIParent:GetSize())) end
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

local function cellFor(unit)
  local i = unit and unit:match("^raid(%d+)$")
  return i and GroupFrames.raid[tonumber(i)]
end
for _, ev in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
  "UNIT_NAME_UPDATE", "UNIT_CONNECTION", "UNIT_FLAGS" }) do
  ns.On(ev, function(_, unit)
    local c = cellFor(unit)
    if c and not GroupFrames.testing then fillCell(c) end
  end)
end
ns.On("UNIT_AURA", function(_, unit)
  local c = cellFor(unit)
  if c and not GroupFrames.testing then updateDispel(c) end
end)
ns.On("UNIT_CONNECTION", function(_, unit) local f = ns.UnitFrames.frames[unit]; if f then ns.UnitFrames.Update(f) end end)

-- Range has no event: checked twice a second for the shown cells.
local elapsed = 0
CreateFrame("Frame"):SetScript("OnUpdate", function(_, dt)
  elapsed = elapsed + dt
  if elapsed < 0.5 or GroupFrames.testing or not raidHolder:IsShown() then return end
  elapsed = 0
  for _, c in ipairs(GroupFrames.raid) do
    if c:IsShown() then updateRange(c) end
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
