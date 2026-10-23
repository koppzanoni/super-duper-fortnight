local _, ns = ...

-- Small widgets in the addon's look: dark glass, thin bronze edge, gold text.
local Widgets = {}
ns.Widgets = Widgets

local WHITE = "Interface\\Buttons\\WHITE8X8"
Widgets.BRONZE = { 0.54, 0.43, 0.23 }
Widgets.BRONZE_LIT = { 0.85, 0.68, 0.35 }
Widgets.GOLD = { 0.91, 0.77, 0.42 }
Widgets.TEXT = { 0.73, 0.68, 0.58 }

local function backdrop(f, bg, edge)
  if not f.SetBackdrop then return end
  f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  f:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
  f:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1)
end

-- Panel background: near-black blue glass with a bronze edge.
function Widgets.Panel(f)
  backdrop(f, { 0.035, 0.04, 0.055, 0.94 }, Widgets.BRONZE)
end

function Widgets.Button(parent, label, onClick)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  local rest, hover = { 0.06, 0.065, 0.08, 0.95 }, { 0.11, 0.105, 0.11, 0.95 }
  backdrop(b, rest, Widgets.BRONZE)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.text:SetPoint("CENTER")
  b.text:SetText(label)
  b.text:SetTextColor(Widgets.GOLD[1], Widgets.GOLD[2], Widgets.GOLD[3])
  b:SetScript("OnEnter", function(self) backdrop(self, hover, Widgets.BRONZE_LIT) end)
  b:SetScript("OnLeave", function(self) backdrop(self, rest, Widgets.BRONZE) end)
  b:SetScript("OnMouseDown", function(self) self.text:SetPoint("CENTER", 1, -1) end)
  b:SetScript("OnMouseUp", function(self) self.text:SetPoint("CENTER") end)
  b:SetScript("OnClick", onClick)
  return b
end
