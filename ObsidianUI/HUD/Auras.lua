local _, ns = ...

-- Player buffs (top row) and debuffs (row below), top center of the screen (spec 4.8).
local M = ns.MediaManifest
local BRONZE, RED = { 0.54, 0.43, 0.23 }, { 0.77, 0.15, 0.11 }
local STEP, WRAP = 30, 16

local function header(filter)
  local h = CreateFrame("Frame", "ObsidianUIAuras" .. filter, UIParent, "SecureAuraHeaderTemplate")
  h:SetAttribute("unit", "player")
  h:SetAttribute("filter", filter)
  h:SetAttribute("template", "ObsidianUIAuraTemplate")
  h:SetAttribute("point", "TOP")
  h:SetAttribute("xOffset", STEP)
  h:SetAttribute("yOffset", 0)
  h:SetAttribute("wrapAfter", WRAP)
  h:SetAttribute("wrapYOffset", -42)
  h:SetAttribute("maxWraps", 2)
  h:SetAttribute("sortMethod", "TIME")
  h:SetAttribute("sortDirection", "-")
  h:SetAttribute("minWidth", 30)
  h:SetAttribute("minHeight", 30)
  h.filter = filter
  h.obCount = 0
  return h
end

local buffs = header("HELPFUL")
local debuffs = header("HARMFUL")

local function style(child, isDebuff)
  if child.obStyled then return end
  child.obStyled = true
  child.icon = child:CreateTexture(nil, "ARTWORK")
  child.icon:SetAllPoints(child)
  child.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  child.border = child:CreateTexture(nil, "OVERLAY")
  child.border:SetAllPoints(child)
  child.border:SetTexture(M.aura_border.file)
  local c = isDebuff and RED or BRONZE
  child.border:SetVertexColor(c[1], c[2], c[3])
  child.cd = CreateFrame("Cooldown", nil, child, "CooldownFrameTemplate")
  child.cd:SetAllPoints(child)
  child.cd:SetReverse(true)
  child.count = child:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  child.count:SetPoint("BOTTOMRIGHT", 1, 0)
  child:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetUnitAura("player", self:GetID() > 0 and self:GetID() or self:GetAttribute("index"), self:GetParent().filter)
  end)
  child:SetScript("OnLeave", GameTooltip_Hide)
end

local function updateChild(child, filter)
  local index = child:GetAttribute("index")
  if not index then return end
  style(child, filter == "HARMFUL")
  local aura = C_UnitAuras.GetAuraDataByIndex("player", index, filter)
  if not aura then return end
  child.icon:SetTexture(aura.icon)
  if filter == "HARMFUL" then
    local ok, r, g, b = pcall(ns.Data.DebuffColor, aura.dispelName)
    if ok then child.border:SetVertexColor(r, g, b) else child.border:SetVertexColor(RED[1], RED[2], RED[3]) end
  end
  if not pcall(function() child.count:SetText(aura.applications > 1 and aura.applications or "") end) then
    child.count:SetText("")
  end
  local ok = false
  if C_UnitAuras.GetAuraDuration and child.cd.SetCooldownFromDurationObject then
    local dur = C_UnitAuras.GetAuraDuration("player", aura.auraInstanceID)
    ok = dur ~= nil and pcall(child.cd.SetCooldownFromDurationObject, child.cd, dur)
  end
  if not ok then
    if not pcall(function()
      if aura.duration > 0 then child.cd:SetCooldown(aura.expirationTime - aura.duration, aura.duration) else child.cd:Clear() end
    end) then child.cd:Clear() end
  end
end

local function updateHeader(h)
  local shown = 0
  for i = 1, 40 do
    local child = h:GetAttribute("child" .. i)
    if not child then break end
    if child:IsShown() then
      shown = shown + 1
      updateChild(child, h.filter)
    end
  end
  h.obCount = shown
end

-- Rows are centered on the screen for the current number of auras. Secure headers cannot
-- move in combat: they keep their spot and re-center when combat ends.
local function layout()
  if InCombatLockdown() then return end
  local _, H = UIParent:GetSize()
  local scale = H / 900
  for h, y in pairs({ [buffs] = 0.025, [debuffs] = 0.095 }) do
    h:SetScale(scale)
    h:ClearAllPoints()
    h:SetPoint("TOP", UIParent, "TOP", ns.Data.AuraRowOffset(h.obCount, WRAP, STEP), -y * H / scale)
  end
end

local function updateAll()
  updateHeader(buffs); updateHeader(debuffs)
  layout()
end

ns.On("PLAYER_LOGIN", function()
  ns.RunOutOfCombat(function()
    buffs:Show(); debuffs:Show()
    updateAll()
  end)
end)
ns.On("UNIT_AURA", function(_, unit)
  -- Let SecureAuraHeader reassign child indexes first, then read them.
  if unit == "player" then C_Timer.After(0, updateAll) end
end)
ns.On("PLAYER_REGEN_ENABLED", layout)
table.insert(ns.HUD.onResize, function() ns.RunOutOfCombat(layout) end)
