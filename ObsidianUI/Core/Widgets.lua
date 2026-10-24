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

-- Glass of the window panels (setting "glass"). The game cannot blur what is behind a window:
-- the glass is transparency, a sheen at the top, a light rim and a highlight line on the top
-- edge. fill: the opacity factor; tint: the fill's colour; gems: gold diamonds on the top
-- corners; inner: a dark second rim 3 px inside.
Widgets.GLASS = {
  solid = { fill = 1, sheen = 0, top = 0 },
  smoke = { fill = 0.66, sheen = 0.07, top = 0.22, rim = { 1, 1, 1, 0.16 } },
  arcane = { fill = 0.66, sheen = 0.1, top = 0.35, rim = { 0.43, 0.67, 1, 0.35 }, tint = { 0.04, 0.06, 0.12 },
    sheenColor = { 0.47, 0.67, 1 }, gems = true },
  crystal = { fill = 0.55, sheen = 0.13, top = 0.35, rim = { 1, 1, 1, 0.22 }, inner = 0.55 },
}
Widgets.GLASS_ORDER = { { "solid", "Sólido" }, { "smoke", "Fumê" }, { "arcane", "Arcano" }, { "crystal", "Cristal" } }
-- the unit frame styles (HUD/UnitFrames.lua), listed here for the panel, which loads first
Widgets.FRAME_STYLES = { { "flat", "Chapado" }, { "gloss", "Brilho" }, { "arcane", "Anel arcano" }, { "plate", "Placa de vidro" } }
function Widgets.Glass() return Widgets.GLASS[ns.db and ns.db.glass or "smoke"] or Widgets.GLASS.smoke end

-- Panels at window opacity take the glass; button plates and small boxes stay as they are.
local WINDOW_ALPHA = 0.6
local panels = setmetatable({}, { __mode = "k" })

local function gradient(t, r, g, b, bottom, top)
  t:SetColorTexture(1, 1, 1, 1)
  if t.SetGradient and CreateColor then
    pcall(t.SetGradient, t, "VERTICAL", CreateColor(r, g, b, bottom), CreateColor(r, g, b, top))
  else
    t:SetColorTexture(r, g, b, (bottom + top) / 2)
  end
end

local function innerRim(f, inset, layer)
  local sides = {}
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local t = f:CreateTexture(nil, layer)
    local horizontal = side == "TOP" or side == "BOTTOM"
    local dy = side == "TOP" and -inset or (side == "BOTTOM" and inset or 0)
    local dx = side == "LEFT" and inset or (side == "RIGHT" and -inset or 0)
    if horizontal then
      t:SetPoint(side .. "LEFT", f, side .. "LEFT", inset, dy)
      t:SetPoint(side .. "RIGHT", f, side .. "RIGHT", -inset, dy)
      t:SetHeight(1)
    else
      t:SetPoint("TOP" .. side, f, "TOP" .. side, dx, -inset)
      t:SetPoint("BOTTOM" .. side, f, "BOTTOM" .. side, dx, inset)
      t:SetWidth(1)
    end
    sides[#sides + 1] = t
  end
  return sides
end

local function gem(f, point)
  local M = ns.MediaManifest
  local t = f:CreateTexture(nil, "OVERLAY", nil, 7)
  t:SetSize(12, 12)
  t:SetPoint("CENTER", f, point, 0, 0)
  if M and M.mod_gem_on then
    t:SetTexture(M.mod_gem_on.file)
    t:SetTexCoord(0, M.mod_gem_on.w / M.mod_gem_on.potW, 0, M.mod_gem_on.h / M.mod_gem_on.potH)
  else
    t:SetColorTexture(0.9, 0.76, 0.35, 1)
  end
  return t
end

-- The chosen glass on one panel (made at Panel time, restyled when the setting changes).
function Widgets.StylePanel(f)
  local alpha = panels[f]
  if not alpha or not f.fill then return end
  local glass = alpha >= WINDOW_ALPHA and Widgets.Glass() or Widgets.GLASS.solid
  local r, g, b = Widgets.Fill()
  if glass.tint and not (ns.db and ns.db.modernColor == "blue") then r, g, b = glass.tint[1], glass.tint[2], glass.tint[3] end
  f.fill:SetColorTexture(r, g, b, alpha * glass.fill)
  local rr, rg, rb, ra = Widgets.Rim()
  if glass.rim then rr, rg, rb, ra = glass.rim[1], glass.rim[2], glass.rim[3], glass.rim[4] end
  for _, t in ipairs(f.rim or {}) do t:SetColorTexture(rr, rg, rb, ra) end
  if glass.sheen > 0 and not f.sheen then
    f.sheen = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    f.sheen:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    f.sheen:SetPoint("BOTTOMRIGHT", f, "RIGHT", -1, 0) -- the top half
    f.topLine = f:CreateTexture(nil, "BORDER", nil, 1)
    f.topLine:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    f.topLine:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    f.topLine:SetHeight(1)
  end
  if f.sheen then
    local c = glass.sheenColor or { 1, 1, 1 }
    gradient(f.sheen, c[1], c[2], c[3], 0, glass.sheen)
    f.sheen:SetShown(glass.sheen > 0)
    f.topLine:SetColorTexture(c[1], c[2], c[3], glass.top)
    f.topLine:SetShown(glass.top > 0)
  end
  if glass.inner and not f.inner then f.inner = innerRim(f, 3, "BORDER") end
  for _, t in ipairs(f.inner or {}) do
    t:SetColorTexture(0, 0, 0, glass.inner or 0)
    t:SetShown(glass.inner ~= nil)
  end
  if glass.gems and not f.gems then f.gems = { gem(f, "TOPLEFT"), gem(f, "TOPRIGHT") } end
  for _, t in ipairs(f.gems or {}) do t:SetShown(glass.gems == true) end
end

function Widgets.ApplyGlass()
  for f in pairs(panels) do Widgets.StylePanel(f) end
end
-- panels made while the addon loads were styled before the saved choice was read
ns.On("PLAYER_LOGIN", Widgets.ApplyGlass)

-- Panel: the black translucent fill and its rim. alpha: the fill's opacity (default the panels').
-- Panels at window opacity take the chosen glass.
function Widgets.Panel(f, alpha)
  local fill = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  fill:SetAllPoints(f)
  local r, g, b, a = Widgets.Fill()
  fill:SetColorTexture(r, g, b, alpha or a)
  f.fill, f.rim = fill, rim(f, "BORDER")
  panels[f] = alpha or a
  Widgets.StylePanel(f)
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
