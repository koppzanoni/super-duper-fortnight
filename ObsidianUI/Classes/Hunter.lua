local _, ns = ...

-- Hunter: an Auto Shot timer while shooting (from your own Auto Shot casts; the last half second,
-- when moving delays the shot, shaded), the pet's happiness on the pet frame (clients that have
-- it), the pet's health as a thin bar under the player's bars, and reminders for low ammo and a
-- missing aspect (only the lasting aspects of clients that have them).
local Hunter = {}
ns.Hunter = Hunter

local AUTO_SHOT = 75
local SHOT_WINDOW = 0.5 -- seconds: Auto Shot's own cast at the end of the timer
local AMMO_SLOT = 0
local LOW_AMMO = 200
local ASPECTS = { 13165, 13163, 5118, 13159, 20043, 13161, 34074, 61846 } -- lasting aspects
local HAPPINESS_TEX = "Interface\\PetPaperDollFrame\\UI-PetHappiness"
local HAPPINESS_COORDS = { { 0.375, 0.5625 }, { 0.1875, 0.375 }, { 0, 0.1875 } } -- unhappy, content, happy

local function db() return ns.db or {} end
local function on(key) return db()[key] ~= false end
local function mine() return ns.Classes.Is("HUNTER") end
local function secret(v) return issecretvalue and issecretvalue(v) end

local frame = CreateFrame("Frame", nil, UIParent)
Hunter.frame = frame

-- Auto Shot -------------------------------------------------------------------------------------
local shot = ns.Classes.NewSwing("ObsidianUIHunterShot", "huntshot", "Tiro Automático (Caçador)", { 0.67, 0.83, 0.45 }, SHOT_WINDOW)
Hunter.shot = shot.bar
local shooting = false

local function shotCast(spellID)
  if not (mine() and on("c_hun_auto") and shooting) or secret(spellID) or spellID ~= AUTO_SHOT then return end
  shot:Start(UnitRangedDamage("player"))
end

-- Pet -------------------------------------------------------------------------------------------
local happy = frame:CreateTexture(nil, "OVERLAY")
happy:SetSize(18, 18)
happy:SetTexture(HAPPINESS_TEX)
happy:Hide()
Hunter.happy = happy

local function happinessUpdate()
  local pet = ns.UnitFrames.frames.pet
  local level = GetPetHappiness and GetPetHappiness()
  if not (mine() and on("c_hun_happy") and pet and UnitExists("pet") and level and HAPPINESS_COORDS[level]) then
    happy:Hide()
    return
  end
  happy.happiness = level
  local c = HAPPINESS_COORDS[level]
  happy:SetTexCoord(c[1], c[2], 0, 0.359375)
  happy:ClearAllPoints()
  happy:SetPoint("LEFT", pet.health or pet, "RIGHT", 4, 0)
  happy:Show()
end

local petHealth = CreateFrame("StatusBar", nil, UIParent)
petHealth:SetHeight(4)
ns.Widgets.Panel(petHealth)
petHealth:Hide()
Hunter.petHealth = petHealth

local function petHealthUpdate()
  local power = ns.UnitFrames.frames.player and ns.UnitFrames.frames.player.power
  if not (mine() and on("c_hun_pethp") and power and UnitExists("pet")) then petHealth:Hide() return end
  petHealth:ClearAllPoints()
  petHealth:SetPoint("TOPLEFT", power, "BOTTOMLEFT", 0, -2)
  petHealth:SetPoint("TOPRIGHT", power, "BOTTOMRIGHT", 0, -2)
  petHealth:SetStatusBarTexture(ns.Look.BarTexture())
  petHealth:SetStatusBarColor(0.38, 0.84, 0.2)
  petHealth:SetMinMaxValues(0, UnitHealthMax("pet")) -- status bars take secret values
  petHealth:SetValue(UnitHealth("pet"))
  petHealth:Show()
end

-- Reminders: ammo and aspect ------------------------------------------------------------------------
ns.Reminders.AddSource(function(add, buffs)
  if not mine() then return end
  if on("c_hun_ammo") and GetInventoryItemID and GetInventoryItemID("player", AMMO_SLOT) then
    local count = GetInventoryItemCount("player", AMMO_SLOT) or 0
    if count < LOW_AMMO then
      add("ammo", GetInventoryItemTexture and GetInventoryItemTexture("player", AMMO_SLOT) or "Interface\\Icons\\INV_Ammo_Arrow_02",
        "Munição: " .. count)
    end
  end
  if on("c_hun_aspect") then
    local known, active
    for _, id in ipairs(ASPECTS) do
      if ns.Reminders.Knows(id) then known = known or id end
      local n = ns.Reminders.SpellName(id)
      if n and buffs[n:lower()] then active = true end
    end
    if known and not active then add("aspect", C_Spell.GetSpellTexture(known), "Sem Aspecto") end
  end
end)

-- Setup -----------------------------------------------------------------------------------------
function Hunter.Refresh()
  if not mine() then return end
  shot:Place()
  frame:SetScript("OnUpdate", function() shot:Tick() end)
  if not on("c_hun_auto") then shot:Stop() end
  happinessUpdate()
  petHealthUpdate()
end

ns.On("PLAYER_LOGIN", function() Hunter.Refresh() end)
table.insert(ns.HUD.onResize, function() ns.RunOutOfCombat(Hunter.Refresh) end)
ns.On("START_AUTOREPEAT_SPELL", function() shooting = true end)
ns.On("STOP_AUTOREPEAT_SPELL", function() shooting = false; shot:Stop() end)
ns.On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID) if unit == "player" then shotCast(spellID) end end)
ns.On("UNIT_RANGEDDAMAGE", function(_, unit) if unit == "player" then shot:Rescale(UnitRangedDamage("player")) end end)
ns.On("UNIT_HAPPINESS", function(_, unit) if unit == "pet" then happinessUpdate() end end)
ns.On("UNIT_PET", function(_, unit) if unit == "player" then happinessUpdate(); petHealthUpdate() end end)
for _, ev in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH" }) do
  ns.On(ev, function(_, unit) if unit == "pet" then petHealthUpdate() end end)
end
ns.On("UNIT_INVENTORY_CHANGED", function(_, unit) if unit == "player" and mine() then ns.Reminders.Update() end end)

ns.Classes.Register("HUNTER", "Caçador", {
  { kind = "toggle", label = "Timer do Tiro Automático", key = "c_hun_auto", default = true,
    onChange = function() Hunter.Refresh() end, help = "Barra entre os tiros: não ande no fim dela (a parte escura)." },
  { kind = "toggle", label = "Felicidade do pet", key = "c_hun_happy", default = true,
    onChange = function() happinessUpdate() end, help = "Carinha ao lado do quadro do pet." },
  { kind = "toggle", label = "Vida do pet no quadro do jogador", key = "c_hun_pethp", default = true,
    onChange = function() petHealthUpdate() end, help = "Barra fina embaixo da sua barra de recurso." },
  { kind = "toggle", label = "Aviso de munição acabando", key = "c_hun_ammo", default = true,
    onChange = function() ns.Reminders.Update() end, help = "Nos Lembretes: menos de 200." },
  { kind = "toggle", label = "Lembrete de Aspecto", key = "c_hun_aspect", default = true,
    onChange = function() ns.Reminders.Update() end, help = "Nos Lembretes, quando nenhum aspecto está ligado." },
})
