local _, ns = ...

-- Smooth status bars: a StatusBar's fill glides to a new value over a short moment instead of
-- jumping. Wrap a bar once (Smooth.Wrap); its SetValue then records a target and a single driver
-- frame eases every wrapped bar towards its target each frame. The ease is frame-rate independent
-- (an exponential approach), so it feels the same at 30 or 144 fps.
--
-- Secret values: in combat a unit's health or power can be a secret value, which errors on any
-- arithmetic. The wrapper never does math on the value it is given: a secret (or non-number) goes
-- straight to the real SetValue, which accepts it, and the bar stops easing until a plain number
-- comes back. The per-frame easing reads the bar's own shown value, always a plain number we set.
--
-- Unit changes: when a frame's unit changes (a new target), the bar should not crawl across from
-- the old unit's value. Smooth.Snap marks the next SetValue to land at once.
local Smooth = {}
ns.Smooth = Smooth

local TAU = 0.20 -- seconds: time constant of the approach (subtle; ~0.6 s to practically settle)
local active = setmetatable({}, { __mode = "k" }) -- wrapped bars currently easing

local function enabled() return not (ns.db and ns.db.smoothBars == false) end

-- Move a bar's shown value one frame towards its target. Called inside pcall by the driver.
local function step(bar, elapsed)
  local cur, target = bar.obShown, bar.obTarget
  local diff = target - cur
  if diff < 0 then diff = -diff end
  if diff <= bar.obMin then
    bar.obShown = target
    active[bar] = nil
    bar.obSet(bar, target)
    return
  end
  -- fraction of the remaining gap to close this frame; clamped so a long frame still can't overshoot
  local f = 1 - math.exp(-elapsed / TAU)
  if f > 1 then f = 1 end
  bar.obShown = cur + (target - cur) * f
  bar.obSet(bar, bar.obShown)
end

local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, elapsed)
  for bar in pairs(active) do
    if not pcall(step, bar, elapsed) then active[bar] = nil end
  end
end)
Smooth.driver = driver

-- Land the next SetValue at once (no slide): called when a bar's unit changes.
function Smooth.Snap(bar)
  if bar and bar.obWrapped then bar.obSnap = true end
end

-- The smallest change worth easing: a thousandth of the bar's range, so tiny ticks still settle.
local function minStep(bar)
  local ok, _, max = pcall(bar.GetMinMaxValues, bar)
  if ok and type(max) == "number" and max > 0 then return max * 0.001 end
  return 0.001
end

function Smooth.Wrap(bar)
  if bar.obWrapped then return end
  bar.obWrapped = true
  bar.obSet = bar.SetValue
  bar.obShown = 0
  bar.obTarget = 0
  bar.obMin = 0.001
  bar.SetValue = function(self, v)
    -- Off, not a plain number, or a secret value: straight through, and stop easing.
    if not enabled() or type(v) ~= "number" or (issecretvalue and issecretvalue(v)) then
      active[self] = nil
      if type(v) == "number" then self.obShown = v end
      return self.obSet(self, v)
    end
    if self.obSnap then
      self.obSnap = nil
      self.obShown = v
      active[self] = nil
      return self.obSet(self, v)
    end
    self.obMin = minStep(self)
    local diff = v - self.obShown
    if (diff < 0 and -diff or diff) <= self.obMin then
      self.obShown = v
      active[self] = nil
      return self.obSet(self, v)
    end
    self.obTarget = v
    active[self] = true
  end
  return bar
end
