local _, ns = ...

-- Blizzard's player cast bar (keeps its secret-aware timing), moved above the action bar and
-- dressed in the Moderno frame: blue fill, the spell name on the tab above the groove, the time,
-- the latency zone and the spell queue mark.
local M = ns.MediaManifest
local art
local barW, barH
local WIDTH = 470 / 1080 -- of the screen height
ns.CastBar = { latency = 0 }

local function spec() return ns.Data.MODERN_CAST end
local function width(H) return WIDTH * H end

-- Half the cast bar art width, for frames placed beside it.
function ns.CastBar.HalfWidth()
  local _, H = UIParent:GetSize()
  return width(H) / 2
end

local function castbar() return ns.Resolve.First(ns.Data.FRAME_CANDIDATES.castbar) end

-- Blizzard's frame art plus its cast effects (finish/interrupt sparkles, glows) that would
-- draw over our fill.
local HIDDEN_REGIONS = { "Border", "BorderShield", "Background", "TextBorder", "Flash", "Spark",
  "InterruptGlow", "Flakes01", "Flakes02", "Flakes03", "Sparkles01", "Sparkles02", "Shine",
  "ChargeFlash", "StandardGlow", "CraftGlow", "ChannelShadow", "BaseGlow", "WispGlow", "EnergyGlow" }

local function reskin(bar)
  bar:SetStatusBarTexture(M.mod_gloss.file)
  local interrupted = bar.barType == "interrupted" or bar.barType == "uninterruptable"
  if interrupted then bar:SetStatusBarColor(0.77, 0.15, 0.11) else bar:SetStatusBarColor(0.17, 0.67, 0.87) end
  for _, key in ipairs(HIDDEN_REGIONS) do
    local region = bar[key]
    if region and region.SetAlpha then region:SetAlpha(0) end
  end
end
ns.CastBar.Reskin = reskin

-- The StatusBar fills exactly our groove; the spell name sits on the tab above it.
local function fit(bar)
  if not barW then return end
  bar:SetSize(barW, barH)
  if bar.Text then
    local S, u = spec(), barW / spec().bar.w
    bar.Text:ClearAllPoints()
    bar.Text:SetPoint("LEFT", bar, "TOPLEFT", (S.name.x - S.bar.x) * u, (S.bar.y - S.name.y - S.name.h / 2) * u)
    bar.Text:SetJustifyH("LEFT")
  end
end

-- Moderno latency zone (Quartz/ElvUI style): the end of the bar as long as the ping. Once the
-- fill reaches it the server has the cast done, so moving or casting the next spell is safe.
-- The ping is the time from UNIT_SPELLCAST_SENT to UNIT_SPELLCAST_START, else the world latency.
-- The queue mark is where the spell queue window (CVar SpellQueueWindow) opens.
-- Cast times can be secret in combat: any failing math hides the zone instead of erroring.
local sentAt
local function hideZone()
  if ns.CastBar.lag then
    ns.CastBar.lag:Hide(); ns.CastBar.queue:Hide(); ns.CastBar.lagText:Hide()
  end
end

local function queueWindow()
  local get = (C_CVar and C_CVar.GetCVar) or GetCVar
  local ok, v = pcall(get, "SpellQueueWindow")
  return ok and tonumber(v) or 400
end

local function showZone()
  local lag = ns.CastBar.lag
  if not (lag and barW) then return end
  local ok, duration = pcall(function()
    local _, _, _, startMS, endMS = UnitCastingInfo("player")
    return (endMS - startMS) / 1000
  end)
  local lagFrac = ok and type(duration) == "number" and ns.Layout.CastLag(ns.CastBar.latency, duration)
  if not lagFrac then return hideZone() end
  local db = ns.db or {}
  lag:SetWidth(math.max(1, barW * lagFrac))
  lag:SetShown(db.castLag ~= false)
  ns.CastBar.lagText:SetFormattedText("%d ms", math.floor(ns.CastBar.latency * 1000 + 0.5))
  ns.CastBar.lagText:SetShown(db.castLag ~= false and db.castMs ~= false)
  local q = ns.Layout.CastQueue(queueWindow(), duration)
  if q and db.castQueue ~= false then
    ns.CastBar.queue:SetSize(math.max(1, barH * 0.1), barH * 1.35)
    ns.CastBar.queue:ClearAllPoints()
    ns.CastBar.queue:SetPoint("CENTER", castbar(), "LEFT", barW * q, 0)
    ns.CastBar.queue:Show()
  else
    ns.CastBar.queue:Hide()
  end
end

-- Settings changed (zone, ms, queue mark): redrawn for the cast in progress.
function ns.CastBar.Refresh() showZone() end

ns.On("UNIT_SPELLCAST_SENT", function(_, unit) if unit == "player" then sentAt = GetTime() end end)
ns.On("UNIT_SPELLCAST_START", function(_, unit)
  if unit ~= "player" then return end
  local now = GetTime()
  if sentAt and now - sentAt < 1.5 then
    ns.CastBar.latency = now - sentAt
  else
    local ok, _, _, _, world = pcall(GetNetStats)
    ns.CastBar.latency = ok and tonumber(world) and world / 1000 or 0
  end
  sentAt = nil
  showZone()
end)
-- Channels run backwards: no zone at their end.
ns.On("UNIT_SPELLCAST_CHANNEL_START", function(_, unit) if unit == "player" then hideZone() end end)

local function modernParts(bar)
  local lag = bar:CreateTexture(nil, "OVERLAY", nil, 1)
  lag:SetColorTexture(0.27, 0.86, 0.35, 0.45)
  lag:SetPoint("TOPRIGHT", bar, "TOPRIGHT")
  lag:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
  local queue = bar:CreateTexture(nil, "OVERLAY", nil, 2)
  queue:SetColorTexture(1, 1, 1, 0.6)
  local lagText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  lagText:SetTextColor(0.55, 0.94, 0.6)
  lagText:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -2)
  local time = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  time:SetTextColor(0.93, 0.78, 0.38)
  ns.CastBar.lag, ns.CastBar.queue, ns.CastBar.lagText, ns.CastBar.time = lag, queue, lagText, time
  hideZone()
  -- "elapsed / total" from the bar itself, quietly blank when the values are secret
  art:SetScript("OnUpdate", function()
    if not pcall(function()
      local _, total = bar:GetMinMaxValues()
      time:SetFormattedText("%.1f / %.1f", bar:GetValue(), total)
    end) then time:SetText("") end
  end)
end

local function layout()
  local bar = castbar()
  if not bar then return end
  local S = spec()
  local _, H = UIParent:GetSize()
  local w = width(H)
  local u = w / S.w
  if not art then
    art = CreateFrame("Frame", nil, bar)
    art:SetFrameLevel(math.max(0, bar:GetFrameLevel() - 1))
    local t = art:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints(art)
    ns.Media.Apply(t, ns.ModernTex("mod_cast"))
    ns.CastBar.art = t
    bar:HookScript("OnEvent", reskin)
    -- Blizzard's SetLook (PlayerFrame) resizes the bar to 11 px and puts the text under it.
    if bar.SetLook then hooksecurefunc(bar, "SetLook", fit) end
    bar:HookScript("OnShow", reskin)
    -- The icon sits in our frame's socket: Blizzard hides it on some casts (after an
    -- interrupt, for one), so it is shown again right away.
    if bar.Icon then
      hooksecurefunc(bar.Icon, "Hide", function(icon) icon:Show() end)
      hooksecurefunc(bar.Icon, "SetShown", function(icon, shown) if not shown then icon:Show() end end)
    end
    modernParts(bar)
  end
  -- The StatusBar itself fills exactly the groove; the frame art sits around it. Pinned:
  -- Blizzard re-anchors the bar on some casts, in combat too (the bar is not protected).
  local x, y = -w / 2 + S.bar.x * u, 64 + (S.h - S.bar.y - S.bar.h) * u
  ns.Movers.Register("cast", "Barra de cast", bar, function(b)
    b:ClearAllPoints()
    b:SetPoint("BOTTOMLEFT", ns.Stack.Anchor(), "TOP", x, y)
  end, { box = art })
  ns.Pin(bar, function() ns.Movers.Place("cast") end)
  barW, barH = S.bar.w * u, S.bar.h * u
  fit(bar)
  art:ClearAllPoints()
  art:SetPoint("TOPLEFT", bar, "TOPLEFT", -S.bar.x * u, S.bar.y * u)
  art:SetSize(w, S.h * u)
  if bar.Icon then
    bar.Icon:ClearAllPoints()
    bar.Icon:SetPoint("TOPLEFT", art, "TOPLEFT", S.icon.x * u, -S.icon.y * u)
    bar.Icon:SetSize(S.icon.w * u, S.icon.h * u)
    bar.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    bar.Icon:Show()
  end
  if ns.CastBar.time then
    -- the time sits left of the queue mark, the latency under the bar's end
    ns.CastBar.time:ClearAllPoints()
    ns.CastBar.time:SetPoint("RIGHT", bar, "RIGHT", -barW * 0.17, 0)
  end
  reskin(bar)
end

table.insert(ns.HUD.onResize, function() ns.RunOutOfCombat(layout) end)
