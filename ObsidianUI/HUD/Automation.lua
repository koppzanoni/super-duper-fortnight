local _, ns = ...

-- Automation: small chores the addon does for you. Sells junk and repairs at merchants (guild
-- money first), accepts group invites from friends and guild, declines duels, accepts a
-- resurrection from someone out of combat, releases the spirit in battlegrounds, skips cinematics
-- already seen, loots fast, hides the red error text in combat, and an AFK screen with the
-- camera turning around the character. Only game actions (no settings changed); Blizzard's
-- dialogs are just closed once answered.
local Automation = {}
ns.Automation = Automation

local W = ns.Widgets
local POPUP_DELAY = 0.1 -- the game shows its dialog on the same event: close it right after
local RES_POPUPS = { "RESURRECT", "RESURRECT_NO_SICKNESS", "RESURRECT_NO_TIMER" }

local function db() return ns.db or {} end
local function on(key) return db()[key] ~= false end
local function say(msg) print("|cffe8c46aObsidianUI|r: " .. msg) end
local function money(c) return GetMoneyString and GetMoneyString(c) or tostring(c) end
local inCombat = false

-- Merchants -------------------------------------------------------------------------------------
local function junkValue()
  local total = 0
  if not (C_Container and C_Container.GetContainerNumSlots and C_Item and C_Item.GetItemInfo) then return total end
  for bag = 0, 4 do
    for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.quality == 0 and not info.hasNoValue then
        local price = select(11, C_Item.GetItemInfo(info.itemID))
        total = total + (price or 0) * (info.stackCount or 1)
      end
    end
  end
  return total
end

local function sellJunk()
  local M = C_MerchantFrame
  if not (M and M.SellAllJunkItems) or (M.GetNumJunkItems and M.GetNumJunkItems() == 0) then return end
  if M.IsSellAllJunkEnabled and not M.IsSellAllJunkEnabled() then return end
  local value = junkValue()
  M.SellAllJunkItems()
  say(value > 0 and ("lixo vendido por " .. money(value) .. ".") or "lixo vendido.")
end

local function repair(mode)
  if not (CanMerchantRepair and CanMerchantRepair()) then return end
  local cost, can = GetRepairAllCost()
  if not can or not cost or cost <= 0 then return end
  if mode == "guild" and CanGuildBankRepair and CanGuildBankRepair() then
    local allowance = GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney() or 0
    if allowance == -1 or allowance >= cost then -- -1: no limit
      RepairAllItems(true)
      say("reparado por " .. money(cost) .. " (guilda).")
      return
    end
  end
  if GetMoney() >= cost then
    RepairAllItems()
    say("reparado por " .. money(cost) .. ".")
  end
end

ns.On("MERCHANT_SHOW", function()
  if on("autoJunk") then sellJunk() end
  local mode = db().autoRepair or "guild"
  if mode ~= "off" then repair(mode) end
end)

-- Social ----------------------------------------------------------------------------------------
local function closePopup(which, accepted)
  local d = StaticPopup_FindVisible and StaticPopup_FindVisible(which)
  if d and accepted then d.inviteAccepted = 1 end -- else the dialog declines as it hides
  if StaticPopup_Hide then StaticPopup_Hide(which) end
end

local function known(guid)
  if not guid then return false end
  if C_FriendList and C_FriendList.IsFriend and C_FriendList.IsFriend(guid) then return true end
  if IsGuildMember and IsGuildMember(guid) then return true end
  return C_BattleNet and C_BattleNet.GetGameAccountInfoByGUID and C_BattleNet.GetGameAccountInfoByGUID(guid) ~= nil or false
end

ns.On("PARTY_INVITE_REQUEST", function(_, _, _, _, _, _, _, guid)
  if not on("autoInvite") or not known(guid) then return end
  AcceptGroup()
  C_Timer.After(POPUP_DELAY, function() closePopup("PARTY_INVITE", true) end)
end)

ns.On("DUEL_REQUESTED", function()
  if db().noDuel ~= true then return end
  CancelDuel()
  C_Timer.After(POPUP_DELAY, function() closePopup("DUEL_REQUESTED") end)
end)

ns.On("RESURRECT_REQUEST", function(_, inviter)
  if not on("autoRes") or (inviter and UnitAffectingCombat(inviter)) then return end
  local wait = GetCorpseRecoveryDelay and GetCorpseRecoveryDelay() or 0
  C_Timer.After(math.max(0, wait) + POPUP_DELAY, function()
    AcceptResurrect()
    for _, which in ipairs(RES_POPUPS) do closePopup(which) end
  end)
end)

ns.On("PLAYER_DEAD", function()
  if not on("autoRelease") then return end
  local _, kind = IsInInstance()
  if kind ~= "pvp" then return end
  local options = C_DeathInfo and C_DeathInfo.GetSelfResurrectOptions and C_DeathInfo.GetSelfResurrectOptions()
  if options and #options > 0 then return end -- a soulstone or a class rez: the player chooses
  C_Timer.After(0.5, function()
    if UnitIsDead("player") and not UnitIsGhost("player") then RepopMe() end
  end)
end)

-- Cinematics ------------------------------------------------------------------------------------
-- Seen ones are account data (Core/Profiles.lua keeps them out of profiles).
local function seen(key)
  db().seenCinematics = db().seenCinematics or {}
  local was = db().seenCinematics[key]
  db().seenCinematics[key] = true
  return was
end

ns.On("CINEMATIC_START", function(_, canCancel)
  if not canCancel then return end -- vehicle "cinematics" are gameplay
  local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or 0
  local key = "c" .. tostring(map) .. ":" .. tostring(GetSubZoneText and GetSubZoneText() or "")
  if seen(key) and on("skipCine") and StopCinematic then StopCinematic() end
end)

ns.On("PLAYER_LOGIN", function()
  if not (MovieFrame and MovieFrame.PlayMovie) then return end
  hooksecurefunc(MovieFrame, "PlayMovie", function(self, id)
    if id and seen("m" .. tostring(id)) and on("skipCine") and self.FinishMovie then self:FinishMovie() end
  end)
end)

-- Loot ------------------------------------------------------------------------------------------
local lastLoot = 0
ns.On("LOOT_READY", function(_, auto)
  if not on("fastLoot") then return end
  local wanted = GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE")
  if not (auto or wanted) then return end
  local now = GetTime()
  if now - lastLoot < 0.3 and lastLoot > 0 then return end -- the event can come twice
  lastLoot = now
  for i = GetNumLootItems(), 1, -1 do
    local locked = select(6, GetLootSlotInfo(i))
    if not locked then LootSlot(i) end
  end
end)

-- Red errors in combat --------------------------------------------------------------------------
local errorsOff = false
local function errors(show)
  if not UIErrorsFrame then return end
  if show and errorsOff then
    UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
    errorsOff = false
  elseif not show and not errorsOff then
    UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
    errorsOff = true
  end
end

-- AFK screen ------------------------------------------------------------------------------------
local afkSince
local function clock(s)
  s = math.floor(s)
  return string.format("%02d:%02d", math.floor(s / 60), s % 60)
end

local function buildAFK()
  if Automation.afk then return Automation.afk end
  local f = CreateFrame("Frame", "ObsidianUIAFK", WorldFrame)
  f:SetAllPoints(WorldFrame)
  f:SetFrameStrata("FULLSCREEN")
  f:Hide()
  local band = CreateFrame("Frame", nil, f)
  band:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  band:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  band:SetHeight(150)
  W.Panel(band)
  local line = band:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(W.ACCENT[1], W.ACCENT[2], W.ACCENT[3], 0.8)
  line:SetPoint("TOPLEFT", band, "TOPLEFT", 0, 0)
  line:SetPoint("TOPRIGHT", band, "TOPRIGHT", 0, 0)
  line:SetHeight(2)
  local model = CreateFrame("PlayerModel", nil, band)
  model:SetSize(260, 320)
  model:SetPoint("BOTTOMLEFT", band, "BOTTOMLEFT", 40, 0)
  f.model = model
  local name = band:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  name:SetPoint("TOPLEFT", band, "TOPLEFT", 320, -30)
  ns.Look.SetFont(name, 30)
  local info = band:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  info:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -8)
  ns.Look.SetFont(info, 16)
  info:SetTextColor(W.TEXT[1], W.TEXT[2], W.TEXT[3])
  local away = band:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  away:SetPoint("RIGHT", band, "RIGHT", -50, 8)
  ns.Look.SetFont(away, 26)
  local hint = band:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hint:SetPoint("TOPRIGHT", away, "BOTTOMRIGHT", 0, -8)
  ns.Look.SetFont(hint, 13)
  hint:SetTextColor(W.DIM[1], W.DIM[2], W.DIM[3])
  hint:SetText("Aperte qualquer tecla para voltar")
  name:SetJustifyH("LEFT"); info:SetJustifyH("LEFT")
  f.name, f.info, f.away = name, info, away
  f:EnableKeyboard(true)
  f:SetScript("OnKeyDown", function() Automation.AFK(false, true) end)
  f:SetScript("OnUpdate", function()
    if afkSince then away:SetText("Ausente há " .. clock(GetTime() - afkSince)) end
  end)
  Automation.afk = f
  return f
end

local dismissed = false
-- Shows (or leaves) the AFK screen. byKey: the player pressed a key; stays off until the next AFK.
function Automation.AFK(show, byKey)
  local f = buildAFK()
  if show then
    if f:IsShown() then return end
    afkSince = GetTime()
    local r, g, b = 1, 1, 1
    local _, class = UnitClass("player")
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then r, g, b = c.r, c.g, c.b end
    f.name:SetText(UnitName("player") or "")
    f.name:SetTextColor(r, g, b)
    local guild = GetGuildInfo and GetGuildInfo("player")
    f.info:SetText(string.format("Nível %s %s%s", tostring(UnitLevel("player") or ""), (UnitClass("player")) or "",
      type(guild) == "string" and ("  ·  <" .. guild .. ">") or ""))
    f.model:SetUnit("player")
    if f.model.SetAnimation then f.model:SetAnimation(0) end
    f:SetScale(UIParent:GetEffectiveScale())
    UIParent:Hide()
    f:Show()
    MoveViewLeftStart(0.035)
  else
    if byKey then dismissed = true end
    if not f:IsShown() then return end
    MoveViewLeftStop()
    f:Hide()
    UIParent:Show()
  end
end

local function afkCheck()
  if not UnitIsAFK("player") then
    dismissed = false
    Automation.AFK(false)
    return
  end
  local _, kind = IsInInstance()
  if db().afkScreen == false or dismissed or inCombat or InCombatLockdown() or (kind and kind ~= "none") then return end
  Automation.AFK(true)
end

ns.On("PLAYER_LOGIN", buildAFK)
ns.On("PLAYER_FLAGS_CHANGED", function(_, unit) if unit == "player" then afkCheck() end end)

-- Combat ----------------------------------------------------------------------------------------
ns.On("PLAYER_REGEN_DISABLED", function()
  inCombat = true
  Automation.AFK(false) -- still allowed: lockdown starts after this event
  if db().hideErrors == true then errors(false) end
end)
ns.On("PLAYER_REGEN_ENABLED", function()
  inCombat = false
  errors(true)
end)

function Automation.Refresh()
  errors(not (inCombat and db().hideErrors == true))
  if db().afkScreen == false then Automation.AFK(false) end
end
