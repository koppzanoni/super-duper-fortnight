local _, ns = ...

-- Blizzard's player cast bar (keeps its secret-aware timing), moved above the action bar and
-- dressed with the Meshy cast bar frame (spec 7.1).
local M = ns.MediaManifest
local S = ns.Data.CASTBAR
local art
local WIDTH = 0.47 -- of the screen height
ns.CastBar = {}

-- Half the cast bar art width, for frames placed beside it.
function ns.CastBar.HalfWidth()
  local _, H = UIParent:GetSize()
  return WIDTH * H / 2
end

local function castbar() return ns.Resolve.First(ns.Data.FRAME_CANDIDATES.castbar) end

local function reskin(bar)
  bar:SetStatusBarTexture(M.bar_fill.file)
  local interrupted = bar.barType == "interrupted" or bar.barType == "uninterruptable"
  if interrupted then bar:SetStatusBarColor(0.77, 0.15, 0.11) else bar:SetStatusBarColor(1.0, 0.75, 0.30) end
  for _, key in ipairs({ "Border", "BorderShield", "Background", "TextBorder", "Flash", "Spark" }) do
    local region = bar[key]
    if region and region.SetAlpha then region:SetAlpha(0) end
  end
end
ns.CastBar.Reskin = reskin

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
    bar:HookScript("OnShow", reskin)
    hooksecurefunc(bar, "SetPoint", function(self)
      if self.obApplying or InCombatLockdown() then return end
      layout()
    end)
  end
  bar.obApplying = true
  bar:ClearAllPoints()
  -- The StatusBar itself fills exactly the groove; the frame art sits around it.
  bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", -w / 2 + S.bar.x * u, ns.Stack.BarTop() + 64 + (S.h - S.bar.y - S.bar.h) * u)
  bar:SetSize(S.bar.w * u, S.bar.h * u)
  bar.obApplying = false
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
  if bar.Text then
    bar.Text:ClearAllPoints()
    bar.Text:SetPoint("LEFT", bar, "LEFT", 8, 0)
  end
  reskin(bar)
end

table.insert(ns.HUD.onResize, function() ns.RunOutOfCombat(layout) end)
