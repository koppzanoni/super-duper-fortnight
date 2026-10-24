local _, ns = ...

-- The five second rule for mana users: after a spell that costs mana, a mark crosses the player's
-- mana bar in five seconds; past it, mana regenerates again. Each class with the option says so in
-- Classes.fiveKeys[class] = its setting. Only while the player's power is mana (not in forms).
local FiveSecond = {}
ns.FiveSecond = FiveSecond

local RULE = 5 -- seconds

ns.Classes.fiveKeys = {}

local function wanted()
  local key = ns.Classes.fiveKeys[ns.Classes.Mine() or ""]
  return key ~= nil and ns.db ~= nil and ns.db[key] ~= false
end

local frame = CreateFrame("Frame", nil, UIParent)
FiveSecond.frame = frame
local since

-- Whether the spell costs mana (plain answers only).
local function costsMana(spellID)
  if (issecretvalue and issecretvalue(spellID)) or not (C_Spell and C_Spell.GetSpellPowerCost) then return false end
  local ok, mana = pcall(function()
    for _, c in ipairs(C_Spell.GetSpellPowerCost(spellID) or {}) do
      if c.type == Enum.PowerType.Mana and (c.cost or 0) > 0 then return true end
    end
    return false
  end)
  return ok and mana
end

local function spark()
  local s = FiveSecond.spark
  if not s then
    local p = ns.UnitFrames.frames.player
    if not (p and p.power) then return end
    s = p.power:CreateTexture(nil, "OVERLAY")
    s:SetColorTexture(1, 1, 1, 0.9)
    s:SetBlendMode("ADD")
    s:SetWidth(2)
    s:Hide()
    FiveSecond.spark = s
  end
  return s
end

local function onUpdate()
  local s = spark()
  if not s then return end
  local t = since and GetTime() - since
  if not (t and t < RULE and wanted() and UnitPowerType("player") == Enum.PowerType.Mana) then
    s:Hide()
    return
  end
  local bar = s:GetParent()
  s:ClearAllPoints()
  s:SetPoint("CENTER", bar, "LEFT", t / RULE * bar:GetWidth(), 0)
  s:SetHeight(bar:GetHeight() + 4)
  s:Show()
end
frame:SetScript("OnUpdate", onUpdate)

ns.On("PLAYER_LOGIN", spark)
ns.On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
  if unit == "player" and wanted() and costsMana(spellID) then since = GetTime() end
end)
