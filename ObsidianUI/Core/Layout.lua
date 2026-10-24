local _, ns = ...

-- Pure geometry: texture pixel coordinates -> frame offsets. No WoW API here.
local Layout = {}
ns.Layout = Layout

-- Rect inside a texture of texW x texH drawn at frameW x frameH. top is negative (for TOPLEFT anchors).
function Layout.Rect(texW, texH, frameW, frameH, x, y, w, h)
  local sx, sy = frameW / texW, frameH / texH
  return x * sx, -y * sy, w * sx, h * sy
end

function Layout.MirrorX(texW, x, w)
  return texW - x - w
end

-- Action bar: rows x columns of slots with the key numbers above the first row, at the bottom
-- center of the screen. Sizes are those of a 1080 px screen, scaled by the HUD scale.
function Layout.ModernBar(screenH, userScale, rows, cols)
  local s = screenH / 1080 * (userScale or 1)
  rows = math.min(rows, math.ceil(36 / cols)) -- 36 buttons at most: no empty rows
  local g = { rows = rows, cols = cols, slot = 54 * s, gap = 7 * s, numbers = 18 * s, bottom = 14 * s, s = s }
  g.width = cols * g.slot + (cols - 1) * g.gap
  g.height = g.numbers + rows * g.slot + (rows - 1) * g.gap
  return g
end

-- Cast bar: the share of the bar at its end covered by the latency, and where the spell queue
-- window opens (fraction from the left). nil when there is nothing to show.
function Layout.CastLag(latency, duration)
  if not duration or duration <= 0 then return nil end
  return math.min(1, latency / duration)
end

function Layout.CastQueue(windowMS, duration)
  local window = windowMS / 1000
  if not duration or duration <= window then return nil end
  return 1 - window / duration
end

-- Edit mode snapping. (x, y) is the moving box's top-left (y up), w x h its size; others: boxes
-- {x, y, w, h} of the other elements. An edge or center within `threshold` of another element's
-- edge/center, or of the screen's center, sticks to it (the guide line's position is returned);
-- otherwise the box sits on the grid.
function Layout.Snap(x, y, w, h, others, grid, threshold, screenW, screenH)
  local xs, ys = { screenW / 2 }, { screenH / 2 }
  for _, o in ipairs(others) do
    xs[#xs + 1], xs[#xs + 2], xs[#xs + 3] = o.x, o.x + o.w, o.x + o.w / 2
    ys[#ys + 1], ys[#ys + 2], ys[#ys + 3] = o.y, o.y - o.h, o.y - o.h / 2
  end
  local function best(pos, size, cands, down)
    local found, dist, guide = nil, threshold + 1, nil
    local edges = down and { { pos, 0 }, { pos - size, -size }, { pos - size / 2, -size / 2 } }
      or { { pos, 0 }, { pos + size, size }, { pos + size / 2, size / 2 } }
    for _, c in ipairs(cands) do
      for _, e in ipairs(edges) do
        local d = math.abs(e[1] - c)
        if d < dist then found, dist, guide = c - e[2], d, c end
      end
    end
    if found then return found, guide end
    return math.floor(pos / grid + 0.5) * grid, nil
  end
  local nx, gx = best(x, w, xs, false)
  local ny, gy = best(y, h, ys, true)
  return nx, ny, gx, gy
end
