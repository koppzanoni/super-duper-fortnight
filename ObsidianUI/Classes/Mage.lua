local _, ns = ...

-- Mage: the five second rule (Classes/FiveSecond.lua), reminders for a missing armor and for no
-- mana gem in the bags (once the character can conjure one), and an alert in the middle of the
-- screen while a proc is up (the game's own spell overlay: Brain Freeze, Clearcasting...).
local Mage = {}
ns.Mage = Mage

local ARMORS = { 168, 7302, 6117, 30482 } -- Frost, Ice, Mage, Molten Armor
local CONJURE_GEM = { 759, 3552, 10053, 10054, 27101, 42985 }
local GEMS = { 5514, 5513, 8007, 8008, 22044, 33312, 36799 }
-- Brain Freeze, Clearcasting, Fingers of Frost, Hot Streak, Missile Barrage (IDs across versions)
local PROCS = { 57761, 190446, 12536, 263725, 44544, 48108, 44401 }

local function db() return ns.db or {} end
local function on(key) return db()[key] ~= false end
local function mine() return ns.Classes.Is("MAGE") end

ns.Classes.fiveKeys.MAGE = "c_mag_5sr"

-- Reminders: armor and mana gem -------------------------------------------------------------------
local function known(list)
  for _, id in ipairs(list) do if ns.Reminders.Knows(id) then return id end end
end

ns.Reminders.AddSource(function(add, buffs)
  if not mine() then return end
  if on("c_mag_armor") then
    local armor, active = known(ARMORS), false
    for _, id in ipairs(ARMORS) do
      local n = ns.Reminders.SpellName(id)
      if n and buffs[n:lower()] then active = true end
    end
    if armor and not active then add("armor", C_Spell.GetSpellTexture(armor), "Sem armadura") end
  end
  if on("c_mag_gem") and C_Item and C_Item.GetItemCount then
    local conjure = known(CONJURE_GEM)
    local have = false
    for _, id in ipairs(GEMS) do if (C_Item.GetItemCount(id) or 0) > 0 then have = true end end
    if conjure and not have then add("managem", C_Spell.GetSpellTexture(conjure), "Sem gema de mana") end
  end
end)

-- Procs -----------------------------------------------------------------------------------------
local alert = ns.Classes.NewAlert()
Mage.alert = alert
local active, order = {}, {}

local function isProc(id)
  if issecretvalue and issecretvalue(id) then return false end
  for _, p in ipairs(PROCS) do if p == id then return true end end
  return false
end

local function procUpdate()
  local shown
  if mine() and on("c_mag_procs") then
    for i = #order, 1, -1 do if active[order[i]] then shown = order[i] break end end -- the newest
  end
  alert:Set(shown)
end

ns.On("SPELL_ACTIVATION_OVERLAY_SHOW", function(_, id)
  if not isProc(id) then return end
  active[id] = true
  order[#order + 1] = id
  procUpdate()
end)
ns.On("SPELL_ACTIVATION_OVERLAY_HIDE", function(_, id)
  if id == nil then active, order = {}, {} -- the game hides every overlay at once
  elseif isProc(id) then
    active[id] = nil
    for i = #order, 1, -1 do if order[i] == id then table.remove(order, i) end end
  end
  procUpdate()
end)

ns.Classes.Register("MAGE", "Mago", {
  { kind = "toggle", label = "Regra dos 5 segundos", key = "c_mag_5sr", default = true,
    help = "Marca na barra de mana: depois dela a mana volta a regenerar." },
  { kind = "toggle", label = "Lembrete de armadura", key = "c_mag_armor", default = true,
    onChange = function() ns.Reminders.Update() end, help = "Nos Lembretes, quando nenhuma armadura está ligada." },
  { kind = "toggle", label = "Gemas de mana prontas", key = "c_mag_gem", default = true,
    onChange = function() ns.Reminders.Update() end, help = "Nos Lembretes, quando não há gema de mana na bolsa." },
  { kind = "toggle", label = "Procs (Congelamento Cerebral, Lançamento Livre)", key = "c_mag_procs", default = true,
    onChange = procUpdate, help = "Ícone e nome no meio da tela enquanto o proc dura." },
})
