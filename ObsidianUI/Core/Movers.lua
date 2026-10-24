local _, ns = ...

-- Every HUD element the edit mode can move: its frame, the box drawn over it, and how the module
-- places it by default. Saved per element in ObsidianUIDB.layout[key] = { x, y, s }: (x, y) the
-- frame's top-left in UIParent units, s its size factor. Modules call Movers.Place(key) where
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

function Movers.Place(key)
  local item = Movers.items[key]
  if not item then return end
  local f, s = item.frame, Movers.Saved(key)
  if not item.ownScale then f:SetScale((item.base and item.base() or 1) * (s and s.s or 1)) end
  if s and s.x and s.y then
    local k = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", s.x / k, s.y / k)
  else
    item.default(f)
  end
end

-- Save an element's frame position (UIParent units) and size factor, then place it.
function Movers.Save(key, x, y, s)
  ns.db.layout = ns.db.layout or {}
  local saved = ns.db.layout[key] or {}
  if x then saved.x, saved.y = x, y end
  if s then saved.s = s end
  ns.db.layout[key] = saved
end

function Movers.Forget(key)
  if ns.db and ns.db.layout then ns.db.layout[key] = nil end
end
