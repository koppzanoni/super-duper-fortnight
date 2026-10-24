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

-- Soft pieces (tools/export_textures.py): a rounded fill, its rounded rim and a feathered
-- shadow, sliced so the corners keep their size on any panel. Clients without sliced textures
-- get the flat fill and the 1 px rim.
local SOFT_MARGIN, SHADOW_MARGIN, SHADOW_OUT = 10, 26, 16
local function soft(t, name, margin)
  local e = ns.MediaManifest and ns.MediaManifest[name]
  if not (e and t.SetTextureSliceMargins) then return false end
  t:SetTexture(e.file)
  t:SetTextureSliceMargins(margin, margin, margin, margin)
  if t.SetTextureSliceMode then pcall(t.SetTextureSliceMode, t, 0) end -- stretched
  return true
end
Widgets.Soft = soft

-- A vertical gradient (bottom, top alpha) on a texture: on the soft fill when it has one.
local function gradient(t, r, g, b, bottom, top)
  if not t.obSoft then t:SetColorTexture(1, 1, 1, 1) end
  if t.SetGradient and CreateColor then
    pcall(t.SetGradient, t, "VERTICAL", CreateColor(r, g, b, bottom), CreateColor(r, g, b, top))
  elseif t.obSoft then
    t:SetVertexColor(r, g, b, (bottom + top) / 2)
  else
    t:SetColorTexture(r, g, b, (bottom + top) / 2)
  end
end
Widgets.Gradient = gradient

-- The fill colour of a panel: a little lighter at the top, so it reads as a surface.
function Widgets.PaintFill(f, r, g, b, a)
  local t = f.fill
  f.obFillAlpha = a
  if not t.obSoft then t:SetColorTexture(r, g, b, a) return end
  if t.SetGradient and CreateColor then
    t:SetVertexColor(1, 1, 1, 1)
    pcall(t.SetGradient, t, "VERTICAL", CreateColor(r * 0.7, g * 0.7, b * 0.7, a),
      CreateColor(math.min(1, r + 0.035), math.min(1, g + 0.035), math.min(1, b + 0.045), a))
  else
    t:SetVertexColor(r, g, b, a)
  end
end
-- The rim colour: lit from above, fading towards the bottom.
function Widgets.SetRim(f, r, g, b, a)
  for _, t in ipairs(f.rim or {}) do
    if t.obSoft and t.SetGradient and CreateColor then
      t:SetVertexColor(1, 1, 1, 1)
      pcall(t.SetGradient, t, "VERTICAL", CreateColor(r, g, b, a * 0.45), CreateColor(r, g, b, math.min(1, a * 1.6)))
    elseif t.obSoft then
      t:SetVertexColor(r, g, b, a)
    else
      t:SetColorTexture(r, g, b, a)
    end
  end
end

local function innerRim(f, inset, layer)
  local t = f:CreateTexture(nil, layer)
  t:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
  t:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)
  if soft(t, "soft_rim", SOFT_MARGIN) then t.obSoft = true return { t } end
  t:Hide()
  local sides = {}
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local e = f:CreateTexture(nil, layer)
    local horizontal = side == "TOP" or side == "BOTTOM"
    local dy = side == "TOP" and -inset or (side == "BOTTOM" and inset or 0)
    local dx = side == "LEFT" and inset or (side == "RIGHT" and -inset or 0)
    if horizontal then
      e:SetPoint(side .. "LEFT", f, side .. "LEFT", inset, dy)
      e:SetPoint(side .. "RIGHT", f, side .. "RIGHT", -inset, dy)
      e:SetHeight(1)
    else
      e:SetPoint("TOP" .. side, f, "TOP" .. side, dx, -inset)
      e:SetPoint("BOTTOM" .. side, f, "BOTTOM" .. side, dx, inset)
      e:SetWidth(1)
    end
    sides[#sides + 1] = e
  end
  return sides
end

local function gem(f, point)
  local M = ns.MediaManifest
  local t = f:CreateTexture(nil, "OVERLAY", nil, 7)
  t:SetSize(12, 12)
  t:SetPoint("CENTER", f, point, point == "TOPLEFT" and 6 or -6, -1)
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
  local window = alpha >= WINDOW_ALPHA
  local glass = window and Widgets.Glass() or Widgets.GLASS.solid
  local r, g, b = Widgets.Fill()
  if glass.tint and not (ns.db and ns.db.modernColor == "blue") then r, g, b = glass.tint[1], glass.tint[2], glass.tint[3] end
  if f.obSelected then
    Widgets.PaintFill(f, 1, 1, 1, 0.1)
  else
    Widgets.PaintFill(f, r, g, b, alpha * glass.fill)
  end
  local rr, rg, rb, ra = Widgets.Rim()
  if glass.rim then rr, rg, rb, ra = glass.rim[1], glass.rim[2], glass.rim[3], glass.rim[4] end
  Widgets.SetRim(f, rr, rg, rb, ra)
  if f.shadow then f.shadow:SetShown(window) end
  if glass.sheen > 0 and not f.sheen then
    f.sheen = f:CreateTexture(nil, "BACKGROUND", nil, -6)
    f.sheen:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    f.sheen:SetPoint("BOTTOMRIGHT", f, "RIGHT", -1, 0) -- the top half
    f.sheen.obSoft = soft(f.sheen, "soft_fill", SOFT_MARGIN)
    -- the highlight on the top edge stops short of the rounded corners and fades at its ends
    f.topLine = f:CreateTexture(nil, "BORDER", nil, 1)
    f.topLine:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -1)
    f.topLine:SetPoint("TOPRIGHT", f, "TOP", 0, -1)
    f.topLine:SetHeight(1)
    f.topLine2 = f:CreateTexture(nil, "BORDER", nil, 1)
    f.topLine2:SetPoint("TOPLEFT", f, "TOP", 0, -1)
    f.topLine2:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -1)
    f.topLine2:SetHeight(1)
  end
  if f.sheen then
    local c = glass.sheenColor or { 1, 1, 1 }
    gradient(f.sheen, c[1], c[2], c[3], 0, glass.sheen)
    f.sheen:SetShown(glass.sheen > 0)
    for i, line in ipairs({ f.topLine, f.topLine2 }) do
      line:SetColorTexture(1, 1, 1, 1)
      if line.SetGradient and CreateColor then
        local lit, dark = CreateColor(c[1], c[2], c[3], glass.top), CreateColor(c[1], c[2], c[3], 0)
        pcall(line.SetGradient, line, "HORIZONTAL", i == 1 and dark or lit, i == 1 and lit or dark)
      else
        line:SetColorTexture(c[1], c[2], c[3], glass.top)
      end
      line:SetShown(glass.top > 0)
    end
  end
  if glass.inner and not f.inner then f.inner = innerRim(f, 3, "BORDER") end
  for _, t in ipairs(f.inner or {}) do
    if t.obSoft then t:SetVertexColor(0, 0, 0, glass.inner or 0) else t:SetColorTexture(0, 0, 0, glass.inner or 0) end
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

-- Panel: the black translucent fill with rounded corners, its rim (lit from above) and, on
-- window-sized panels, a soft shadow that fades the window into the scene. alpha: the fill's
-- opacity (default the panels'). Panels at window opacity take the chosen glass.
function Widgets.Panel(f, alpha)
  local fill = f:CreateTexture(nil, "BACKGROUND", nil, -7)
  fill:SetAllPoints(f)
  fill.obSoft = soft(fill, "soft_fill", SOFT_MARGIN)
  local rimTex = f:CreateTexture(nil, "BORDER")
  rimTex:SetAllPoints(f)
  rimTex.obSoft = soft(rimTex, "soft_rim", SOFT_MARGIN)
  local r, g, b, a = Widgets.Fill()
  f.fill = fill
  if rimTex.obSoft then
    f.rim = { rimTex }
  else
    rimTex:Hide()
    f.rim = rim(f, "BORDER")
  end
  if (alpha or a) >= WINDOW_ALPHA then
    local shadow = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    shadow:SetPoint("TOPLEFT", f, "TOPLEFT", -SHADOW_OUT, SHADOW_OUT)
    shadow:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", SHADOW_OUT, -SHADOW_OUT)
    if soft(shadow, "soft_shadow", SHADOW_MARGIN) then
      shadow:SetVertexColor(0, 0, 0, 0.7)
      f.shadow = shadow
    else
      shadow:Hide()
    end
  end
  Widgets.PaintFill(f, r, g, b, alpha or a)
  panels[f] = alpha or a
  Widgets.StylePanel(f)
  return fill
end

-- A rounded colour texture (flat on clients without sliced textures); SetSoftColor recolours it.
function Widgets.SetSoftColor(t, r, g, b, a)
  if t.obSoft then t:SetVertexColor(r, g, b, a) else t:SetColorTexture(r, g, b, a) end
end
function Widgets.SoftTexture(parent, layer, r, g, b, a, sub)
  local t = parent:CreateTexture(nil, layer, nil, sub)
  t.obSoft = soft(t, "soft_fill", SOFT_MARGIN)
  Widgets.SetSoftColor(t, r, g, b, a)
  return t
end
-- A rounded 1 px rim round the whole of parent, lit from above.
function Widgets.SoftRim(parent, r, g, b, a, layer)
  local t = parent:CreateTexture(nil, layer or "BORDER")
  t:SetAllPoints(parent)
  t.obSoft = soft(t, "soft_rim", SOFT_MARGIN)
  local holder = { rim = t.obSoft and { t } or rim(parent, layer or "BORDER") }
  if not t.obSoft then t:Hide() end
  Widgets.SetRim(holder, r, g, b, a)
  return holder.rim
end

-- A hairline that fades out towards both ends instead of stopping in a hard cut. A frame: anchor
-- and size it like a texture (height 1 for a horizontal line, width 1 for a vertical one).
function Widgets.FadeLine(parent, r, g, b, a, vertical)
  local f = CreateFrame("Frame", nil, parent)
  local first, second = f:CreateTexture(nil, "BORDER"), f:CreateTexture(nil, "BORDER")
  if vertical then
    first:SetPoint("TOPLEFT"); first:SetPoint("BOTTOMRIGHT", f, "RIGHT")
    second:SetPoint("TOPLEFT", f, "LEFT"); second:SetPoint("BOTTOMRIGHT")
  else
    first:SetPoint("TOPLEFT"); first:SetPoint("BOTTOMRIGHT", f, "BOTTOM")
    second:SetPoint("TOPLEFT", f, "TOP"); second:SetPoint("BOTTOMRIGHT")
  end
  local lit, dark = CreateColor and CreateColor(r, g, b, a), CreateColor and CreateColor(r, g, b, 0)
  for i, t in ipairs({ first, second }) do
    t:SetColorTexture(1, 1, 1, 1)
    if lit and t.SetGradient then
      -- VERTICAL: min at the bottom; HORIZONTAL: min at the left
      local towardsMiddle = (i == 1) ~= (vertical == true)
      if towardsMiddle then pcall(t.SetGradient, t, vertical and "VERTICAL" or "HORIZONTAL", dark, lit)
      else pcall(t.SetGradient, t, vertical and "VERTICAL" or "HORIZONTAL", lit, dark) end
    else
      t:SetColorTexture(r, g, b, a)
    end
  end
  f.halves = { first, second }
  return f
end

-- Window fade: the frame comes in over a short moment instead of popping up.
function Widgets.FadeIn(f, seconds)
  if not f.CreateAnimationGroup then return end
  local ok, group = pcall(f.CreateAnimationGroup, f)
  if not ok or not group or not group.CreateAnimation then return end
  local anim = group:CreateAnimation("Alpha")
  if not anim or not anim.SetFromAlpha then return end
  anim:SetFromAlpha(0)
  anim:SetToAlpha(1)
  anim:SetDuration(seconds or 0.14)
  if anim.SetSmoothing then anim:SetSmoothing("OUT") end
  f.obFade = group
  f:HookScript("OnShow", function() group:Stop(); group:Play() end)
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
  if soft(glow, "soft_fill", SOFT_MARGIN) then glow:SetVertexColor(1, 1, 1, 0.08) else glow:SetColorTexture(1, 1, 1, 0.08) end
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
  b.obSelected = on and true or nil
  Widgets.StylePanel(b)
  local c = on and Widgets.WHITE or Widgets.TEXT
  b.text:SetTextColor(c[1], c[2], c[3])
end
