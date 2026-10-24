local _, ns = ...

-- Quest tracker in the Moderno look: the game's tracker without its header art and backing; the
-- headers in white with a thin line under them in the arcane purple. It hangs from a holder the
-- edit mode moves ("Missões"; by default left of the vertical bars, or under the minimap).
-- Optionally collapsed during combat and inside instances; opened again afterwards, unless the
-- player had collapsed it.
local QuestTracker = {}
ns.QuestTracker = QuestTracker

local W = ns.Widgets
local holder = CreateFrame("Frame", "ObsidianUIQuestHolder", UIParent)
holder:SetSize(1, 1)
QuestTracker.holder = holder
local collapsedByUs = false

local function db() return ns.db or {} end
local function on(key) return db()[key] ~= false end
local function tracker() return ns.Resolve.First(ns.Data.FRAME_CANDIDATES.objectivetracker) end

-- ------------------------------------------------------------------ look
local function skinHeader(h)
  if not h or h.obLine then return end
  local bg = rawget(h, "Background")
  if bg then bg:SetAlpha(0) end
  local text = rawget(h, "Text")
  if text then
    text:SetTextColor(W.WHITE[1], W.WHITE[2], W.WHITE[3])
    if text.SetShadowColor then text:SetShadowColor(0, 0, 0, 1); text:SetShadowOffset(1, -1) end
  end
  h.obLine = h:CreateTexture(nil, "ARTWORK")
  h.obLine:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 0, 1)
  h.obLine:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 0, 1)
  h.obLine:SetHeight(1)
  h.obLine:SetColorTexture(W.ACCENT[1], W.ACCENT[2], W.ACCENT[3], 0.6)
end

local function skin(t)
  if not t then return end
  local nine = rawget(t, "NineSlice")
  if nine then nine:SetAlpha(0) end
  skinHeader(rawget(t, "Header"))
  for _, m in ipairs(rawget(t, "modules") or {}) do skinHeader(rawget(m, "Header")) end
end

-- ------------------------------------------------------------------ place
function QuestTracker.Place()
  local t = tracker()
  local _, H = UIParent:GetSize()
  holder:SetSize(t and t:GetWidth() or 260, 0.4 * H)
  ns.Movers.Register("quests", "Missões", holder, function(f)
    f:ClearAllPoints()
    local bars = ns.VerticalBars and ns.VerticalBars.container
    if bars and bars:IsShown() then
      f:SetPoint("TOPRIGHT", bars, "TOPLEFT", -10, 0)
    else
      f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -0.012 * H, -ns.VerticalBars.TOP * H)
    end
  end)
  ns.Movers.Place("quests")
  if t then
    ns.Pin(t, function(f)
      f:ClearAllPoints()
      f:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
    end)
  end
end

-- ------------------------------------------------------------------ collapse
local function collapse(want)
  local t = tracker()
  if not t or not t.SetCollapsed then return end
  if want then
    if not t:IsCollapsed() then collapsedByUs = true; t:SetCollapsed(true) end
  elseif collapsedByUs then
    collapsedByUs = false
    t:SetCollapsed(false)
  end
end

local function wantCollapsed(inCombat)
  if db().questInstance and IsInInstance() then return true end
  return inCombat and on("questCombat")
end

ns.On("PLAYER_LOGIN", function()
  local t = tracker()
  if on("quest_on") then
    skin(t)
    if t and t.Update then hooksecurefunc(t, "Update", skin) end
  end
  ns.RunOutOfCombat(QuestTracker.Place)
end)
table.insert(ns.HUD.onResize, function() ns.RunOutOfCombat(QuestTracker.Place) end)
-- before combat locks the tracker's buttons; after it, out of combat again
ns.On("PLAYER_REGEN_DISABLED", function() collapse(wantCollapsed(true)) end)
ns.On("PLAYER_REGEN_ENABLED", function() collapse(wantCollapsed(false)) end)
ns.On("PLAYER_ENTERING_WORLD", function() ns.RunOutOfCombat(function() collapse(wantCollapsed(false)) end) end)
