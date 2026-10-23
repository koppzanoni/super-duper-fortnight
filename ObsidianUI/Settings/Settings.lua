local _, ns = ...

-- "ObsidianUI" page in the game's Settings panel: vertical bars and HUD scale.
local category

local function register()
  if not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
  category = Settings.RegisterVerticalLayoutCategory("ObsidianUI")

  local function checkbox(key, label)
    local setting = Settings.RegisterAddOnSetting(category, "ObsidianUI_" .. key, key, ns.db, "boolean", label, false)
    setting:SetValueChangedCallback(function() ns.VerticalBars.Refresh() end)
    Settings.CreateCheckbox(category, setting, nil)
  end
  checkbox("vbar1", "Barra vertical direita 1")
  checkbox("vbar2", "Barra vertical direita 2")

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
