local _, ns = ...

-- "ObsidianUI" page in the game's Settings panel: bars, sizes and what the HUD shows.
local category

local function register()
  if not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
  local layout
  category, layout = Settings.RegisterVerticalLayoutCategory("ObsidianUI")

  local function checkbox(key, label, default, onChange, tooltip)
    local setting = Settings.RegisterAddOnSetting(category, "ObsidianUI_" .. key, key, ns.db, "boolean", label, default)
    setting:SetValueChangedCallback(onChange)
    Settings.CreateCheckbox(category, setting, tooltip)
  end
  local function slider(key, label, default, min, max, step, fmt, onChange, tooltip)
    local setting = Settings.RegisterAddOnSetting(category, "ObsidianUI_" .. key, key, ns.db, "number", label, default)
    setting:SetValueChangedCallback(onChange)
    local options = Settings.CreateSliderOptions(min, max, step)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v) return string.format(fmt, v) end)
    Settings.CreateSlider(category, setting, options, tooltip)
  end
  local function relayoutHUD() ns.RunOutOfCombat(ns.HUD.Layout) end

  checkbox("vbar1", "Barra vertical direita 1", false, function() ns.VerticalBars.Refresh() end)
  checkbox("vbar2", "Barra vertical direita 2", false, function() ns.VerticalBars.Refresh() end)
  checkbox("showHotkeys", "Mostrar teclas de atalho nos botões", true, function() ns.ActionBars.UpdateBindings() end)
  if CreateSettingsButtonInitializer and layout then
    layout:AddInitializer(CreateSettingsButtonInitializer("Posição e tamanho dos elementos", "Modo de edição",
      function() ns.EditMode.Start() end,
      "Arraste cada elemento da HUD, mude o tamanho com a roda do mouse e ajuste com as setas. Esc sai.", true))
    layout:AddInitializer(CreateSettingsButtonInitializer("Teclas de atalho da barra", "Definir teclas",
      function() ns.KeybindMode.Start() end,
      "Feche esta janela, passe o mouse num botão da barra de ações e aperte a tecla. Backspace limpa, Esc sai.", true))
  end
  -- The colour builds the textures at login: it applies after a reload, offered right away.
  local function choice(key, label, default, options, tooltip, onChange)
    local setting = Settings.RegisterAddOnSetting(category, "ObsidianUI_" .. key, key, ns.db, "string", label, default)
    setting:SetValueChangedCallback(onChange)
    Settings.CreateDropdown(category, setting, function()
      local container = Settings.CreateControlTextContainer()
      for _, o in ipairs(options) do container:Add(o[1], o[2]) end
      return container:GetData()
    end, tooltip)
  end
  local function askReload() StaticPopup_Show("OBSIDIANUI_RELOAD") end
  choice("modernColor", "Cor da HUD", "black", { { "black", "Preto translúcido" }, { "blue", "Azul" } }, nil, askReload)
  checkbox("arcaneRing", "Anel arcano no retrato", true, function()
    local player = ns.UnitFrames and ns.UnitFrames.frames.player
    if player and player.arcane then player.arcane:SetShown(ns.db.arcaneRing ~= false) end
  end)
  slider("modernRows", "Linhas da barra de ações", 2, 1, 4, 1, "%d", relayoutHUD,
    "Linhas x colunas: até 36 botões (barra principal, inferior direita e inferior esquerda).")
  slider("modernCols", "Colunas da barra de ações", 12, 4, 18, 1, "%d", relayoutHUD)

  local scale = Settings.RegisterAddOnSetting(category, "ObsidianUI_scale", "scale", ns.db, "number", "Escala do HUD", 1.0)
  scale:SetValueChangedCallback(function() ns.RunOutOfCombat(ns.HUD.Layout) end)
  local options = Settings.CreateSliderOptions(0.6, 1.4, 0.05)
  options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v) return string.format("%.2f", v) end)
  Settings.CreateSlider(category, scale, options, "Tamanho do HUD inferior.")

  local inv = Settings.RegisterAddOnSetting(category, "ObsidianUI_invScale", "invScale", ns.db, "number",
    "Tamanho do inventário", 1.0)
  inv:SetValueChangedCallback(function()
    if ns.Inventory then ns.RunOutOfCombat(ns.Inventory.Layout) end
  end)
  local invOptions = Settings.CreateSliderOptions(0.8, 1.3, 0.05)
  invOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v) return string.format("%.2f", v) end)
  Settings.CreateSlider(category, inv, invOptions, "Acima de 1, a janela pode cobrir parte do HUD.")

  Settings.RegisterAddOnCategory(category)
end

-- Changing the HUD colour needs a reload: asked, never forced. (Only a key is added:
-- assigning the global StaticPopupDialogs itself would taint Blizzard's popups.)
StaticPopupDialogs["OBSIDIANUI_RELOAD"] = {
  text = "ObsidianUI: recarregar a interface agora para aplicar a nova cor?",
  button1 = "Recarregar", button2 = "Depois",
  OnAccept = function() ReloadUI() end,
  timeout = 0, whileDead = true, hideOnEscape = true,
}

ns.On("PLAYER_LOGIN", register)

function ns.OpenSettings()
  if category and Settings.OpenToCategory then Settings.OpenToCategory(category:GetID()) end
end
