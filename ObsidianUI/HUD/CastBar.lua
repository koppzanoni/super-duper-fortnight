local _, ns = ...

-- Blizzard's player cast bar (keeps its secret-aware timing), moved above the action bar and
-- dressed with the Meshy cast bar frame (spec 7.1).
local M = ns.MediaManifest
local S = ns.Data.CASTBAR
local art
local barW, barH
local WIDTH = 0.38 -- of the screen height
ns.CastBar = {}

-- Half the cast bar art width, for frames placed beside it.
function ns.CastBar.HalfWidth()
  local _, H = UIParent:GetSize()
  return WIDTH * H / 2
end

local function castbar() return ns.Resolve.First(ns.Data.FRAME_CANDIDATES.castbar) end

-- Blizzard's frame art plus its cast effects (finish/interrupt sparkles, glows) that would
-- draw over our fill.
local HIDDEN_REGIONS = { "Border", "BorderShield", "Background", "TextBorder", "Flash", "Spark",
  "InterruptGlow", "Flakes01", "Flakes02", "Flakes03", "Sparkles01", "Sparkles02", "Shine",
  "ChargeFlash", "StandardGlow", "CraftGlow", "ChannelShadow", "BaseGlow", "WispGlow", "EnergyGlow" }

local function reskin(bar)
  bar:SetStatusBarTexture(M.bar_fill.file)
  local interrupted = bar.barType == "interrupted" or bar.barType == "uninterruptable"
  if interrupted then bar:SetStatusBarColor(0.77, 0.15, 0.11) else bar:SetStatusBarColor(1.0, 0.75, 0.30) end
  for _, key in ipairs(HIDDEN_REGIONS) do
    local region = bar[key]
    if region and region.SetAlpha then region:SetAlpha(0) end
  end
end
ns.CastBar.Reskin = reskin

-- The StatusBar fills exactly our groove, with the spell name centered on it.
local function fit(bar)
  if not barW then return end
  bar:SetSize(barW, barH)
  if bar.Text then
    bar.Text:ClearAllPoints()
    bar.Text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    bar.Text:SetJustifyH("CENTER")
  end
end

local function layout()
  local bar = castbar()
  if not bar then return end
  local _, H = UIParent:GetSize()
  local w = WIDTH * H
  local u = w / S.w
  if not art then
    art = CreateFrame("Frame", nil, bar)
    art:SetFrameLevel(math.max(0, bar:GetFrameLevel() - 1))
    local t = art:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints(art)
    ns.Media.Apply(t, "castbar")
    bar:HookScript("OnEvent", reskin)
    -- Blizzard's SetLook (PlayerFrame) resizes the bar to 11 px and puts the text under it.
    if bar.SetLook then hooksecurefunc(bar, "SetLook", fit) end
    bar:HookScript("OnShow", reskin)
    -- The icon sits in our frame's socket: Blizzard hides it on some casts (after an
    -- interrupt, for one), so it is shown again right away.
    if bar.Icon then
      hooksecurefunc(bar.Icon, "Hide", function(icon) icon:Show() end)
      hooksecurefunc(bar.Icon, "SetShown", function(icon, shown) if not shown then icon:Show() end end)
      -- round, like the frame's socket
      local mask = bar:CreateMaskTexture()
      mask:SetTexture(M.mask_circle.file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      mask:SetAllPoints(bar.Icon)
      bar.Icon:AddMaskTexture(mask)
    end
  end
  -- The StatusBar itself fills exactly the groove; the frame art sits around it. Pinned:
  -- Blizzard re-anchors the bar on some casts, in combat too (the bar is not protected).
  local x, y = -w / 2 + S.bar.x * u, ns.Stack.BarTop() + 64 + (S.h - S.bar.y - S.bar.h) * u
  ns.Pin(bar, function(b)
    b:ClearAllPoints()
    b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", x, y)
  end)
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
  reskin(bar)
end

table.insert(ns.HUD.onResize, function() ns.RunOutOfCombat(layout) end)
