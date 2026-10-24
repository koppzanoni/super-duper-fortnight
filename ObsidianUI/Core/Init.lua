local addonName, ns = ...

ns.name = addonName

-- Default settings (also what a new profile starts from, Core/Profiles.lua).
local DEFAULTS = { vbar1 = false, vbar2 = false, scale = 1.0, invScale = 1.0, showHotkeys = true,
  -- the HUD (the stone HUD retired: git tag hud-pedra-final)
  modernColor = "black", arcaneRing = true, modernRows = 2, modernCols = 12,
  castLag = true, castMs = true, castQueue = true,
  font = "default", outline = "OUTLINE", barTex = "gloss", numFmt = "short",
  res_on = true, resStyle = "gems", resHide = false, buffs_on = true, debuffs_on = true, buffSize = 26, buffRow = 16,
  xp_on = true, rep_on = true, dataText = "hover", dataHeight = 5,
  party_on = true, raid_on = true, raidW = 72, raidH = 36, raidGrowth = "rows",
  partyPlayer = false, partyStyle = "frames", groupDebuffs = true, raidTools = true,
  plates_on = true, plateW = 140, plateH = 10, plateHP = true, plateCast = true, plateDebuffs = true, plateFade = true,
  chat_on = true, chatButtons = false, chatFade = 120,
  tip_on = true, tipAnchor = "default", tipCombat = true,
  quest_on = true, questCombat = true, questInstance = false,
  skins_on = true, cd_on = true, cdAuras = true, cdMin = 1.5, cdDecimals = true,
  curRing = false, curTrail = false, curCombat = true, curSize = 1,
  autoJunk = true, autoRepair = "guild", autoInvite = true, noDuel = false, autoRes = true, autoRelease = true,
  skipCine = true, fastLoot = true, hideErrors = false, afkScreen = true,
  rmBuff = true, rmFood = true, rmPoison = true, rmRepair = true, rmBags = true,
  c_rog_tick = true, c_rog_ontarget = false, c_rog_snd = true, c_rog_poison = true,
  c_war_swing = true, c_war_proc = true, c_war_stance = false, c_war_text = true,
  c_pal_aura = true, c_pal_judge = true, c_pal_bless = true,
  c_hun_auto = true, c_hun_happy = true, c_hun_pethp = true, c_hun_ammo = true, c_hun_aspect = true,
  c_pri_5sr = true, c_pri_shield = true, c_pri_fort = true,
  c_dk_types = true, c_dk_cd = true, c_dk_rp = true, c_dk_dis = true,
  c_sha_totems = true, c_sha_totpos = "player", c_sha_weapon = true, c_sha_shield = true, c_sha_5sr = true,
  c_mag_5sr = true, c_mag_armor = true, c_mag_gem = true, c_mag_procs = true }

-- A Moderno texture in the chosen colour: the black theme, or the concept's blue.
function ns.ModernTex(name)
  if ns.db and ns.db.modernColor == "blue" then return name end
  return name .. "_black"
end

ns.DEFAULTS = DEFAULTS

-- Event bus: ns.On(event, fn) calls fn(event, ...) every time the event fires.
local listeners = {}
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event, ...)
  local list = listeners[event]
  if not list then return end
  for i = 1, #list do list[i](event, ...) end
end)

-- An event this client does not have is skipped: registering it raises an error, and that
-- stopped the rest of the calling file from loading (the C key code never ran).
function ns.On(event, fn)
  if not listeners[event] then
    listeners[event] = {}
    pcall(eventFrame.RegisterEvent, eventFrame, event)
  end
  table.insert(listeners[event], fn)
end

-- Protected frames cannot change in combat: run now, or queue until combat ends.
local queue = {}
function ns.RunOutOfCombat(fn)
  if InCombatLockdown() then
    table.insert(queue, fn)
  else
    fn()
  end
end

ns.On("PLAYER_REGEN_ENABLED", function()
  local pending = queue
  queue = {}
  for i = 1, #pending do pending[i]() end
end)

ns.On("ADDON_LOADED", function(_, name)
  if name ~= addonName then return end
  ObsidianUIDB = ObsidianUIDB or {}
  for k, v in pairs(DEFAULTS) do
    if ObsidianUIDB[k] == nil then ObsidianUIDB[k] = v end
  end
  ns.db = ObsidianUIDB
end)
