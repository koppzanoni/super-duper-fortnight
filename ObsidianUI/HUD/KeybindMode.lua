local _, ns = ...

-- Key binding mode: while on, hover one of the addon's action buttons and press a key (with
-- any of Shift/Ctrl/Alt) to bind it to that button's command; Backspace/Delete clears the
-- button's keys, Esc leaves. The game's quick keybind mode does not reach these buttons.
-- Started from the settings page or /obui atalhos; combat ends it.
local KeybindMode = { active = false }
ns.KeybindMode = KeybindMode

local MODIFIER_KEYS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
  UNKNOWN = true }
local CLEAR_KEYS = { BACKSPACE = true, DELETE = true }

local hovered

-- Banner across the top of the screen while the mode is on.
local banner = CreateFrame("Frame", nil, UIParent)
banner:SetFrameStrata("FULLSCREEN_DIALOG")
banner:SetPoint("TOP", UIParent, "TOP", 0, -120)
banner:SetSize(620, 64)
banner:Hide()
local bannerBg = banner:CreateTexture(nil, "BACKGROUND")
bannerBg:SetAllPoints(banner)
bannerBg:SetColorTexture(0, 0, 0, 0.75)
local bannerTitle = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
bannerTitle:SetPoint("TOP", banner, "TOP", 0, -10)
bannerTitle:SetText("Modo de atalhos")
bannerTitle:SetTextColor(0.91, 0.77, 0.42)
local bannerText = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
bannerText:SetPoint("TOP", bannerTitle, "BOTTOM", 0, -6)
bannerText:SetText("Passe o mouse num botão da barra e aperte a tecla. Backspace limpa. Esc sai.")

-- Captures the keyboard only while a button is hovered (and the settings window is closed);
-- every other key goes on to the game.
local catcher = CreateFrame("Frame", nil, UIParent)
catcher:SetFrameStrata("FULLSCREEN_DIALOG")
catcher:EnableKeyboard(false)
KeybindMode.catcher = catcher

local function settingsOpen()
  return type(SettingsPanel) == "table" and SettingsPanel.IsShown and SettingsPanel:IsShown()
end

local function fullKey(key)
  local prefix = ""
  if IsAltKeyDown() then prefix = prefix .. "ALT-" end
  if IsControlKeyDown() then prefix = prefix .. "CTRL-" end
  if IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
  return prefix .. key
end

local function showTip(b)
  if not (GameTooltip and b) then return end
  GameTooltip:SetOwner(b, "ANCHOR_TOP")
  local key1, key2 = GetBindingKey(b.binding)
  local keys = key1 and (GetBindingText(key1) .. (key2 and (", " .. GetBindingText(key2)) or "")) or "nenhuma"
  GameTooltip:SetText("Tecla: " .. keys)
  GameTooltip:Show()
end

local function propagate(on)
  if not InCombatLockdown() then catcher:SetPropagateKeyboardInput(on) end
end

catcher:SetScript("OnKeyDown", function(_, key)
  if not KeybindMode.active or settingsOpen() then propagate(true); return end
  if key == "ESCAPE" then
    propagate(false)
    KeybindMode.Stop()
    return
  end
  if not hovered or MODIFIER_KEYS[key] then propagate(true); return end
  propagate(false)
  if CLEAR_KEYS[key] then
    for _, k in ipairs({ GetBindingKey(hovered.binding) }) do SetBinding(k) end
  else
    SetBinding(fullKey(key), hovered.binding)
  end
  SaveBindings(GetCurrentBindingSet())
  showTip(hovered)
end)

local hooked = {}
local function hookButtons()
  for _, b in ipairs(ns.ActionBars and ns.ActionBars.buttons or {}) do
    if not hooked[b] and b.binding then
      hooked[b] = true
      b:HookScript("OnEnter", function(self)
        if not KeybindMode.active then return end
        hovered = self
        showTip(self)
      end)
      b:HookScript("OnLeave", function(self) if hovered == self then hovered = nil end end)
    end
  end
end
ns.On("PLAYER_LOGIN", hookButtons)

function KeybindMode.Start()
  if InCombatLockdown() then return end
  hookButtons()
  KeybindMode.active = true
  hovered = nil
  banner:Show()
  catcher:EnableKeyboard(true)
  catcher:SetPropagateKeyboardInput(true)
end

function KeybindMode.Stop()
  KeybindMode.active = false
  hovered = nil
  banner:Hide()
  if not InCombatLockdown() then catcher:EnableKeyboard(false) end
  if GameTooltip then GameTooltip:Hide() end
end

ns.On("PLAYER_REGEN_DISABLED", KeybindMode.Stop)
