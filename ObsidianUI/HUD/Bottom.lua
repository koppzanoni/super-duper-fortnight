local _, ns = ...

-- The bottom HUD: cap | tiled connector | half bar | half bar (mirrored) | connector | cap (mirrored).
-- Always touches the bottom and both side edges of the screen.
local HUD = { onResize = {} }
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

local capL, capR, barL, barR = newTex(), newTex(), newTex(), newTex()
local connectors = { left = {}, right = {} }

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
  if p.x + p.w / 2 <= D.half then
    left = ns.Layout.MapX(p.x, W, u)
  else
    left = W - ns.Layout.MapX(ns.Layout.MirrorX(D.width, p.x, p.w), W, u) - p.w * u
  end
  p.region:ClearAllPoints()
  p.region:SetPoint("TOPLEFT", root, "TOPLEFT", left, -p.y * u)
  p.region:SetSize(p.w * u, p.h * u)
end

-- Position a region using the virtual 2692x381 HUD texture coordinates; re-applied on every resize.
function HUD.Place(region, x, y, w, h)
  local p = { region = region, x = x, y = y, w = w, h = h }
  placed[#placed + 1] = p
  if HUD.u then applyPlace(p) end
end

local function layoutConnectors(side, x0, stretch, u)
  local pieces = ns.Layout.ConnectorPieces(stretch, TILE_W * u)
  local x = x0
  for i, w in ipairs(pieces) do
    local t = connector(side, i)
    t:ClearAllPoints()
    t:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", x, 0)
    t:SetSize(w, HUD.h)
    ns.Media.Apply(t, "hud_connector", side == "right", w / (TILE_W * u))
    t:Show()
    x = x + w
  end
  for i = #pieces + 1, #connectors[side] do connectors[side][i]:Hide() end
end

function HUD.Layout()
  local W, H = UIParent:GetSize()
  local h, u, stretch = ns.Layout.HudSize(W, H, ns.db and ns.db.scale or 1)
  HUD.u, HUD.h, HUD.W = u, h, W

  root:ClearAllPoints()
  root:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT")
  root:SetSize(W, h)

  local capW, barW = CAP_W * u, BAR_W * u
  capL:ClearAllPoints(); capL:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 0, 0); capL:SetSize(capW, h)
  capR:ClearAllPoints(); capR:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", 0, 0); capR:SetSize(capW, h)
  barL:ClearAllPoints(); barL:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", W / 2 - barW, 0); barL:SetSize(barW, h)
  barR:ClearAllPoints(); barR:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", W / 2, 0); barR:SetSize(barW, h)
  ns.Media.Apply(capL, "hud_cap")
  ns.Media.Apply(capR, "hud_cap", true)
  ns.Media.Apply(barL, "hud_bar")
  ns.Media.Apply(barR, "hud_bar", true)

  layoutConnectors("left", capW, stretch, u)
  layoutConnectors("right", W / 2 + barW, stretch, u)

  for _, p in ipairs(placed) do applyPlace(p) end
  for _, fn in ipairs(HUD.onResize) do fn(u, h, W) end
end

local function relayout() ns.RunOutOfCombat(HUD.Layout) end
ns.On("PLAYER_LOGIN", relayout)
ns.On("UI_SCALE_CHANGED", relayout)
ns.On("DISPLAY_SIZE_CHANGED", relayout)
