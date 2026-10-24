local _, ns = ...

-- Pure geometry: texture pixel coordinates -> frame offsets. No WoW API here.
local Layout = {}
ns.Layout = Layout

-- Bottom HUD texture, left half: cap (orb + menu panel) | free gap | half action bar.
local HUD_H, CAP_W, BAR_W, HALF_W = 381, 656, 684, 1346

-- Extra action columns: copies of a plain middle column of the bar art (SLICE_SRC..+EXTRA_PITCH:
-- no bar-end bracket, XP groove without its cap), inserted at BAR_SPLIT between columns 1 and 2.
-- The outer part (bar end, groove cap, column 1's frame) moves out; the main buttons don't move,
-- column 1's buttons take the slot next to column 2 (see ActionBars).
Layout.BAR_SPLIT, Layout.SLICE_SRC, Layout.EXTRA_PITCH, Layout.MAX_EXTRA = 774, 845, 72, 6

-- How many extra columns fit in the free gap of one side.
function Layout.MaxExtraColumns(stretch, u)
  if u <= 0 then return 0 end
  return math.max(0, math.min(Layout.MAX_EXTRA, math.floor(stretch / (Layout.EXTRA_PITCH * u))))
end

-- Rect inside a texture of texW x texH drawn at frameW x frameH. top is negative (for TOPLEFT anchors).
function Layout.Rect(texW, texH, frameW, frameH, x, y, w, h)
  local sx, sy = frameW / texW, frameH / texH
  return x * sx, -y * sy, w * sx, h * sy
end

function Layout.MirrorX(texW, x, w)
  return texW - x - w
end

-- HUD height h, texture unit u (screen px per texture px) and the width of each free gap.
-- The HUD always spans the whole screen width; it shrinks when cap + half bar would not fit.
function Layout.HudSize(screenW, screenH, userScale)
  local fitWidth = screenW * HUD_H / (2 * (CAP_W + BAR_W))
  local h = math.min(0.25 * screenH * (userScale or 1), fitWidth)
  local u = h / HUD_H
  local stretch = math.max(0, screenW / 2 - (CAP_W + BAR_W) * u)
  return h, u, stretch
end

-- Screen x of a left-half texture x (0..1346): the bar is pinned to center and the cap touches
-- the bar's outer end, so a small HUD stays in one piece (the free space goes to the screen edges).
-- extraW: width of the extra columns; the cap and the bar part outside BAR_SPLIT move out by it.
function Layout.MapX(x, screenW, u, extraW)
  if x <= CAP_W then return screenW / 2 - (CAP_W + BAR_W - x) * u - (extraW or 0) end
  local sx = screenW / 2 - (HALF_W - x) * u
  if x < Layout.BAR_SPLIT then sx = sx - (extraW or 0) end
  return sx
end

-- Moderno action bar: rows x columns of slots with the key numbers above the first row, at the
-- bottom center of the screen. Sizes are those of a 1080 px screen, scaled by the HUD scale.
function Layout.ModernBar(screenH, userScale, rows, cols)
  local s = screenH / 1080 * (userScale or 1)
  rows = math.min(rows, math.ceil(36 / cols)) -- 36 buttons at most: no empty rows
  local g = { rows = rows, cols = cols, slot = 54 * s, gap = 7 * s, numbers = 18 * s, bottom = 14 * s, s = s }
  g.width = cols * g.slot + (cols - 1) * g.gap
  g.height = g.numbers + rows * g.slot + (rows - 1) * g.gap
  return g
end

-- Moderno cast bar: the share of the bar at its end covered by the latency, and where the spell
-- queue window opens (fraction from the left). nil when there is nothing to show.
function Layout.CastLag(latency, duration)
  if not duration or duration <= 0 then return nil end
  return math.min(1, latency / duration)
end

function Layout.CastQueue(windowMS, duration)
  local window = windowMS / 1000
  if not duration or duration <= window then return nil end
  return 1 - window / duration
end

-- Screen x of a bar texture x measured from the screen center, whatever its value (extra
-- columns have bar coordinates below the cap's width).
function Layout.BarX(x, screenW, u)
  return screenW / 2 - (HALF_W - x) * u
end
