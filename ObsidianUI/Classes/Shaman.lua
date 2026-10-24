local _, ns = ...

-- Shaman: a totem bar (the four elements, each with the game's own countdown, dim when empty;
-- under the player frame or above the action bar), reminders for a missing or ending weapon
-- imbue and a missing Lightning/Water Shield, and the five second rule (Classes/FiveSecond.lua).
local Shaman = { slots = {} }
ns.Shaman = Shaman

local SLOTS = 4
local SIZE, GAP = 30, 5
local SOON = 5 * 60 -- seconds: an imbue with less than this is running out
local IMBUES = { 8017, 8024, 8033, 8232, 33757, 318038, 382021, 51730 }
local SHIELDS = { 324, 192106, 52127, 974 } -- Lightning Shield (two IDs), Water Shield, Earth Shield
local EMPTY = "Interface\\Icons\\INV_Misc_QuestionMark"

local function db() return ns.db or {} end
local function on(key) return db()[key] ~= false end
local function mine() return ns.Classes.Is("SHAMAN") end

ns.Classes.fiveKeys.SHAMAN = "c_sha_5sr"

-- Totem bar -------------------------------------------------------------------------------------
local bar = CreateFrame("Frame", "ObsidianUIShamanTotems", UIParent)
bar:SetSize(SLOTS * SIZE + (SLOTS - 1) * GAP, SIZE)
bar:Hide()
Shaman.totems = bar

for i = 1, SLOTS do
  local s = CreateFrame("Frame", nil, bar)
  s:SetSize(SIZE, SIZE)
  s:SetPoint("LEFT", bar, "LEFT", (i - 1) * (SIZE + GAP), 0)
  s.icon = s:CreateTexture(nil, "ARTWORK")
  s.icon:SetAllPoints(s)
  s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  s.border = s:CreateTexture(nil, "OVERLAY")
  s.border:SetAllPoints(s)
  s.cd = CreateFrame("Cooldown", nil, s, "CooldownFrameTemplate")
  s.cd:SetAllPoints(s)
  s.cd:SetReverse(true)
  if s.cd.SetHideCountdownNumbers then s.cd:SetHideCountdownNumbers(false) end
  Shaman.slots[i] = s
end

local function place()
  bar:ClearAllPoints()
  local player = ns.UnitFrames.frames.player
  if db().c_sha_totpos == "bar" or not player then
    bar:SetPoint("BOTTOM", ns.Stack.Anchor(), "TOP", 0, 34) -- the gems' spot (no gem row for shamans)
  else
    bar:SetPoint("TOPLEFT", player, "BOTTOMLEFT", 0, -6)
  end
end

local function totemUpdate()
  if not (mine() and on("c_sha_totems") and GetTotemInfo) then bar:Hide() return end
  local any = false
  for i, s in ipairs(Shaman.slots) do
    local have, _, start, duration, icon = GetTotemInfo(i)
    ns.Media.Apply(s.border, ns.ModernTex("mod_slot"))
    if have and icon then
      any = true
      s.icon:SetTexture(icon)
      s.icon:SetAlpha(1)
      s.icon:SetDesaturated(false)
      if not pcall(s.cd.SetCooldown, s.cd, start, duration) then s.cd:Clear() end -- the game counts down
    else
      s.icon:SetTexture(EMPTY)
      s.icon:SetAlpha(0.25)
      s.icon:SetDesaturated(true)
      s.cd:Clear()
    end
  end
  if not any then bar:Hide() return end
  place()
  bar:Show()
end

-- Reminders: weapon imbue and shield -------------------------------------------------------------------
ns.Reminders.AddSource(function(add, buffs)
  if not mine() then return end
  if on("c_sha_weapon") and GetWeaponEnchantInfo then
    local imbue
    for _, id in ipairs(IMBUES) do if ns.Reminders.Knows(id) then imbue = imbue or id end end
    if imbue then
      local has, ms = GetWeaponEnchantInfo()
      if not has then
        add("weapon", C_Spell.GetSpellTexture(imbue), "Arma sem encantamento")
      elseif ms and ms / 1000 < SOON then
        add("weapon", C_Spell.GetSpellTexture(imbue), "Encantamento acabando (" .. math.max(1, math.floor(ms / 60000 + 0.5)) .. " min)")
      end
    end
  end
  if on("c_sha_shield") then
    local known, active
    for _, id in ipairs(SHIELDS) do
      if ns.Reminders.Knows(id) then known = known or id end
      local n = ns.Reminders.SpellName(id)
      if n and buffs[n:lower()] then active = true end
    end
    if known and not active then add("shashield", C_Spell.GetSpellTexture(known), "Sem Escudo de Raios / Água") end
  end
end)

-- Setup -----------------------------------------------------------------------------------------
function Shaman.Refresh()
  if not mine() then return end
  totemUpdate()
end

ns.On("PLAYER_LOGIN", function() Shaman.Refresh() end)
table.insert(ns.HUD.onResize, function() ns.RunOutOfCombat(Shaman.Refresh) end)
ns.On("PLAYER_TOTEM_UPDATE", function() if mine() then totemUpdate() end end)
ns.On("PLAYER_ENTERING_WORLD", function() if mine() then totemUpdate() end end)

ns.Classes.Register("SHAMAN", "Xamã", {
  { kind = "toggle", label = "Barra de totens", key = "c_sha_totems", default = true,
    onChange = totemUpdate, help = "Os 4 elementos com o tempo de cada totem." },
  { kind = "choice", label = "Onde", key = "c_sha_totpos", default = "player",
    options = { { "player", "Embaixo do jogador" }, { "bar", "Sobre a barra" } }, onChange = totemUpdate },
  { kind = "toggle", label = "Arma encantada acabando", key = "c_sha_weapon", default = true,
    onChange = function() ns.Reminders.Update() end, help = "Nos Lembretes: sem encantamento ou com menos de 5 minutos." },
  { kind = "toggle", label = "Escudo de Raios / Água", key = "c_sha_shield", default = true,
    onChange = function() ns.Reminders.Update() end, help = "Nos Lembretes, quando nenhum escudo está ligado." },
  { kind = "toggle", label = "Regra dos 5 segundos", key = "c_sha_5sr", default = true,
    help = "Marca na barra de mana: depois dela a mana volta a regenerar." },
})
