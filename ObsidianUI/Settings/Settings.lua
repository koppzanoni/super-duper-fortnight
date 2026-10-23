local _, ns = ...

-- "ObsidianUI" page in the game's Settings panel: bars, sizes and what the HUD shows.
local category

local function register()
  if not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
  category = Settings.RegisterVerticalLayoutCategory("ObsidianUI")

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
  slider("extraCols", "Colunas extras na barra de ações", 0, 0, ns.Layout.MAX_EXTRA, 1, "%d", relayoutHUD,
    "Cada coluna adiciona 4 botões (barras de ação 6 e 7 do jogo). Só cabem se houver espaço livre ao lado da barra: diminua a Escala do HUD para liberar mais.")
  checkbox("showHotkeys", "Mostrar teclas de atalho nos botões", true, function() ns.ActionBars.UpdateBindings() end)
  checkbox("orbText", "Mostrar números nos orbes", true, function() ns.Orbs.ApplyTextVisibility() end)

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

ns.On("PLAYER_LOGIN", register)

function ns.OpenSettings()
  if category and Settings.OpenToCategory then Settings.OpenToCategory(category:GetID()) end
end
