local _, ns = ...

-- Raid tools in place of Blizzard's raid manager (hidden with its raid frames): ready check,
-- a 10 second pull countdown and the eight raid markers (plus clear) for the current target, on
-- a black translucent band. Shown to the group leader and assistants; in the test mode too, to
-- place it. Movable in the edit mode; on/off on the Raid page.
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

local function layout()
  local _, H = UIParent:GetSize()
  local s = H / 1080
  local h, pad, gap = 26 * s, 3 * s, 3 * s
  local x = pad
  local function put(b, w)
    b:SetSize(w, h - 2 * pad)
    b:ClearAllPoints()
    b:SetPoint("LEFT", frame, "LEFT", x, 0)
    x = x + w + gap
  end
  put(RaidTools.readyButton, 60 * s)
  put(RaidTools.countButton, 70 * s)
  for _, b in ipairs(RaidTools.markers) do
    put(b, h - 2 * pad)
    b.icon:SetAllPoints(b)
  end
  put(RaidTools.clearButton, h - 2 * pad)
  for _, b in ipairs({ RaidTools.readyButton, RaidTools.countButton, RaidTools.clearButton }) do
    ns.Look.SetFont(b.label, 11 * s)
  end
  frame:SetSize(x - gap + pad, h)
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
  frame:SetShown(show)
end

ns.On("PLAYER_LOGIN", function() layout(); RaidTools.Update() end)
table.insert(ns.HUD.onResize, function() layout(); RaidTools.Update() end)
for _, ev in ipairs({ "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "PLAYER_ENTERING_WORLD" }) do
  ns.On(ev, RaidTools.Update)
end
