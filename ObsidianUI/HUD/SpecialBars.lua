local _, ns = ...

-- Blizzard's own stance/pet bars, extra action, zone ability and vehicle exit, moved around the
-- HUD center (their combat logic stays Blizzard's). Vertical stack above the action bar, from
-- the bar's top edge: stance+pet row, class gems, cast bar, extra/zone buttons.
local HUD = ns.HUD
local BAR_TOP_TEX_Y = 87 -- y of the action bar frame top in the HUD texture

ns.Stack = {}

-- Distance in screen units from the screen bottom to the top edge of the action bar art
-- (HUD.h is already the visible height, so the sunk bottom rows are accounted for).
function ns.Stack.BarTop()
  if HUD.modern then return HUD.h end -- Moderno: the top of the key numbers row
  return (HUD.h or 0) - BAR_TOP_TEX_Y * (HUD.u or 0)
end

local function pin(key, point, x, yAboveBar)
  ns.Pin(ns.Resolve.First(ns.Data.FRAME_CANDIDATES[key]), function(frame)
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, "BOTTOM", x, ns.Stack.BarTop() + yAboveBar)
  end)
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
    -- Stance (left) and pet (right) bars start past the widest gem row (6 runes).
    local gems = ns.ClassResource.HalfWidth(6) + 8
    pin("stancebar", "BOTTOMRIGHT", -gems, 6)
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
