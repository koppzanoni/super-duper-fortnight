local _, ns = ...

-- Raid tools in place of Blizzard's raid manager (hidden with its raid frames): ready check,
-- a 10 second pull countdown and the eight raid markers (plus clear) for the current target, and
-- a second row with the eight ground markers (secure /wm macro buttons: the game then asks where
-- on the ground) and clear all, on a black translucent band. Shown to the group leader and
-- assistants; in the test mode too, to place it. Movable in the edit mode; on/off on the Raid page.
local RaidTools = {}
ns.RaidTools = RaidTools

local MARKER_TEX = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local WHITE = { 0.93, 0.94, 0.96 }

local frame = CreateFrame("Frame", "ObsidianUIRaidTools", UIParent)
frame:SetFrameStrata("LOW")
frame:Hide()
RaidTools.frame = frame
local bg = frame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(frame)
bg:SetColorTexture(0, 0, 0, 0.6)
local rim = frame:CreateTexture(nil, "BORDER")
rim:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
rim:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
rim:SetColorTexture(1, 1, 1, 0.1)

local function button(onClick)
  local b = CreateFrame("Button", nil, frame)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints(b)
  b.bg:SetColorTexture(1, 1, 1, 0.06)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints(b)
  hl:SetColorTexture(1, 1, 1, 0.12)
  b:SetScript("OnClick", onClick)
  return b
end

local function textButton(label, onClick)
  local b = button(onClick)
  b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.label:SetPoint("CENTER")
  b.label:SetTextColor(WHITE[1], WHITE[2], WHITE[3])
  b.label:SetText(label)
  return b
end

RaidTools.readyButton = textButton("Pronto?", function() C_PartyInfo.DoReadyCheck() end)
RaidTools.countButton = textButton("Contagem", function() C_PartyInfo.DoCountdown(10) end)
RaidTools.markers = {}
for i = 1, 8 do
  local b = button(function() SetRaidTarget("target", i) end)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetTexture(MARKER_TEX)
  SetRaidTargetIconTexture(b.icon, i)
  RaidTools.markers[i] = b
end
RaidTools.clearButton = textButton("X", function() SetRaidTarget("target", 0) end)

-- Ground markers: world marker n shows raid icon GROUND_ICON[n] (blue square first...).
local GROUND_ICON = { 6, 4, 3, 7, 1, 2, 5, 8 }
local function slash(name, fallback) local v = _G[name]; return type(v) == "string" and v or fallback end
local function macroButton(macro)
  local b = CreateFrame("Button", nil, frame, "SecureActionButtonTemplate")
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:SetAttribute("type", "macro")
  b:SetAttribute("macrotext", macro)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints(b)
  b.bg:SetColorTexture(1, 1, 1, 0.06)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints(b)
  hl:SetColorTexture(1, 1, 1, 0.12)
  return b
end
RaidTools.groundLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
RaidTools.groundLabel:SetTextColor(WHITE[1], WHITE[2], WHITE[3])
RaidTools.groundLabel:SetText("Chão")
RaidTools.ground = {}
for i = 1, 8 do
  local b = macroButton(slash("SLASH_WORLD_MARKER1", "/wm") .. " " .. i)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetTexture(MARKER_TEX)
  SetRaidTargetIconTexture(b.icon, GROUND_ICON[i])
  RaidTools.ground[i] = b
end
RaidTools.groundClear = macroButton(slash("SLASH_CLEAR_WORLD_MARKER1", "/cwm") .. " " .. slash("ALL", "all"):lower())
RaidTools.groundClear.label = RaidTools.groundClear:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
RaidTools.groundClear.label:SetPoint("CENTER")
RaidTools.groundClear.label:SetTextColor(WHITE[1], WHITE[2], WHITE[3])
RaidTools.groundClear.label:SetText("X")

local function layout()
  local _, H = UIParent:GetSize()
  local s = H / 1080
  local h, pad, gap = 26 * s, 3 * s, 3 * s
  local x, row = pad, 0
  local function put(b, w)
    b:SetSize(w, h - 2 * pad)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -pad - row * h)
    x = x + w + gap
  end
  put(RaidTools.readyButton, 60 * s)
  put(RaidTools.countButton, 70 * s)
  local marks = x -- both rows of markers start here
  for _, b in ipairs(RaidTools.markers) do
    put(b, h - 2 * pad)
    b.icon:SetAllPoints(b)
  end
  put(RaidTools.clearButton, h - 2 * pad)
  local width = x - gap + pad
  x, row = marks, 1
  RaidTools.groundLabel:ClearAllPoints()
  RaidTools.groundLabel:SetPoint("RIGHT", frame, "TOPLEFT", marks - gap - 4 * s, -h * 1.5)
  for _, b in ipairs(RaidTools.ground) do
    put(b, h - 2 * pad)
    b.icon:SetAllPoints(b)
  end
  put(RaidTools.groundClear, h - 2 * pad)
  for _, b in ipairs({ RaidTools.readyButton, RaidTools.countButton, RaidTools.clearButton, RaidTools.groundClear }) do
    ns.Look.SetFont(b.label, 11 * s)
  end
  ns.Look.SetFont(RaidTools.groundLabel, 11 * s)
  frame:SetSize(width, h * 2)
  -- default: right above the party and raid frames
  ns.Movers.Register("raidtools", "Ferramentas de raide", frame, function(f)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 18 * s, -346 * s)
  end)
  ns.Movers.Place("raidtools")
end

local function canLead()
  return UnitIsGroupLeader("player") or (UnitIsGroupAssistant and UnitIsGroupAssistant("player"))
end

function RaidTools.Update()
  local on = not (ns.db and ns.db.raidTools == false)
  local show = on and (ns.GroupFrames.testing ~= nil or (IsInGroup() and canLead() and true or false))
  -- the ground markers are protected buttons: their band shows or hides out of combat only
  ns.RunOutOfCombat(function() frame:SetShown(show) end)
end

ns.On("PLAYER_LOGIN", function() ns.RunOutOfCombat(layout); RaidTools.Update() end)
table.insert(ns.HUD.onResize, function() ns.RunOutOfCombat(layout); RaidTools.Update() end)
for _, ev in ipairs({ "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "PLAYER_ENTERING_WORLD" }) do
  ns.On(ev, RaidTools.Update)
end
