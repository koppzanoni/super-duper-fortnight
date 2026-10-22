local _, ns = ...

-- Blizzard's own stance/pet bars, extra action, zone ability and vehicle exit, moved around the
-- HUD center (their combat logic stays Blizzard's). Vertical stack above the action bar, from
-- the bar's top edge: stance+pet row, class gems, cast bar, extra/zone buttons.
local HUD = ns.HUD
local BAR_TOP_TEX_Y = 87 -- y of the action bar frame top in the HUD texture

ns.Stack = {}

-- Distance in screen units from the screen bottom to the top edge of the action bar art.
function ns.Stack.BarTop()
  return (HUD.h or 0) - BAR_TOP_TEX_Y * (HUD.u or 0)
end

local moved = {}

local function pin(key, point, x, yAboveBar)
  local frame = ns.Resolve.First(ns.Data.FRAME_CANDIDATES[key])
  if not frame then return end
  local entry = moved[key] or { frame = frame }
  entry.point, entry.x, entry.y = point, x, yAboveBar
  if not moved[key] then
    moved[key] = entry
    hooksecurefunc(frame, "SetPoint", function(self)
      if entry.applying or InCombatLockdown() then return end
      entry.applying = true
      self:ClearAllPoints()
      self:SetPoint(entry.point, UIParent, "BOTTOM", entry.x, ns.Stack.BarTop() + entry.y)
      entry.applying = false
    end)
  end
  entry.applying = true
  frame:ClearAllPoints()
  frame:SetPoint(point, UIParent, "BOTTOM", x, ns.Stack.BarTop() + yAboveBar)
  entry.applying = false
end

local function hideArt(frame)
  if not frame then return end
  for _, key in ipairs({ "Background", "Border", "BorderArt", "Style", "SpellButtonContainer" }) do
    local region = frame[key]
    if region and region.SetAlpha and key ~= "SpellButtonContainer" then region:SetAlpha(0) end
  end
end

local function layout()
  ns.RunOutOfCombat(function()
    pin("stancebar", "BOTTOMRIGHT", -12, 6)
    pin("petbar", "BOTTOMLEFT", 12, 6)
    pin("extrabutton", "BOTTOMRIGHT", -8, 150)
    pin("zoneability", "BOTTOMLEFT", 8, 150)
    pin("vehicleleave", "BOTTOMLEFT", 0.12 * (HUD.W or 1920), 92)
    hideArt(ns.Resolve.First(ns.Data.FRAME_CANDIDATES.stancebar))
    hideArt(ns.Resolve.First(ns.Data.FRAME_CANDIDATES.petbar))
    hideArt(ns.Resolve.First(ns.Data.FRAME_CANDIDATES.extrabutton))
  end)
end

table.insert(HUD.onResize, layout)
