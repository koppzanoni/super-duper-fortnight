local _, ns = ...

-- Small widgets in the Moderno look (the inventory's): black translucent panels with a thin light
-- rim, flat buttons with light text and a soft hover. The blue HUD colour tints them blue.
local Widgets = {}
ns.Widgets = Widgets

Widgets.WHITE = { 0.93, 0.94, 0.96 }
Widgets.TEXT = { 0.72, 0.74, 0.76 }
Widgets.DIM = { 0.6, 0.62, 0.64 }
Widgets.ACCENT = { 0.71, 0.55, 1.0 } -- the arcane purple of the HUD

local function blue() return ns.db and ns.db.modernColor == "blue" end
-- Panel fill and rim colours for the chosen HUD colour.
function Widgets.Fill() if blue() then return 0.01, 0.05, 0.08, 0.86 end return 0.02, 0.02, 0.025, 0.86 end
function Widgets.Rim() if blue() then return 0.13, 0.5, 0.64, 0.6 end return 1, 1, 1, 0.1 end

-- A 1 px rim just inside f.
local function rim(f, layer)
  local sides = {}
  local r, g, b, a = Widgets.Rim()
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local t = f:CreateTexture(nil, layer)
    t:SetColorTexture(r, g, b, a)
    if side == "TOP" or side == "BOTTOM" then
      t:SetPoint(side .. "LEFT", f, side .. "LEFT", 0, 0)
      t:SetPoint(side .. "RIGHT", f, side .. "RIGHT", 0, 0)
      t:SetHeight(1)
    else
      t:SetPoint("TOP" .. side, f, "TOP" .. side, 0, 0)
      t:SetPoint("BOTTOM" .. side, f, "BOTTOM" .. side, 0, 0)
      t:SetWidth(1)
    end
    sides[#sides + 1] = t
  end
  return sides
end
Widgets.Rim1 = rim

-- Panel: the black translucent fill and its rim. alpha: the fill's opacity (default the panels').
function Widgets.Panel(f, alpha)
  local fill = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  fill:SetAllPoints(f)
  local r, g, b, a = Widgets.Fill()
  fill:SetColorTexture(r, g, b, alpha or a)
  f.fill, f.rim = fill, rim(f, "BORDER")
  return fill
end

-- Button: flat, light text, soft hover, text sinks while pressed.
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
  Widgets.Panel(b, 0.35)
  b.plate = b.fill
  local glow = b:CreateTexture(nil, "HIGHLIGHT")
  glow:SetAllPoints(b)
  glow:SetColorTexture(1, 1, 1, 0.08)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.text:SetPoint("CENTER")
  b.text:SetText(label)
  b.text:SetTextColor(Widgets.TEXT[1], Widgets.TEXT[2], Widgets.TEXT[3])
  b:SetScript("OnMouseDown", function(self) self.text:SetPoint("CENTER", 1, -1) end)
  b:SetScript("OnMouseUp", function(self) self.text:SetPoint("CENTER") end)
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

-- Selected look of a button among tabs: white text on a lighter fill.
function Widgets.SetSelected(b, on)
  if on then b.plate:SetColorTexture(1, 1, 1, 0.1) else b.plate:SetColorTexture(0, 0, 0, 0.35) end
  local c = on and Widgets.WHITE or Widgets.TEXT
  b.text:SetTextColor(c[1], c[2], c[3])
end
