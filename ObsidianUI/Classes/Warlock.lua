local _, ns = ...

-- Warlock: the soul shards in the bags as a number where the gems would be (clients where shards
-- are items; where they are a resource, the gems show them), reminders for no healthstone and no
-- soulstone (on anyone in the group or in the bags), DoT timers on the target, and the demon's
-- health and mana as thin bars under the player's bars.
local Warlock = {}
ns.Warlock = Warlock

local SHARD = 6265
local DRAIN_SOUL = 1120
local CREATE_HEALTHSTONE = { 6201, 6202, 5699, 11729, 11730 }
local HEALTHSTONES = { 5512, 19004, 19005, 5511, 19006, 19007, 5509, 19008, 19009, 5510, 19010, 19011, 9421, 19012, 19013 }
local SOULSTONE_SPELLS = { 20707, 693, 20752, 20755, 20756, 20757 } -- the buff, then Create Soulstone ranks
local SOULSTONES = { 5232, 16892, 16893, 16895, 16896 }

local function db() return ns.db or {} end
local function on(key) return db()[key] ~= false end
local function mine() return ns.Classes.Is("WARLOCK") end
local function count(id) return C_Item and C_Item.GetItemCount and (C_Item.GetItemCount(id) or 0) or 0 end
local function anyItem(list) for _, id in ipairs(list) do if count(id) > 0 then return true end end return false end
local function known(list) for _, id in ipairs(list) do if ns.Reminders.Knows(id) then return id end end end

-- Soul shard counter ----------------------------------------------------------------------------
local shards = CreateFrame("Frame", nil, UIParent)
shards:SetSize(60, 26)
shards.icon = shards:CreateTexture(nil, "ARTWORK")
shards.icon:SetSize(20, 20)
shards.icon:SetPoint("LEFT", shards, "LEFT", 0, 0)
shards.icon:SetTexture("Interface\\Icons\\INV_Misc_Gem_Amethyst_02")
shards.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
shards.text = shards:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
shards.text:SetPoint("LEFT", shards.icon, "RIGHT", 6, 0)
shards:Hide()
Warlock.shards = shards

local function shardUpdate()
  local n = count(SHARD)
  -- shards as items: some in the bags, or a spell that makes them (Drain Soul) while none are left
  -- (where the gems show shards as a resource, they are the counter)
  if not (mine() and on("c_wl_shards")) or ns.ClassResource.holder:IsShown()
    or (n == 0 and not ns.Reminders.Knows(DRAIN_SOUL)) then shards:Hide() return end
  shards:ClearAllPoints()
  shards:SetPoint("BOTTOM", ns.Stack.Anchor(), "TOP", 0, 34) -- the gems' spot
  ns.Look.SetFont(shards.text, 20)
  shards.text:SetText(tostring(n))
  if n == 0 then shards.text:SetTextColor(1, 0.3, 0.3) else shards.text:SetTextColor(0.75, 0.6, 1) end
  shards:SetWidth(20 + 6 + (tonumber(shards.text:GetStringWidth()) or 20))
  shards:Show()
end

-- Reminders: healthstone and soulstone -----------------------------------------------------------------
ns.Reminders.AddSource(function(add)
  if not (mine() and on("c_wl_stones")) then return end
  local create = known(CREATE_HEALTHSTONE)
  if create and not anyItem(HEALTHSTONES) then add("healthstone", C_Spell.GetSpellTexture(create), "Sem pedra de vida") end
  local soul = known(SOULSTONE_SPELLS)
  if soul then
    local members = ns.Reminders.GroupMembers(true)
    local onSomeone = ns.Reminders.CountMissing(members, ns.Reminders.Names({ SOULSTONE_SPELLS[1] })) < #members
    if not onSomeone and not anyItem(SOULSTONES) then add("soulstone", C_Spell.GetSpellTexture(soul), "Sem pedra da alma") end
  end
end)

-- DoTs ------------------------------------------------------------------------------------------
local timers = ns.Classes.NewTimers("ObsidianUIWarlockTimers", "wltimers", "DoTs (Bruxo)", {
  { label = "Corrupção", unit = "target", ids = { 172, 146739 }, color = { 0.6, 0.3, 0.9 }, mine = true },
  { label = "Agonia", unit = "target", ids = { 980 }, color = { 0.85, 0.65, 0.2 }, mine = true },
  { label = "Imolar", unit = "target", ids = { 348, 157736 }, color = { 0.95, 0.45, 0.1 }, mine = true },
  { label = "Sifão de Vida", unit = "target", ids = { 18265 }, color = { 0.3, 0.8, 0.3 }, mine = true },
  { label = "Aflição Instável", unit = "target", ids = { 30108, 316099 }, color = { 0.5, 0.2, 0.7 }, mine = true },
})
Warlock.timers, Warlock.bars = timers.frame, timers.bars
local function timerUpdate(unit) timers:Update(unit, mine() and on("c_wl_dots")) end

-- Demon -----------------------------------------------------------------------------------------
local pet = ns.Classes.NewPetBars(true)
Warlock.pet = pet
local function petUpdate() pet:Update(mine() and on("c_wl_pet")) end

-- Setup -----------------------------------------------------------------------------------------
local frame = CreateFrame("Frame", nil, UIParent)
function Warlock.Refresh()
  if not mine() then return end
  timers:Place()
  frame:SetScript("OnUpdate", function() timers:Tick() end)
  shardUpdate()
  timerUpdate()
  petUpdate()
end

ns.On("PLAYER_LOGIN", function() Warlock.Refresh() end)
table.insert(ns.HUD.onResize, function() ns.RunOutOfCombat(Warlock.Refresh) end)
-- again once the gems have shown or hidden (ClassResource listens first: it loads earlier)
for _, ev in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED" }) do
  ns.On(ev, function() if mine() then shardUpdate() end end)
end
ns.On("PLAYER_TARGET_CHANGED", function() if mine() then timerUpdate("target") end end)
ns.On("UNIT_AURA", function(_, unit) if mine() and unit == "target" then timerUpdate(unit) end end)
ns.On("UNIT_PET", function(_, unit) if unit == "player" and mine() then petUpdate() end end)
for _, ev in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER" }) do
  ns.On(ev, function(_, unit) if unit == "pet" and mine() then petUpdate() end end)
end

ns.Classes.Register("WARLOCK", "Bruxo", {
  { kind = "toggle", label = "Contador de fragmentos na mochila", key = "c_wl_shards", default = true,
    onChange = shardUpdate, help = "Quantos fragmentos de alma há nas bolsas, no lugar das gemas." },
  { kind = "toggle", label = "Pedra de alma e de vida", key = "c_wl_stones", default = true,
    onChange = function() ns.Reminders.Update() end, help = "Nos Lembretes: sem pedra de vida, ou ninguém com pedra da alma." },
  { kind = "toggle", label = "DoTs no alvo (tempo restante)", key = "c_wl_dots", default = true,
    onChange = function() timerUpdate() end, help = "Os seus, em barras acima da barra de cast." },
  { kind = "toggle", label = "Vida e mana do demônio", key = "c_wl_pet", default = true,
    onChange = petUpdate, help = "Barras finas embaixo da sua barra de recurso." },
})
