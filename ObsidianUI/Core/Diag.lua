local _, ns = ...

-- /obui diag: facts about this client that the rest of the addon depends on.
local MEDIA = "Interface\\AddOns\\ObsidianUI\\Media\\"

local function out(...) print("|cffe8c46aObsidianUI|r", ...) end

local function secretInfo(label, value)
  if issecretvalue == nil then
    out(label, "issecretvalue: (função não existe)")
  else
    out(label, "secret =", tostring(issecretvalue(value)))
  end
end

local function frameCandidates()
  local lists = (ns.Data and ns.Data.FRAME_CANDIDATES) or {}
  for key, names in pairs(lists) do
    local _, found = ns.Resolve.First(names)
    out("frame", key, "=", found or "|cffff4040NENHUM|r")
  end
end

local testFrame
local function showTextures()
  if not testFrame then
    testFrame = CreateFrame("Frame", nil, UIParent)
    testFrame:SetSize(150, 70)
    testFrame:SetPoint("CENTER")
    local png = testFrame:CreateTexture(nil, "ARTWORK")
    png:SetSize(64, 64); png:SetPoint("LEFT"); png:SetTexture(MEDIA .. "test.png")
    local tga = testFrame:CreateTexture(nil, "ARTWORK")
    tga:SetSize(64, 64); tga:SetPoint("RIGHT"); tga:SetTexture(MEDIA .. "test.tga")
  end
  testFrame:Show()
  C_Timer.After(15, function() testFrame:Hide() end)
  out("Quadrado da ESQUERDA = PNG, da DIREITA = TGA (somem em 15s). Diga quais aparecem.")
end

local function run()
  local version, build, date, interface = GetBuildInfo()
  out("build", version, build, date, "interface", interface)
  frameCandidates()
  local keys = { GetBindingKey("TOGGLECHARACTER0") }
  for _, key in ipairs(keys) do
    out("tecla", key, "->", GetBindingAction(key, true) or "?")
  end
  if #keys == 0 then out("TOGGLECHARACTER0 sem tecla") end
  if Minimap and Minimap.GetScale then
    out("minimap escala", Minimap:GetScale(), Minimap:GetEffectiveScale(), "tamanho", Minimap:GetSize())
  end
  secretInfo("UnitHealth", UnitHealth("player"))
  secretInfo("UnitPower combo", UnitPower("player", Enum.PowerType.ComboPoints))
  showTextures()
  out("Agora entre em combate (boneco de treino): o teste de valor secreto roda de novo sozinho.")
end

local armed = false
ns.On("PLAYER_REGEN_DISABLED", function()
  if not armed then return end
  armed = false
  C_Timer.After(1, function()
    out("--- em combate ---")
    secretInfo("UnitHealth", UnitHealth("player"))
    secretInfo("UnitPower combo", UnitPower("player", Enum.PowerType.ComboPoints))
    secretInfo("UnitHealth target", UnitHealth("target"))
  end)
end)

SLASH_OBSIDIANUI1 = "/obui"
SlashCmdList.OBSIDIANUI = function(msg)
  if msg == "diag" then
    armed = true
    run()
  elseif msg == "" or msg == "config" then
    ns.Panel.Toggle()
  elseif msg:match("^modelo") then
    local dist, height = msg:match("^modelo%s+([%-%d%.]+)%s+([%-%d%.]+)")
    if not dist then
      out("uso: /obui modelo <distância> <altura>   ex.: /obui modelo 0.85 -0.1")
      out("distância menor = mais perto; altura negativa = mais para baixo")
      return
    end
    ns.db.modelDistance, ns.db.modelHeight = tonumber(dist), tonumber(height)
    if ns.Inventory and ns.Inventory.RefreshModel then ns.Inventory.RefreshModel() end
    out("modelo:", dist, height)
  elseif msg == "atalhos" then
    ns.KeybindMode.Start()
  elseif msg == "editar" then
    ns.EditMode.Start()
  elseif msg == "reset" then
    ns.ResetPositions()
    out("posições restauradas.")
  else
    out("comandos: /obui (configurações), /obui editar, /obui atalhos, /obui reset, /obui diag, /obui modelo")
  end
end
