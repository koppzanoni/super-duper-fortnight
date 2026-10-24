local _, ns = ...

-- Cooldown numbers on icons: the game's own countdown on each cooldown frame (so it keeps
-- working in combat), turned on per frame without touching any game setting. Short cooldowns
-- (the global one) stay quiet, the last seconds show tenths, and the numbers use the HUD's font
-- at a size that follows the icon. Action bars, bag items, your buffs and debuffs and the
-- target's debuffs.
local Cooldowns = {}
ns.Cooldowns = Cooldowns

local W = ns.Widgets
local TENTHS = 3 -- seconds
-- Bumped when a setting or the sizes change: frames styled for an older version are redone.
local version = 1

local function db() return ns.db or {} end
local function on(key) return db()[key] ~= false end

-- One cooldown frame; show: numbers on or off for its group.
local function style(cd, show)
  if not cd or not cd.SetHideCountdownNumbers or cd.obVersion == version then return end
  cd.obVersion = version
  pcall(cd.SetHideCountdownNumbers, cd, not show)
  if not show then return end
  if cd.SetMinimumCountdownDuration then pcall(cd.SetMinimumCountdownDuration, cd, (db().cdMin or 1.5) * 1000) end
  if cd.SetCountdownMillisecondsThreshold then
    pcall(cd.SetCountdownMillisecondsThreshold, cd, db().cdDecimals == false and 0 or TENTHS)
  end
  local fs = cd.GetCountdownFontString and cd:GetCountdownFontString()
  if fs then
    local w = cd:GetParent() and cd:GetParent():GetWidth() or 36
    ns.Look.SetFont(fs, math.max(10, math.min(28, w * 0.4)))
    fs:SetTextColor(W.WHITE[1], W.WHITE[2], W.WHITE[3])
  end
end

local function each(list, key, show)
  for _, b in pairs(list or {}) do
    if type(b) == "table" then style(rawget(b, key), show) end
  end
end

-- Styles the frames not styled yet (new buttons); Refresh redoes them all.
function Cooldowns.Update()
  local all = on("cd_on")
  each(ns.ActionBars and ns.ActionBars.buttons, "cooldown", all)
  local auras = all and on("cdAuras")
  if ns.Auras and ns.Auras.rows then
    for _, row in pairs(ns.Auras.rows) do each(row.buttons, "cd", auras) end
  end
  each(ns.UnitFrames and ns.UnitFrames.debuffs, "cd", auras)
  if ns.Inventory and ns.Inventory.bagButtons then each(ns.Inventory.bagButtons(), "Cooldown", all) end
end

function Cooldowns.Refresh()
  version = version + 1
  Cooldowns.Update()
end

-- New buttons come with layouts, auras and bag changes: styled then (cheap, idempotent).
ns.On("PLAYER_LOGIN", function() Cooldowns.Refresh() end)
table.insert(ns.HUD.onResize, function() Cooldowns.Refresh() end)
ns.On("UNIT_AURA", function(_, unit) if unit == "player" or unit == "target" then Cooldowns.Update() end end)
ns.On("PLAYER_TARGET_CHANGED", Cooldowns.Update)
ns.On("BAG_UPDATE_DELAYED", Cooldowns.Update)
