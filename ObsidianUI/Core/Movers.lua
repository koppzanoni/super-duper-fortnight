local _, ns = ...

-- Every HUD element the edit mode can move: its frame, the box drawn over it, and how the module
-- places it by default. Saved per element in ObsidianUIDB.layout[key] = { x, y, s, to, dx, dy }:
-- (x, y) the frame's top-left in UIParent units, s its size factor, and when anchored to element
-- `to`, the distance (dx, dy) from that element's top-left. Modules call Movers.Place(key) where
-- they used to set the frame's points.
local Movers = { items = {}, order = {} }
ns.Movers = Movers

function Movers.Saved(key)
  return ns.db and ns.db.layout and ns.db.layout[key]
end

-- Size factor of an element (1 when never resized).
function Movers.Scale(key)
  local s = Movers.Saved(key)
  return s and s.s or 1
end

-- opts.box: the region the edit box covers (default: the frame); opts.base: the frame's own
-- scale before the size factor; opts.ownScale: the module sizes the element itself from
-- Movers.Scale(key) (frames whose buttons are not their children).
function Movers.Register(key, label, frame, default, opts)
  local item = Movers.items[key]
  if not item then
    item = { key = key }
    Movers.items[key] = item
    Movers.order[#Movers.order + 1] = key
  end
  opts = opts or {}
  item.label, item.frame, item.default = label, frame, default
  item.box, item.base, item.ownScale = opts.box or frame, opts.base, opts.ownScale
  return item
end

-- A frame's top-left and size in UIParent units.
function Movers.Rect(region)
  local k = region:GetEffectiveScale() / UIParent:GetEffectiveScale()
  local left, top = region:GetLeft(), region:GetTop()
  if not left or not top then return nil end
  return { x = left * k, y = top * k, w = region:GetWidth() * k, h = region:GetHeight() * k }
end

-- An anchored element's top-left: its anchor's top-left plus the saved distance (nil when the
-- anchor cannot be measured: the plain saved position then).
local function anchoredAt(s)
  local anchor = s and s.to and Movers.items[s.to]
  local r = anchor and Movers.Rect(anchor.frame)
  if r and s.dx and s.dy then return r.x + s.dx, r.y + s.dy end
end

-- The elements anchored to `key` follow it. Placed through UIParent, never anchored to the other
-- frame: a protected frame hanging from one that moves in combat would be blocked.
local function placeDependents(key, depth)
  if depth > #Movers.order then return end
  for _, k in ipairs(Movers.order) do
    local s = Movers.Saved(k)
    if s and s.to == key then Movers.Place(k, depth + 1) end
  end
end

function Movers.Place(key, depth)
  local item = Movers.items[key]
  if not item then return end
  local f, s = item.frame, Movers.Saved(key)
  if not item.ownScale then f:SetScale((item.base and item.base() or 1) * (s and s.s or 1)) end
  local x, y = anchoredAt(s)
  if not x and s then x, y = s.x, s.y end
  if x and y then
    local k = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / k, y / k)
  else
    item.default(f)
  end
  placeDependents(key, depth or 0)
end

-- After a full layout: every anchored element once more, now that its anchor has moved.
function Movers.PlaceAnchored()
  for _, k in ipairs(Movers.order) do
    local s = Movers.Saved(k)
    if s and s.to and not (Movers.Saved(s.to) or {}).to then Movers.Place(k) end -- chains follow
  end
end

-- Whether anchoring `key` to `to` would close a loop.
local function loops(key, to)
  local seen, k = 0, to
  while k do
    if k == key then return true end
    seen = seen + 1
    if seen > #Movers.order then return true end
    k = (Movers.Saved(k) or {}).to
  end
  return false
end

-- Anchors `key` to element `to` where it is now (nil: free again). False for a loop.
function Movers.Anchor(key, to)
  if to and (not Movers.items[to] or loops(key, to)) then return false end
  ns.db.layout = ns.db.layout or {}
  local saved = ns.db.layout[key] or {}
  local r = Movers.Rect(Movers.items[key].frame)
  if r then saved.x, saved.y = r.x, r.y end
  saved.to, saved.dx, saved.dy = nil, nil, nil
  if to then
    local a = Movers.Rect(Movers.items[to].frame)
    if not (a and r) then return false end
    saved.to, saved.dx, saved.dy = to, r.x - a.x, r.y - a.y
  end
  ns.db.layout[key] = saved
  return true
end

-- Save an element's frame position (UIParent units) and size factor, then place it.
function Movers.Save(key, x, y, s)
  ns.db.layout = ns.db.layout or {}
  local saved = ns.db.layout[key] or {}
  if x then
    saved.x, saved.y = x, y
    local a = saved.to and Movers.items[saved.to] and Movers.Rect(Movers.items[saved.to].frame)
    if a then saved.dx, saved.dy = x - a.x, y - a.y end -- moved by hand: same anchor, new distance
  end
  if s then saved.s = s end
  ns.db.layout[key] = saved
end

function Movers.Forget(key)
  if ns.db and ns.db.layout then ns.db.layout[key] = nil end
end
