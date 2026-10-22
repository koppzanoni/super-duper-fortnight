local _, ns = ...

-- Central action bar: 2 rows x 18 columns (spec 4.2). Built on Blizzard's ActionBarButtonTemplate
-- so cooldowns, charges, range and usability come from the game's own (secret-aware) code.
local D = ns.Data.HUD
local HUD = ns.HUD
local ActionBars = { buttons = {} }
ns.ActionBars = ActionBars

local bindingOwner = CreateFrame("Frame")

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
  b.action = actionID
  b.binding = binding
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:HookScript("OnAttributeChanged", function(self, attr, value)
    if attr == "action" then
      self.action = value
      if self.UpdateAction then self:UpdateAction(true) end
    end
  end)
  skin(b)
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
    HUD.Place(b, cols[c], D.barRows[r], D.barSlot.w, D.barSlot.h)
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
      local hotkey = b.HotKey or _G[b:GetName() .. "HotKey"]
      if hotkey then hotkey:SetText(key1 and GetBindingText(key1, true) or "") end
    end
  end)
end

ns.On("PLAYER_LOGIN", function()
  ns.RunOutOfCombat(function()
    RegisterStateDriver(header, "page", ns.Data.PagingDriver())
  end)
  ActionBars.UpdateBindings()
end)
ns.On("UPDATE_BINDINGS", ActionBars.UpdateBindings)
