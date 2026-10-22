local _, ns = ...

-- Player buffs (top row) and debuffs (row below), top center of the screen (spec 4.8).
local M = ns.MediaManifest
local BRONZE, RED = { 0.54, 0.43, 0.23 }, { 0.77, 0.15, 0.11 }

local function header(filter)
  local h = CreateFrame("Frame", "ObsidianUIAuras" .. filter, UIParent, "SecureAuraHeaderTemplate")
  h:SetAttribute("unit", "player")
  h:SetAttribute("filter", filter)
  h:SetAttribute("template", "ObsidianUIAuraTemplate")
  h:SetAttribute("point", "TOP")
  h:SetAttribute("xOffset", 30)
  h:SetAttribute("yOffset", 0)
  h:SetAttribute("wrapAfter", 16)
  h:SetAttribute("wrapYOffset", -42)
  h:SetAttribute("maxWraps", 2)
  h:SetAttribute("sortMethod", "TIME")
  h:SetAttribute("sortDirection", "-")
  h:SetAttribute("minWidth", 30)
  h:SetAttribute("minHeight", 30)
  h.filter = filter
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
  for i = 1, 40 do
    local child = h:GetAttribute("child" .. i)
    if not child then break end
    if child:IsShown() then updateChild(child, h.filter) end
  end
end

local function layout()
  local _, H = UIParent:GetSize()
  local scale = H / 900
  buffs:SetScale(scale)
  debuffs:SetScale(scale)
  buffs:ClearAllPoints()
  buffs:SetPoint("TOP", UIParent, "TOP", -7.5 * 30 / 2, -0.025 * H / scale)
  debuffs:ClearAllPoints()
  debuffs:SetPoint("TOP", UIParent, "TOP", -7.5 * 30 / 2, -0.095 * H / scale)
end

ns.On("PLAYER_LOGIN", function()
  ns.RunOutOfCombat(function()
    layout()
    buffs:Show(); debuffs:Show()
    updateHeader(buffs); updateHeader(debuffs)
  end)
end)
ns.On("UNIT_AURA", function(_, unit)
  if unit == "player" then updateHeader(buffs); updateHeader(debuffs) end
end)
table.insert(ns.HUD.onResize, function() ns.RunOutOfCombat(layout) end)
