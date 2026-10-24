local _, ns = ...

-- Cursor: a ring around the mouse and a short trail of fading dots, so the cursor is easy to
-- find in a busy fight. Drawn on top of everything, never takes the mouse, hidden while the camera
-- is turned with the mouse (the game hides the cursor then). Only runs while something is shown.
local Cursor = { dots = {} }
ns.Cursor = Cursor

local W = ns.Widgets
local RING = 48   -- ring size at 100%
local DOT = 14    -- newest trail dot at 100%
local DOTS = 12
local SPACING = 6 -- trail points closer than this to the last one are skipped
local FADE = 0.35 -- seconds for a still trail to vanish

local function db() return ns.db or {} end
local inCombat = false
local trail = {} -- recent mouse points, newest first: { x, y }
local still = 0

local function wanted() return db().curRing == true or db().curTrail == true end
local function allowed() return not (db().curCombat ~= false and not inCombat) end

local function colour()
  local r, g, b = ns.Look.Color("cursor")
  if not r then r, g, b = W.ACCENT[1], W.ACCENT[2], W.ACCENT[3] end
  return r, g, b
end

local function hideTrail()
  for i = 1, DOTS do Cursor.dots[i]:Hide() end
  wipe(trail)
end

local function onUpdate(_, elapsed)
  local f = Cursor.frame
  if not allowed() or (IsMouselooking and IsMouselooking()) then
    Cursor.ring:Hide()
    hideTrail()
    return
  end
  local scale = UIParent:GetEffectiveScale()
  local x, y = GetCursorPosition()
  x, y = x / scale, y / scale
  if db().curRing == true then
    Cursor.ring:ClearAllPoints()
    Cursor.ring:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    Cursor.ring:Show()
  else
    Cursor.ring:Hide()
  end
  if db().curTrail ~= true then return end
  local last = trail[1]
  if not last or math.abs(last[1] - x) + math.abs(last[2] - y) >= SPACING then
    table.insert(trail, 1, { x, y })
    if #trail > DOTS then trail[#trail] = nil end
    still = 0
  else
    still = still + (elapsed or 0)
  end
  local fade = math.max(0, 1 - still / FADE)
  local size = DOT * (db().curSize or 1)
  for i = 1, DOTS do
    local d, p = Cursor.dots[i], trail[i]
    if p and fade > 0 then
      local k = 1 - (i - 1) / DOTS
      d:ClearAllPoints()
      d:SetPoint("CENTER", UIParent, "BOTTOMLEFT", p[1], p[2])
      d:SetSize(size * (0.45 + 0.55 * k), size * (0.45 + 0.55 * k))
      d:SetAlpha(0.8 * k * fade)
      d:Show()
    else
      d:Hide()
    end
  end
  if fade == 0 then wipe(trail) end
end

local function build()
  if Cursor.frame then return end
  local f = CreateFrame("Frame", "ObsidianUICursor", UIParent)
  f:SetFrameStrata("TOOLTIP")
  f:SetAllPoints(UIParent)
  if f.EnableMouse then f:EnableMouse(false) end
  Cursor.frame = f
  Cursor.ring = f:CreateTexture(nil, "OVERLAY")
  ns.Media.Apply(Cursor.ring, "cursor_ring")
  Cursor.ring:SetBlendMode("ADD")
  Cursor.ring:Hide()
  for i = 1, DOTS do
    local d = f:CreateTexture(nil, "ARTWORK")
    ns.Media.Apply(d, "cursor_dot")
    d:SetBlendMode("ADD")
    d:Hide()
    Cursor.dots[i] = d
  end
end

-- Settings again: size, colour, and the per-frame work only while something is switched on.
function Cursor.Refresh()
  build()
  local r, g, b = colour()
  local size = RING * (db().curSize or 1)
  Cursor.ring:SetSize(size, size)
  Cursor.ring:SetVertexColor(r, g, b, 1)
  for i = 1, DOTS do Cursor.dots[i]:SetVertexColor(r, g, b, 1) end
  if wanted() then
    Cursor.frame:SetScript("OnUpdate", onUpdate)
    Cursor.frame:Show()
  else
    Cursor.frame:SetScript("OnUpdate", nil)
    Cursor.ring:Hide()
    hideTrail()
  end
end

ns.On("PLAYER_LOGIN", function()
  inCombat = InCombatLockdown() and true or false
  Cursor.Refresh()
end)
ns.On("PLAYER_REGEN_DISABLED", function() inCombat = true end)
ns.On("PLAYER_REGEN_ENABLED", function() inCombat = false end)
table.insert(ns.HUD.onResize, function() Cursor.Refresh() end)
