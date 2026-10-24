local addonName, ns = ...

ns.name = addonName

local DEFAULTS = { vbar1 = false, vbar2 = false, scale = 1.0, invScale = 1.0, extraCols = 0, showHotkeys = true,
  orbText = true, orbStyle = "a", capStyle = "classic",
  -- HUD style "Moderno": an option next to the stone HUD, which stays the default
  hudTheme = "obsidian", modernColor = "black", arcaneRing = true, modernRows = 2, modernCols = 12 }

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
