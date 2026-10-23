local _, ns = ...

-- The bottom HUD: cap | tiled connector | half bar | half bar (mirrored) | connector | cap (mirrored).
-- Always touches the bottom and both side edges of the screen. Each half bar is drawn as its
-- outer part, the optional extra slot columns (copies of one column of the art), and its inner
-- part; the extra columns take their width from the connector gap.
-- BOTTOM_PAD: transparent rows at the bottom of the HUD art, pushed below the screen edge.
local HUD = { onResize = {}, BOTTOM_PAD = 19 }
ns.HUD = HUD

local D = ns.Data.HUD
local CAP_W, BAR_W, TILE_W = 656, 684, 333

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
local outerL, innerL, outerR, innerR = newTex(), newTex(), newTex(), newTex()
local connectors = { left = {}, right = {} }
local slices = { left = {}, right = {} }

-- Bar art pieces, as fractions of the half bar texture: outer end | one slot column | inner.
local SPLIT = (ns.Layout.BAR_SPLIT - (D.half - BAR_W)) / BAR_W
local SLICE_START = (ns.Layout.SLICE_SRC - (D.half - BAR_W)) / BAR_W
local SLICE_END = SLICE_START + ns.Layout.EXTRA_PITCH / BAR_W

local function slice(side, i)
  local list = slices[side]
  if not list[i] then list[i] = newTex() end
  return list[i]
end

local function connector(side, i)
  local list = connectors[side]
  if not list[i] then
    list[i] = HUD.art:CreateTexture(nil, "BACKGROUND")
  end
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

local function layoutConnectors(side, x0, stretch, u, h)
  local pieces = ns.Layout.ConnectorPieces(stretch, TILE_W * u)
  local x = x0
  for i, w in ipairs(pieces) do
    local t = connector(side, i)
    t:ClearAllPoints()
    t:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", x, 0)
    t:SetSize(w, h)
    ns.Media.Apply(t, "hud_connector", side == "right", w / (TILE_W * u))
    t:Show()
    x = x + w
  end
  for i = #pieces + 1, #connectors[side] do connectors[side][i]:Hide() end
  return #pieces
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
  capL:ClearAllPoints(); capL:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 0, 0); capL:SetSize(capW, h)
  capR:ClearAllPoints(); capR:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", 0, 0); capR:SetSize(capW, h)
  ns.Media.Apply(capL, "hud_cap")
  ns.Media.Apply(capR, "hud_cap", true)

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

  -- The stone connectors between the side caps and the bar are optional (setting "connectBar"):
  -- without them the bar floats free in the middle.
  local gap = (ns.db and ns.db.connectBar) and (stretch - HUD.extraW) or 0
  HUD.connectorsShown = layoutConnectors("left", capW, gap, u, h)
    + layoutConnectors("right", W / 2 + barW + HUD.extraW, gap, u, h)

  for _, p in ipairs(placed) do applyPlace(p) end
  for _, fn in ipairs(HUD.onResize) do fn(u, h, W) end
end

local function relayout() ns.RunOutOfCombat(HUD.Layout) end
ns.On("PLAYER_LOGIN", relayout)
ns.On("UI_SCALE_CHANGED", relayout)
ns.On("DISPLAY_SIZE_CHANGED", relayout)
