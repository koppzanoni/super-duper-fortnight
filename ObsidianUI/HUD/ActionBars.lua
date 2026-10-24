local _, ns = ...

-- Central action bar: a grid of up to 36 buttons (spec 2026-10-23-hud-moderno). Built on Blizzard's
-- ActionBarButtonTemplate so cooldowns, charges, range and usability come from the game's own
-- (secret-aware) code.
local HUD = ns.HUD
local ActionBars = { buttons = {} }
ns.ActionBars = ActionBars

local bindingOwner = CreateFrame("Frame")

-- Our key text on the button. Blizzard's UpdateHotkeys finds no binding for our buttons and
-- blanks and hides it, so this runs after it too. Optional (setting "showHotkeys").
local function showHotkey(b)
  local hotkey = b.HotKey or _G[b:GetName() .. "HotKey"]
  if not hotkey then return end
  local text = b.obHotkey or ""
  hotkey:SetText(text)
  hotkey:SetShown(text ~= "" and not (ns.db and ns.db.showHotkeys == false))
end

local function skin(button)
  local name = button:GetName()
  local icon = button.icon or _G[name .. "Icon"]
  if icon then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
  local normal = button:GetNormalTexture()
  if normal then normal:SetAlpha(0) end
  for _, key in ipairs({ "SlotBackground", "SlotArt", "Border", "IconMask" }) do
    local region = button[key]
    if region and region.SetAlpha then region:SetAlpha(0) end
  end
  local hotkey = button.HotKey or _G[name .. "HotKey"]
  if hotkey then
    hotkey:ClearAllPoints()
    hotkey:SetPoint("TOPRIGHT", -2, -2)
    hotkey:SetTextColor(0.91, 0.86, 0.75)
  end
  -- Blizzard's template pieces have fixed sizes and offsets for its own 45px buttons, and a mask
  -- that crops the icon: on our buttons they were offset and bigger than the slot. Fit them all
  -- to the icon.
  if icon then
    if button.IconMask and icon.RemoveMaskTexture then icon:RemoveMaskTexture(button.IconMask) end
    local pieces = { button:GetHighlightTexture() or false, button:GetPushedTexture() or false,
      button.GetCheckedTexture and button:GetCheckedTexture() or false, button.cooldown or _G[name .. "Cooldown"] or false,
      button.Flash or _G[name .. "Flash"] or false, button.NewActionTexture or false, button.SpellHighlightTexture or false }
    for _, region in ipairs(pieces) do
      if region then
        region:ClearAllPoints()
        region:SetAllPoints(icon)
      end
    end
  end
  local count = button.Count or _G[name .. "Count"]
  local macroName = button.Name or _G[name .. "Name"]
  if macroName then macroName:SetAlpha(0) end
  -- Icon and texts follow the button size: at a small HUD scale the default fonts made the key
  -- text and the stack count overlap. The icon is square, centered in the (taller) slot.
  button:HookScript("OnSizeChanged", function(_, w, h)
    local s = math.min(w, h)
    if icon then
      icon:ClearAllPoints()
      icon:SetPoint("CENTER")
      icon:SetSize(s, s)
    end
    for region, frac in pairs({ [hotkey or false] = 0.30, [count or false] = 0.34 }) do
      if region then
        local path, _, flags = region:GetFont()
        if path then region:SetFont(path, math.max(8, math.floor(s * frac)), flags or "OUTLINE") end
      end
    end
  end)
end

function ActionBars.CreateButton(parent, name, actionID, binding)
  local b = CreateFrame("CheckButton", name, parent, "ActionBarButtonTemplate")
  b:SetAttribute("type", "action")
  b:SetAttribute("action", actionID)
  b.binding = binding
  b:RegisterForClicks("AnyUp", "AnyDown")
  -- Blizzard's UpdateAction touches protected attributes: only call it out of combat.
  -- In combat (form shift, vehicle) refresh the icon ourselves and finish after combat.
  b:HookScript("OnAttributeChanged", function(self, attr, value)
    if attr ~= "action" or not self.UpdateAction then return end
    if InCombatLockdown() then
      local icon = self.icon or _G[self:GetName() .. "Icon"]
      if icon then icon:SetTexture(GetActionTexture(value)) end
      ns.RunOutOfCombat(function() self:UpdateAction(true) end)
    else
      self:UpdateAction(true)
    end
  end)
  skin(b)
  if type(b.UpdateHotkeys) == "function" then hooksecurefunc(b, "UpdateHotkeys", showHotkey) end
  ActionBars.buttons[#ActionBars.buttons + 1] = b
  return b
end

-- Secure header pages the top-left 12 buttons (vehicles, override, possess, stances, forms).
local header = CreateFrame("Frame", "ObsidianUIBarHeader", HUD.over, "SecureHandlerStateTemplate")
header:SetAllPoints(HUD.over)
header:SetAttribute("_onstate-page", [[
  local page = tonumber(newstate) or 1
  for i = 1, 12 do
    local b = self:GetFrameRef("paged" .. i)
    b:SetAttribute("action", (page - 1) * 12 + i)
  end
]])

-- 36 buttons: main bar, bottom left and bottom right bars (Data.ACTION_LAYOUT); the Moderno grid
-- below places them.
for r = 1, 2 do
  for c = 1, 18 do
    local entry = ns.Data.ACTION_LAYOUT[r][c]
    local b = ActionBars.CreateButton(header, "ObsidianUIActionButton" .. ((r - 1) * 18 + c), entry.actionID, entry.binding)
    if r == 1 and c <= 12 then header:SetFrameRef("paged" .. c, b) end
  end
end

-- Route the standard key bindings (1-0, -, =, multibar bindings) to our buttons.
function ActionBars.UpdateBindings()
  ns.RunOutOfCombat(function()
    ClearOverrideBindings(bindingOwner)
    for _, b in ipairs(ActionBars.buttons) do
      local key1, key2 = GetBindingKey(b.binding)
      for _, key in ipairs({ key1, key2 }) do
        if key and b.obEnabled ~= false then
          SetOverrideBindingClick(bindingOwner, false, key, b:GetName(), "LeftButton")
        end
      end
      b.obHotkey = key1 and GetBindingText(key1, true) or ""
      showHotkey(b)
    end
  end)
end

-- Moderno: the bar is a grid of rows x columns of slot frames with no background, the key numbers
-- above the first row with small diamonds between them. Buttons fill it in reading order: main
-- bar, bottom right bar, bottom left bar. Buttons past the grid wait in a hidden frame (Blizzard's
-- grid could show a merely hidden button) and lose their key bindings.
local MODERN_ORDER = {}
for c = 1, 12 do MODERN_ORDER[#MODERN_ORDER + 1] = c end
for c = 1, 12 do MODERN_ORDER[#MODERN_ORDER + 1] = 18 + c end
for c = 13, 18 do MODERN_ORDER[#MODERN_ORDER + 1] = c end
for c = 13, 18 do MODERN_ORDER[#MODERN_ORDER + 1] = 18 + c end
ActionBars.MODERN_ORDER = MODERN_ORDER

local spare = CreateFrame("Frame", nil, header)
spare:Hide()
local modernFrame = CreateFrame("Frame", "ObsidianUIModernBar", UIParent)
ActionBars.modernFrame = modernFrame
local diamonds = {}

-- The slot frame around a button's icon (also used by the vertical bars).
function ActionBars.ModernSlot(b, inset)
  if not b.obModernSlot then b.obModernSlot = b:CreateTexture(nil, "BACKGROUND", nil, -8) end
  local t = b.obModernSlot
  t:ClearAllPoints()
  t:SetPoint("TOPLEFT", b, "TOPLEFT", -inset, inset)
  t:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", inset, -inset)
  ns.Media.Apply(t, ns.ModernTex("mod_slot"))
  t:Show()
end

local function diamond(i)
  if not diamonds[i] then
    local t = modernFrame:CreateTexture(nil, "ARTWORK")
    if t.SetRotation then t:SetRotation(math.pi / 4) end
    diamonds[i] = t
  end
  return diamonds[i]
end

function ActionBars.LayoutModern()
  local g = HUD.modernBar
  modernFrame:SetSize(g.width, g.height)
  ns.Movers.Register("bar", "Barra de ações", modernFrame, function(f)
    f:ClearAllPoints()
    f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, g.bottom)
  end, { ownScale = true })
  ns.Movers.Place("bar")
  local inset = g.slot * ns.Data.MODERN_SLOT.inset / ns.Data.MODERN_SLOT.size
  local n = g.rows * g.cols
  for i, index in ipairs(MODERN_ORDER) do
    local b = ActionBars.buttons[index]
    if i <= n then
      local r, c = math.floor((i - 1) / g.cols), (i - 1) % g.cols
      b:SetParent(header)
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", modernFrame, "TOPLEFT", c * (g.slot + g.gap) + inset, -(g.numbers + r * (g.slot + g.gap) + inset))
      b:SetSize(g.slot - 2 * inset, g.slot - 2 * inset)
      b.obEnabled = true
      ActionBars.ModernSlot(b, inset)
      local hotkey = b.HotKey or _G[b:GetName() .. "HotKey"]
      if hotkey and r == 0 then
        hotkey:ClearAllPoints()
        hotkey:SetPoint("BOTTOM", b, "TOP", 0, inset + 2 * g.s)
        if hotkey.SetJustifyH then hotkey:SetJustifyH("CENTER") end
      end
      b:Show()
    else
      b:SetParent(spare)
      b.obEnabled = false
    end
  end
  local blue = ns.db and ns.db.modernColor == "blue"
  for c = 1, math.max(g.cols - 1, #diamonds) do
    local t = diamond(c)
    if c < g.cols then
      t:SetColorTexture(blue and 0.24 or 0.54, blue and 0.63 or 0.56, blue and 0.78 or 0.59, 1)
      t:SetSize(5 * g.s, 5 * g.s)
      t:ClearAllPoints()
      t:SetPoint("CENTER", modernFrame, "TOPLEFT", c * (g.slot + g.gap) - g.gap / 2, -g.numbers / 2)
      t:Show()
    else
      t:Hide()
    end
  end
  ActionBars.UpdateBindings()
end
table.insert(HUD.onResize, function() ns.RunOutOfCombat(ActionBars.LayoutModern) end)

ns.On("PLAYER_LOGIN", function()
  ns.RunOutOfCombat(function()
    -- Register every button's action slot with the game once (the template starts on action 1).
    for _, b in ipairs(ActionBars.buttons) do
      if b.UpdateAction then b:UpdateAction(true) end
    end
    RegisterStateDriver(header, "page", ns.Data.PagingDriver())
  end)
  ActionBars.UpdateBindings()
end)
ns.On("UPDATE_BINDINGS", ActionBars.UpdateBindings)
