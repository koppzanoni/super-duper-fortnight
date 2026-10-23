local _, ns = ...

-- The bottom HUD: free gap | cap | half bar | half bar (mirrored) | cap (mirrored) | free gap.
-- Centered at the bottom of the screen; at full size the caps touch the side edges. Each half bar
-- is drawn as its outer part, the optional extra slot columns (copies of one column of the art),
-- and its inner part; the extra columns take their width from the gap.
-- BOTTOM_PAD: transparent rows at the bottom of the HUD art, pushed below the screen edge.
local HUD = { onResize = {}, BOTTOM_PAD = 19 }
ns.HUD = HUD

local D = ns.Data.HUD
local CAP_W, BAR_W = 656, 684

local root = CreateFrame("Frame", "ObsidianUIHUD", UIParent)
root:SetFrameStrata("LOW")
root:SetFrameLevel(1)
HUD.frame = root

-- Layers as child frames so orb liquid sits under the art and buttons/text above it.
HUD.under = CreateFrame("Frame", nil, root)
HUD.art = CreateFrame("Frame", nil, root)
HUD.over = CreateFrame("Frame", nil, root)
for i, layer in ipairs({ HUD.under, HUD.art, HUD.over }) do
  layer:SetAllPoints(root)
  layer:SetFrameLevel(root:GetFrameLevel() + i * 5)
end

local function newTex()
  local t = HUD.art:CreateTexture(nil, "ARTWORK")
  return t
end

local capL, capR = newTex(), newTex()
HUD.caps = { left = capL, right = capR }
-- Parts of a cap's ornament that lie over the orb (Relicário style), above the liquid.
HUD.capOver = { left = HUD.over:CreateTexture(nil, "BACKGROUND"), right = HUD.over:CreateTexture(nil, "BACKGROUND") }
local outerL, innerL, outerR, innerR = newTex(), newTex(), newTex(), newTex()
local slices = { left = {}, right = {} }
-- Between a cap and the screen edge: the plain stone just inside the panel's trim (cap art
-- x 10..15, the same from top to bottom) stretched out, and the bronze trim (x 0..10) at the
-- screen edge.
local FILL_TRIM, FILL_STONE = 10, 5
HUD.capFill = { left = {}, right = {} }

-- Bar art pieces, as fractions of the half bar texture: outer end | one slot column | inner.
local SPLIT = (ns.Layout.BAR_SPLIT - (D.half - BAR_W)) / BAR_W
local SLICE_START = (ns.Layout.SLICE_SRC - (D.half - BAR_W)) / BAR_W
local SLICE_END = SLICE_START + ns.Layout.EXTRA_PITCH / BAR_W

local function slice(side, i)
  local list = slices[side]
  if not list[i] then list[i] = newTex() end
  return list[i]
end

local placed = {}

local function applyPlace(p)
  local u, W = HUD.u, HUD.W
  local left
  local function mapX(x)
    if p.noShift then return ns.Layout.BarX(x, W, u) end
    return ns.Layout.MapX(x, W, u, HUD.extraW)
  end
  if p.x + p.w / 2 <= D.half then
    left = mapX(p.x)
  else
    left = W - mapX(ns.Layout.MirrorX(D.width, p.x, p.w)) - p.w * u
  end
  p.region.obLeft = left
  p.region:ClearAllPoints()
  p.region:SetPoint("TOPLEFT", root, "TOPLEFT", left, -p.y * u)
  p.region:SetSize(p.w * u, p.h * u)
end

-- Position a region using the virtual 2692x381 HUD texture coordinates; re-applied on every resize.
-- noShift: a bar item that stays put when extra columns open (measured from the screen center).
function HUD.Place(region, x, y, w, h, noShift)
  local p = { region = region, x = x, y = y, w = w, h = h, noShift = noShift }
  placed[#placed + 1] = p
  if HUD.u then applyPlace(p) end
end

function HUD.Layout()
  local W, H = UIParent:GetSize()
  local h, u, stretch = ns.Layout.HudSize(W, H, ns.db and ns.db.scale or 1)
  -- HUD.h: visible height above the screen bottom (the art minus its sunk transparent rows).
  local sink = HUD.BOTTOM_PAD * u
  HUD.u, HUD.h, HUD.W = u, h - sink, W

  root:ClearAllPoints()
  root:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, -sink)
  root:SetSize(W, h)

  local wanted = ns.db and ns.db.extraCols or 0
  HUD.extra = math.min(wanted, ns.Layout.MaxExtraColumns(stretch, u))
  local pitch = ns.Layout.EXTRA_PITCH * u
  HUD.extraW = HUD.extra * pitch

  local capW, barW = CAP_W * u, BAR_W * u
  local outerW, innerW = SPLIT * barW, (1 - SPLIT) * barW
  local function put(t, x, w)
    t:ClearAllPoints()
    t:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", x, 0)
    t:SetSize(w, h)
  end
  HUD.capX = W / 2 - barW - HUD.extraW - capW
  put(capL, HUD.capX, capW)
  put(capR, W / 2 + barW + HUD.extraW, capW)
  local style = ns.Data.CAP_STYLES[ns.db and ns.db.capStyle] or ns.Data.CAP_STYLES.classic
  ns.Media.Apply(capL, style.left)
  ns.Media.Apply(capR, style.right, true)
  for _, side in ipairs({ "left", "right" }) do
    local t, key = HUD.capOver[side], side == "left" and style.overLeft or style.overRight
    if key then
      put(t, side == "left" and HUD.capX or W / 2 + barW + HUD.extraW, capW)
      ns.Media.Apply(t, key, side == "right")
      t:Show()
    else
      t:Hide()
    end
  end
  for _, side in ipairs({ "left", "right" }) do
    local list, n = HUD.capFill[side], 0
    local function piece(x, w, x0, x1)
      n = n + 1
      local t = list[n]
      if not t then
        t = HUD.art:CreateTexture(nil, "ARTWORK", nil, 1)
        list[n] = t
      end
      local mirror = side == "right"
      put(t, mirror and W - x - w or x, w)
      t.obLeft, t.obWidth = mirror and W - x - w or x, w
      ns.Media.ApplyRange(t, style[side], mirror, x0 / CAP_W, x1 / CAP_W)
      t:Show()
    end
    if HUD.capX > 0 then
      piece(0, FILL_TRIM * u, 0, FILL_TRIM)
      -- the stone also covers the cap's own trim, which would sit in the middle of it
      piece(FILL_TRIM * u, HUD.capX, FILL_TRIM, FILL_TRIM + FILL_STONE)
    end
    for k = n + 1, #list do list[k]:Hide() end
  end

  put(innerL, W / 2 - innerW, innerW)
  put(outerL, W / 2 - innerW - HUD.extraW - outerW, outerW)
  put(innerR, W / 2, innerW)
  put(outerR, W / 2 + innerW + HUD.extraW, outerW)
  ns.Media.ApplyRange(outerL, "hud_bar", false, 0, SPLIT)
  ns.Media.ApplyRange(innerL, "hud_bar", false, SPLIT, 1)
  ns.Media.ApplyRange(innerR, "hud_bar", true, SPLIT, 1)
  ns.Media.ApplyRange(outerR, "hud_bar", true, 0, SPLIT)
  for k = 1, HUD.extra do
    local l, r = slice("left", k), slice("right", k)
    put(l, W / 2 - innerW - k * pitch, pitch)
    put(r, W / 2 + innerW + (k - 1) * pitch, pitch)
    ns.Media.ApplyRange(l, "hud_bar", false, SLICE_START, SLICE_END)
    ns.Media.ApplyRange(r, "hud_bar", true, SLICE_START, SLICE_END)
    l:Show(); r:Show()
  end
  for _, side in ipairs({ "left", "right" }) do
    for k = HUD.extra + 1, #slices[side] do slices[side][k]:Hide() end
  end

  for _, p in ipairs(placed) do applyPlace(p) end
  for _, fn in ipairs(HUD.onResize) do fn(u, h, W) end
end

local function relayout() ns.RunOutOfCombat(HUD.Layout) end
ns.On("PLAYER_LOGIN", relayout)
ns.On("UI_SCALE_CHANGED", relayout)
ns.On("DISPLAY_SIZE_CHANGED", relayout)
