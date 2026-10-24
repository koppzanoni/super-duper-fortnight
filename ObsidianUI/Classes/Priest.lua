local _, ns = ...

-- Priest: the five second rule on the mana bar (Classes/FiveSecond.lua), Power Word: Shield (or
-- Weakened Soul, dimmed) as a small icon on each party frame (a line on raid cells), and a
-- reminder counting group members without Fortitude (alone, the class-buff reminder covers you).
local Priest = {}
ns.Priest = Priest

local SHIELD, WEAKENED = 17, 6788
local FORTITUDE = { 21562, 1243, 21564 } -- Power Word: Fortitude (two IDs across versions), Prayer of Fortitude
local ICON = 14

local function db() return ns.db or {} end
local function on(key) return db()[key] ~= false end
local function mine() return ns.Classes.Is("PRIEST") end

ns.Classes.fiveKeys.PRIEST = "c_pri_5sr"

-- Shield / Weakened Soul on the group frames ----------------------------------------------------------
local function auraOn(unit, id)
  local A = C_UnitAuras
  if UnitIsUnit and UnitIsUnit(unit, "player") and A.GetPlayerAuraBySpellID then return A.GetPlayerAuraBySpellID(id) end
  return A.GetUnitAuraBySpellID and A.GetUnitAuraBySpellID(unit, id)
end

-- Raid cells have no free corner (debuffs, role, marker, the name on top): a thin line along
-- the top edge instead, white for the shield, grey for Weakened Soul. Drawn on the health bar
-- itself: a child bar draws over its frame's own textures.
local function cellLine(owner, id)
  local line = owner.priestLine
  if not id then
    if line then line:Hide(); line.shade:Hide() end
    return
  end
  if not line then
    line = (owner.health or owner):CreateTexture(nil, "OVERLAY", nil, 7)
    line:SetPoint("TOPLEFT", owner.health or owner, "TOPLEFT", 0, 0)
    line:SetPoint("TOPRIGHT", owner.health or owner, "TOPRIGHT", 0, 0)
    line:SetHeight(3)
    line.shade = (owner.health or owner):CreateTexture(nil, "OVERLAY", nil, 6) -- dark edge: readable on any class colour
    line.shade:SetColorTexture(0, 0, 0, 0.8)
    line.shade:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, 0)
    line.shade:SetPoint("TOPRIGHT", line, "BOTTOMRIGHT", 0, 0)
    line.shade:SetHeight(1)
    owner.priestLine = line
  end
  if id == SHIELD then line:SetColorTexture(1, 1, 1, 1) else line:SetColorTexture(0.5, 0.5, 0.53, 1) end
  line:Show()
  line.shade:Show()
end

local function indicator(owner)
  local icon = owner.priestIcon
  local id = mine() and on("c_pri_shield") and owner.unit and UnitExists(owner.unit)
    and ((auraOn(owner.unit, SHIELD) and SHIELD) or (auraOn(owner.unit, WEAKENED) and WEAKENED))
  if owner.isCell then cellLine(owner, id or nil) return end
  if not id then
    if icon then icon:Hide() end
    return
  end
  if not icon then
    icon = (owner.health or owner):CreateTexture(nil, "OVERLAY", nil, 7)
    icon:SetSize(ICON, ICON)
    icon:SetPoint("TOPRIGHT", owner.health or owner, "TOPRIGHT", -2, -2)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    owner.priestIcon = icon
  end
  icon:SetTexture(C_Spell.GetSpellTexture(id))
  icon:SetAlpha(id == SHIELD and 1 or 0.55)
  icon:SetDesaturated(id == WEAKENED)
  icon:Show()
end
ns.GroupFrames.AddIndicator(indicator)

-- Fortitude in the group (reminders) ----------------------------------------------------------------
ns.Reminders.AddSource(function(add)
  if not (mine() and on("c_pri_fort") and IsInGroup()) then return end
  local known
  for _, id in ipairs(FORTITUDE) do if ns.Reminders.Knows(id) then known = known or id end end
  if not known then return end
  local missing = ns.Reminders.CountMissing(ns.Reminders.GroupMembers(false), ns.Reminders.Names(FORTITUDE))
  if missing > 0 then add("fort", C_Spell.GetSpellTexture(known), "Fortitude faltando em " .. missing) end
end)

local pending = false
ns.On("UNIT_AURA", function(_, unit)
  if not (mine() and on("c_pri_fort") and unit and (unit:find("^party") or unit:find("^raid"))) or pending then return end
  pending = true
  C_Timer.After(1, function() pending = false; ns.Reminders.Update() end)
end)

ns.Classes.Register("PRIEST", "Sacerdote", {
  { kind = "toggle", label = "Regra dos 5 segundos", key = "c_pri_5sr", default = true,
    help = "Marca na barra de mana: depois dela a mana volta a regenerar." },
  { kind = "toggle", label = "Escudo e Alma Enfraquecida no grupo", key = "c_pri_shield", default = true,
    onChange = function() ns.GroupFrames.Update() end, help = "Ícone pequeno no canto de cada membro (Alma Enfraquecida apagada)." },
  { kind = "toggle", label = "Fortitude faltando no grupo", key = "c_pri_fort", default = true,
    onChange = function() ns.Reminders.Update() end, help = "Nos Lembretes: quantos do grupo estão sem Fortitude." },
})
