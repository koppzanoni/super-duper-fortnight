local _, ns = ...

-- Central action bar: 2 rows x 18 columns (spec 4.2). Built on Blizzard's ActionBarButtonTemplate
-- so cooldowns, charges, range and usability come from the game's own (secret-aware) code.
local D = ns.Data.HUD
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

local cols = {}
for _, x in ipairs(D.barCols) do cols[#cols + 1] = x end
for i = #D.barCols, 1, -1 do cols[#cols + 1] = ns.Layout.MirrorX(D.width, D.barCols[i], D.barSlot.w) end

for r = 1, 2 do
  for c = 1, 18 do
    local entry = ns.Data.ACTION_LAYOUT[r][c]
    local b = ActionBars.CreateButton(header, "ObsidianUIActionButton" .. ((r - 1) * 18 + c), entry.actionID, entry.binding)
    -- Column 1 stays next to column 2 when extra columns open between them (its art moves out).
    HUD.Place(b, cols[c], D.barRows[r], D.barSlot.w, D.barSlot.h, c == 1 or c == 18)
    if r == 1 and c <= 12 then header:SetFrameRef("paged" .. c, b) end
  end
end

-- Extra columns, in the HUD space a smaller HUD frees (setting "extraCols"): the game's action
-- bars 6 and 7. Column k holds rows 1-2 on each side; left uses buttons k, right 6 + k. Each
-- column lives in its own holder, hidden when unused, so Blizzard's grid can't show its buttons.
ActionBars.extra = {}
local holders = {}
for k = 1, ns.Layout.MAX_EXTRA do
  holders[k] = CreateFrame("Frame", nil, header)
  holders[k]:SetAllPoints(header)
  holders[k]:Hide()
  for r = 1, 2 do
    local bar = r == 1 and 5 or 6
    for _, index in ipairs({ k, ns.Layout.MAX_EXTRA + k }) do
      local b = ActionBars.CreateButton(holders[k], "ObsidianUIExtra" .. bar .. "Button" .. index,
        (r == 1 and 144 or 156) + index, "MULTIACTIONBAR" .. bar .. "BUTTON" .. index)
      local x = D.barCols[1] - k * ns.Layout.EXTRA_PITCH
      if index > ns.Layout.MAX_EXTRA then x = ns.Layout.MirrorX(D.width, x, D.barSlot.w) end
      HUD.Place(b, x, D.barRows[r], D.barSlot.w, D.barSlot.h, true)
      b.obEnabled, b.obColumn = false, k
      ActionBars.extra[#ActionBars.extra + 1] = b
    end
  end
end

function ActionBars.RefreshExtras()
  ns.RunOutOfCombat(function()
    local n = HUD.extra or 0
    for k, holder in ipairs(holders) do holder:SetShown(k <= n) end
    for _, b in ipairs(ActionBars.extra) do b.obEnabled = b.obColumn <= n end
    ActionBars.UpdateBindings()
  end)
end
table.insert(HUD.onResize, ActionBars.RefreshExtras)

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
