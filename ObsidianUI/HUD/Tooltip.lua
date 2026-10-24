local _, ns = ...

-- Tooltips in the Moderno look: a black translucent panel with a thin rim in place of the game's
-- border (its NineSlice turns invisible, also after the game restyles it), the rim in the item's
-- quality colour or the player's class colour, the player's name in their class colour, who they
-- are targeting on an extra line, and the health bar thin on a black backing. Optionally at the
-- cursor or above the info bar, and hidden over the world during combat. Values the game keeps
-- from addons in combat are skipped (pcall).
local Tooltip = {}
ns.Tooltip = Tooltip

local W = ns.Widgets
local TIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "EmbeddedItemTooltip" }

local function db() return ns.db or {} end
local function on(key) return db()[key] ~= false end
local function global(name) return rawget(_G, name) end

local function setRim(tip, r, g, b, a)
  if not tip.obRim then return end
  W.SetRim(tip, r, g, b, a or 1)
end
local function neutralRim(tip) setRim(tip, W.Rim()) end

local function hideBorder(tip)
  local nine = rawget(tip, "NineSlice")
  if nine then nine:SetAlpha(0) end
end

local function skinBar(tip)
  local bar = rawget(tip, "StatusBar") or global((tip:GetName() or "") .. "StatusBar")
  if not bar or bar.backing then return end
  bar:SetStatusBarTexture(ns.Look.BarTexture())
  bar:SetHeight(5)
  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", tip, "BOTTOMLEFT", 1, -3)
  bar:SetPoint("TOPRIGHT", tip, "BOTTOMRIGHT", -1, -3)
  bar.backing = bar:CreateTexture(nil, "BACKGROUND")
  bar.backing:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
  bar.backing:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
  bar.backing:SetColorTexture(0, 0, 0, 0.8)
end

local function skin(tip)
  if not tip or tip.obFill then return end
  hideBorder(tip)
  tip.obFill = W.Panel(tip, 0.9)
  tip.obRim = tip.rim
  skinBar(tip)
  -- back to the neutral rim whenever the tooltip is emptied
  if tip.HookScript then
    tip:HookScript("OnTooltipCleared", neutralRim)
    tip:HookScript("OnShow", function(self)
      -- over the world in combat (owner: the world or UIParent), when asked to hide it
      if db().tipCombat == false and InCombatLockdown() then
        local owner = self.GetOwner and self:GetOwner()
        if owner == global("WorldFrame") or owner == UIParent then self:Hide() end
      end
    end)
  end
end

-- Items: the rim in the item's quality colour (from green up).
local function onItem(tip)
  if not tip.obRim then return end
  local ok, quality = pcall(function()
    local _, link = tip:GetItem()
    return link and C_Item.GetItemQualityByID(link)
  end)
  local c = ok and type(quality) == "number" and quality > 1 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
  if c then setRim(tip, c.r, c.g, c.b, 0.9) else neutralRim(tip) end
end

-- Players: name and rim in their class colour; anyone with a target gets an "Alvo:" line.
local function onUnit(tip)
  if not tip.obRim then return end
  pcall(function()
    local _, unit = tip:GetUnit()
    if not unit then return end
    if UnitIsPlayer(unit) then
      local _, class = UnitClass(unit)
      local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
      if c then
        local name = global((tip:GetName() or "") .. "TextLeft1")
        if name then name:SetTextColor(c.r, c.g, c.b) end
        setRim(tip, c.r, c.g, c.b, 0.9)
      end
    else
      neutralRim(tip)
    end
    local target = unit .. "target"
    if UnitExists(target) then
      local who = UnitName(target)
      if who then tip:AddLine("Alvo: " .. who, W.TEXT[1], W.TEXT[2], W.TEXT[3]) end
    end
  end)
end

-- Where tooltips without their own place appear: the game's spot, the cursor, or above the info bar.
local function anchor(tip, parent)
  local where = db().tipAnchor or "default"
  if where == "cursor" then
    tip:SetOwner(parent, "ANCHOR_CURSOR_RIGHT", 16, -8)
  elseif where == "hud" then
    tip:ClearAllPoints()
    local info = ns.InfoBar and ns.InfoBar.frame
    if info and info:IsShown() then tip:SetPoint("BOTTOMRIGHT", info, "TOPRIGHT", 0, 8)
    else tip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, ns.HUD.h or 200) end
  end
end

function Tooltip.Apply()
  if not on("tip_on") then return end
  for _, name in ipairs(TIPS) do skin(global(name)) end
end

ns.On("PLAYER_LOGIN", function()
  if not on("tip_on") then return end
  Tooltip.Apply()
  if type(global("SharedTooltip_SetBackdropStyle")) == "function" then
    hooksecurefunc("SharedTooltip_SetBackdropStyle", function(tip) if tip and tip.obFill then hideBorder(tip) end end)
  end
  if type(global("GameTooltip_SetDefaultAnchor")) == "function" then
    hooksecurefunc("GameTooltip_SetDefaultAnchor", anchor)
  end
  local processor, types = global("TooltipDataProcessor"), Enum and Enum.TooltipDataType
  if processor and types then
    processor.AddTooltipPostCall(types.Item, onItem)
    processor.AddTooltipPostCall(types.Unit, onUnit)
  end
end)
