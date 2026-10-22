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
  elseif msg == "config" then
    ns.OpenSettings()
  else
    out("comandos: /obui diag, /obui config")
  end
end
