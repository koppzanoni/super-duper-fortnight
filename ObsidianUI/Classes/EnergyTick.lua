local _, ns = ...

-- Energy tick: a mark crossing the player's energy bar every two seconds, in step with the
-- energy coming in, so the next tick can be timed. Only when energy really comes in 2 s jumps
-- (smooth regeneration shows nothing) and while the player's power is energy (cat form too).
-- Each class with the option says so in Classes.tickKeys[class] = its setting.
local EnergyTick = { ticking = false }
ns.EnergyTick = EnergyTick

local TICK = 2       -- seconds between energy ticks
local TICK_JUMP = 15 -- an energy rise this big is a tick

ns.Classes.tickKeys = {}

local function secret(v) return issecretvalue and issecretvalue(v) end
local function wanted()
  local key = ns.Classes.tickKeys[ns.Classes.Mine() or ""]
  return key ~= nil and ns.db ~= nil and ns.db[key] ~= false
end

local frame = CreateFrame("Frame", nil, UIParent)
EnergyTick.frame = frame
local lastEnergy, lastTick, small, energySecret = nil, nil, 0, false

local function energy()
  local v = UnitPower("player", Enum.PowerType.Energy)
  if secret(v) then energySecret = true return end
  energySecret = false
  if lastEnergy and v > lastEnergy then
    local d = v - lastEnergy
    if d >= TICK_JUMP then
      EnergyTick.ticking, lastTick, small = true, GetTime(), 0
    else
      small = small + 1
      if small >= 3 then EnergyTick.ticking = false end -- regenerates smoothly: no ticks to show
    end
  end
  lastEnergy = v
end

local function spark()
  local s = EnergyTick.spark
  if not s then
    local p = ns.UnitFrames.frames.player
    if not (p and p.power) then return end
    s = p.power:CreateTexture(nil, "OVERLAY")
    s:SetColorTexture(1, 1, 1, 0.9)
    s:SetBlendMode("ADD")
    s:SetWidth(2)
    s:Hide()
    EnergyTick.spark = s
  end
  return s
end

local function onUpdate()
  local s = spark()
  if not s then return end
  local max = UnitPowerMax("player", Enum.PowerType.Energy)
  if not (wanted() and EnergyTick.ticking and lastTick) or energySecret or secret(max)
    or UnitPowerType("player") ~= Enum.PowerType.Energy or (lastEnergy or 0) >= (max or 0) then
    s:Hide()
    return
  end
  local bar = s:GetParent()
  local p = ((GetTime() - lastTick) % TICK) / TICK
  s:ClearAllPoints()
  s:SetPoint("CENTER", bar, "LEFT", p * bar:GetWidth(), 0)
  s:SetHeight(bar:GetHeight() + 4)
  s:Show()
end
frame:SetScript("OnUpdate", onUpdate)

ns.On("PLAYER_LOGIN", spark)
ns.On("UNIT_POWER_FREQUENT", function(_, unit, token)
  if unit == "player" and token == "ENERGY" and wanted() then energy() end
end)
