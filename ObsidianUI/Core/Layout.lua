local _, ns = ...

-- Pure geometry: texture pixel coordinates -> frame offsets. No WoW API here.
local Layout = {}
ns.Layout = Layout

-- Bottom HUD texture, left half: cap (orb + menu panel) | tiled connector | half action bar.
local HUD_H, CAP_W, BAR_W, HALF_W = 381, 656, 684, 1346

-- Rect inside a texture of texW x texH drawn at frameW x frameH. top is negative (for TOPLEFT anchors).
function Layout.Rect(texW, texH, frameW, frameH, x, y, w, h)
  local sx, sy = frameW / texW, frameH / texH
  return x * sx, -y * sy, w * sx, h * sy
end

function Layout.MirrorX(texW, x, w)
  return texW - x - w
end

-- HUD height h, texture unit u (screen px per texture px) and the width of each connector gap.
-- The HUD always spans the whole screen width; it shrinks when cap + half bar would not fit.
function Layout.HudSize(screenW, screenH, userScale)
  local fitWidth = screenW * HUD_H / (2 * (CAP_W + BAR_W))
  local h = math.min(0.25 * screenH * (userScale or 1), fitWidth)
  local u = h / HUD_H
  local stretch = math.max(0, screenW / 2 - (CAP_W + BAR_W) * u)
  return h, u, stretch
end

-- Screen x of a left-half texture x (0..1346): the cap is pinned left, the bar is pinned to center.
function Layout.MapX(x, screenW, u)
  if x <= CAP_W then return x * u end
  return screenW / 2 - (HALF_W - x) * u
end

-- Widths of the connector tiles that fill a gap; the last one is cut to fit.
function Layout.ConnectorPieces(stretch, tileW)
  local pieces = {}
  if tileW <= 0 then return pieces end
  local left = stretch
  while left > 0.01 do
    local w = math.min(tileW, left)
    pieces[#pieces + 1] = w
    left = left - w
  end
  return pieces
end
