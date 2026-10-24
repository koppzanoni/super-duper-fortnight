local _, ns = ...

-- Blizzard's own stance/pet bars, extra action, zone ability and vehicle exit, moved around the
-- HUD center (their combat logic stays Blizzard's). Vertical stack above the action bar, from
-- the bar's top edge: stance+pet row, class gems, cast bar, extra/zone buttons.
local HUD = ns.HUD

ns.Stack = {}

-- Distance in screen units from the screen bottom to the top of the action bar (its key numbers),
-- where the bar sits by default.
function ns.Stack.BarTop()
  return HUD.h or 0
end

-- The frame the stack above the bar is anchored to (its TOP): it follows the bar when moved.
function ns.Stack.Anchor()
  return ns.ActionBars.modernFrame
end

local function pin(key, point, x, yAboveBar)
  ns.Pin(ns.Resolve.First(ns.Data.FRAME_CANDIDATES[key]), function(frame)
    frame:ClearAllPoints()
    frame:SetPoint(point, ns.Stack.Anchor(), "TOP", x, yAboveBar)
  end)
end

local function hideArt(frame)
  if not frame then return end
  for _, key in ipairs({ "Background", "Border", "BorderArt", "Style", "SpellButtonContainer" }) do
    local region = frame[key]
    if region and region.SetAlpha and key ~= "SpellButtonContainer" then region:SetAlpha(0) end
  end
end

-- Stance bar: left of the gems, or under the player frame when the class page asks (called
-- again by the class modules once the unit frames exist).
function ns.Stack.PlaceStance()
  local gems = ns.ClassResource.HalfWidth(6) + 8
  ns.Pin(ns.Resolve.First(ns.Data.FRAME_CANDIDATES.stancebar), function(frame)
    frame:ClearAllPoints()
    local player = ns.Classes and ns.Classes.StanceOnPlayer() and ns.UnitFrames.frames.player
    if player then
      frame:SetPoint("TOPLEFT", player, "BOTTOMLEFT", 0, -6)
    else
      frame:SetPoint("BOTTOMRIGHT", ns.Stack.Anchor(), "TOP", -gems, 6)
    end
  end)
end

local function layout()
  ns.RunOutOfCombat(function()
    -- Stance (left) and pet (right) bars start past the widest gem row (6 runes).
    local gems = ns.ClassResource.HalfWidth(6) + 8
    ns.Stack.PlaceStance()
    pin("petbar", "BOTTOMLEFT", gems, 6)
    pin("extrabutton", "BOTTOMRIGHT", -8, 150)
    pin("zoneability", "BOTTOMLEFT", 8, 150)
    -- Vehicle exit just right of the cast bar, at its height.
    pin("vehicleleave", "BOTTOMLEFT", ns.CastBar.HalfWidth() + 8, 70)
    hideArt(ns.Resolve.First(ns.Data.FRAME_CANDIDATES.stancebar))
    hideArt(ns.Resolve.First(ns.Data.FRAME_CANDIDATES.petbar))
    hideArt(ns.Resolve.First(ns.Data.FRAME_CANDIDATES.extrabutton))
  end)
end

table.insert(HUD.onResize, layout)
