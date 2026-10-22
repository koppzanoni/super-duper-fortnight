-- Permissive stand-in for the WoW API so addon files can be loaded outside the game.
-- Any unknown global, field or call returns another stub, so load-time code never errors
-- on a missing API. Tests that need real behavior replace specific globals.
local stubmt = {}
local function newstub() return setmetatable({}, stubmt) end
local NUMERIC = { GetWidth = 32, GetHeight = 32, GetFrameLevel = 1, GetScale = 1 }
stubmt.__index = function(t, k)
  if NUMERIC[k] then local v = NUMERIC[k]; return function() return v end end
  local s = newstub(); rawset(t, k, s); return s
end
stubmt.__call = function() return newstub() end
local function zero() return 0 end
stubmt.__add, stubmt.__sub, stubmt.__mul, stubmt.__div, stubmt.__unm = zero, zero, zero, zero, zero
stubmt.__concat = function() return "" end

STUB_EVENTS = {}

function CreateFrame()
  local f = newstub()
  f.handlers = {}
  f.SetScript = function(self, name, fn) self.handlers[name] = fn end
  f.GetScript = function(self, name) return self.handlers[name] end
  f.RegisterEvent = function(self, ev) STUB_EVENTS[#STUB_EVENTS + 1] = { frame = self, event = ev } end
  f.GetFrameLevel = function() return 1 end
  f.GetSize = function() return 1920, 1080 end
  f.GetWidth = function() return 1920 end
  f.GetHeight = function() return 1080 end
  f.IsProtected = function() return false end
  return f
end

-- Fire an event on every stub frame that registered it.
function STUB_FIRE(event, ...)
  for _, r in ipairs(STUB_EVENTS) do
    if r.event == event and r.frame.handlers.OnEvent then r.frame.handlers.OnEvent(r.frame, event, ...) end
  end
end

STUB_COMBAT = false
function InCombatLockdown() return STUB_COMBAT end
SlashCmdList = {}
UIParent = CreateFrame()
UISpecialFrames = {}
Enum = { PowerType = { Mana = 0, Rage = 1, Focus = 2, Energy = 3, ComboPoints = 4, Runes = 5, RunicPower = 6,
  SoulShards = 7, HolyPower = 9, Chi = 12, ArcaneCharges = 16 } }
PowerBarColor = setmetatable({}, { __index = function() return { r = 0.5, g = 0.5, b = 0.5 } end })
function hooksecurefunc() end
function print() end
-- Plain numbers for APIs the addon does math with (non-secret values only).
function UnitLevel() return 10 end
function GetMaxPlayerLevel() return 60 end
function UnitXP() return 300 end
function UnitXPMax() return 1000 end
function GetXPExhaustion() return nil end
STUB_TIME = 100
function GetTime() return STUB_TIME end
C_Container = {
  GetContainerNumSlots = function(bag) if bag <= 4 then return 4 end return 0 end,
  GetContainerItemInfo = function(bag, slot)
    if bag == 0 and slot == 1 then return { iconFileID = 1, stackCount = 5, quality = 2, itemID = 25 } end
    return nil
  end,
  ContainerIDToInventoryID = function(bag) return 30 + bag end,
}
C_Item = { GetItemInfoInstant = function(id) return id, "", "", "", 1, 2, 0 end }

-- Saved variables start as nil in the game; everything else unknown becomes a stub.
setmetatable(_G, { __index = function(t, k)
  if type(k) == "string" and k:find("^ObsidianUI") then return nil end
  local s = newstub(); rawset(t, k, s); return s
end })
