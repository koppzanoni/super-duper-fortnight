local _, ns = ...

-- Small widgets in the inventory's look: the stone of its panels with a bronze edge, and its
-- stone tab plates as buttons (textures cut from the inventory art by tools/inventory_art.py).
local Widgets = {}
ns.Widgets = Widgets

local M = ns.MediaManifest
Widgets.BRONZE = { 0.54, 0.43, 0.23 }
Widgets.BRONZE_LIT = { 0.85, 0.68, 0.35 }
Widgets.GOLD = { 0.91, 0.77, 0.42 }
Widgets.TEXT = { 0.73, 0.68, 0.58 }

local function edge(f, inset, color, layer, sub)
  local sides = {}
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local t = f:CreateTexture(nil, layer, nil, sub)
    t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    if side == "TOP" or side == "BOTTOM" then
      local y = side == "TOP" and -inset or inset
      t:SetPoint(side .. "LEFT", f, side .. "LEFT", inset, y)
      t:SetPoint(side .. "RIGHT", f, side .. "RIGHT", -inset, y)
      t:SetHeight(1)
    else
      local x = side == "LEFT" and inset or -inset
      t:SetPoint("TOP" .. side, f, "TOP" .. side, x, -inset)
      t:SetPoint("BOTTOM" .. side, f, "BOTTOM" .. side, x, inset)
      t:SetWidth(1)
    end
    sides[#sides + 1] = t
  end
  return sides
end

-- Panel: tiled stone, slightly darkened for legible text, a bronze edge with a dark line
-- inside it (the bevel of the inventory's own panels).
function Widgets.Panel(f)
  local stone = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  stone:SetAllPoints(f)
  stone:SetTexture(M.stone_tile.file, "REPEAT", "REPEAT")
  stone:SetHorizTile(true)
  stone:SetVertTile(true)
  local shade = f:CreateTexture(nil, "BACKGROUND", nil, -7)
  shade:SetAllPoints(f)
  shade:SetColorTexture(0, 0, 0, 0.35)
  edge(f, 0, { 0, 0, 0, 0.9 }, "BORDER", 0)
  edge(f, 1, Widgets.BRONZE, "BORDER", 1)
  edge(f, 2, { 0, 0, 0, 0.6 }, "BORDER", 2)
end

-- Button: the stone tab plate (exported at about the buttons' shape), gold text, warm glow
-- on hover, text sinks while pressed.
-- With clickTarget (a Blizzard button's global name) the button is secure and clicks that
-- button, so Blizzard's own code opens its window (calling it from addon code would taint).
function Widgets.Button(parent, label, onClick, clickTarget)
  local b
  if clickTarget then
    b = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "click")
    b:SetAttribute("clickbutton", _G[clickTarget])
  else
    b = CreateFrame("Button", nil, parent)
  end
  local plate = b:CreateTexture(nil, "BACKGROUND")
  plate:SetAllPoints(b)
  plate:SetTexture(M.plate.file)
  local glow = b:CreateTexture(nil, "HIGHLIGHT")
  glow:SetPoint("TOPLEFT", 3, -3)
  glow:SetPoint("BOTTOMRIGHT", -3, 3)
  glow:SetColorTexture(1, 0.85, 0.5, 0.12)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.text:SetPoint("CENTER")
  b.text:SetText(label)
  b.text:SetTextColor(Widgets.GOLD[1], Widgets.GOLD[2], Widgets.GOLD[3])
  b:SetScript("OnMouseDown", function(self) self.text:SetPoint("CENTER", 1, -1) end)
  b:SetScript("OnMouseUp", function(self) self.text:SetPoint("CENTER") end)
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end
