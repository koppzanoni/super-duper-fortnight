local _, ns = ...

-- Installer (NaowhUI's idea): on the first login a few steps set the interface up — size, role,
-- colour — and apply it to the active profile. /obui instalar or the panel opens it again. Skip
-- leaves everything as it is. Only the colour needs a reload (asked, never forced).
local Installer = { step = 1, choices = {} }
ns.Installer = Installer

local WHITE, DIM = { 0.93, 0.94, 0.96 }, { 0.6, 0.63, 0.67 }
local BLUE = { 0.17, 0.56, 0.75 }
local W, H = 680, 380

local picked = {}
local STEPS = {
  { title = "Bem-vindo à ObsidianUI", text = "Em poucos passos a interface fica pronta para você. Dá para refazer tudo depois em /obui." },
  { title = "Tamanho da tela", key = "size", text = "Ajusta a escala da HUD para a sua resolução.", options = {
    { "1080", "1080p", "Escala 100%" }, { "1440", "1440p", "Escala 90%" }, { "2160", "4K", "Escala 80%" } } },
  { title = "Sua função", key = "role", text = "Posiciona os quadros do jeito que cada função joga melhor.", options = {
    { "dps", "Dano", "Quadros em cima, à esquerda." }, { "tank", "Tanque", "Igual ao dano." },
    { "healer", "Cura", "Quadros perto do centro." } } },
  { title = "Cor da HUD", key = "color", text = "A outra continua nas configurações.", options = {
    { "black", "Preto translúcido", "Painéis pretos e linhas neutras." }, { "blue", "Azul", "Como o conceito original." } } },
  { title = "Tudo pronto!", text = "Clique em Concluir. Em outros personagens o perfil carrega sozinho; cada especialização pode ter o seu em /obui > Perfis." },
}
local SCALE = { ["1080"] = 1, ["1440"] = 0.9, ["2160"] = 0.8 }

local frame = CreateFrame("Frame", "ObsidianUIInstaller", UIParent)
frame:SetSize(W, H)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
frame:SetFrameStrata("FULLSCREEN_DIALOG")
frame:EnableMouse(true)
frame:Hide()
Installer.frame = frame

local function fill(parent, layer, r, g, b, a)
  local t = parent:CreateTexture(nil, layer)
  t:SetColorTexture(r, g, b, a)
  return t
end
local function text(parent, template, color)
  local t = parent:CreateFontString(nil, "OVERLAY", template)
  t:SetTextColor(color[1], color[2], color[3])
  t:SetJustifyH("LEFT")
  return t
end

fill(frame, "BACKGROUND", 0.024, 0.028, 0.035, 0.96):SetAllPoints(frame)
local track = fill(frame, "BORDER", 1, 1, 1, 0.08)
track:SetPoint("TOPLEFT"); track:SetPoint("TOPRIGHT"); track:SetHeight(3)
local progress = fill(frame, "ARTWORK", BLUE[1], BLUE[2], BLUE[3], 1)
progress:SetPoint("TOPLEFT"); progress:SetHeight(3)
local stepLabel = text(frame, "GameFontDisableSmall", DIM)
stepLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 26, -24)
local title = text(frame, "GameFontNormalLarge", WHITE)
title:SetPoint("TOPLEFT", stepLabel, "BOTTOMLEFT", 0, -6)
local body = text(frame, "GameFontHighlight", DIM)
body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
body:SetWidth(W - 52)
Installer.title = title

local function button(label, w, onClick)
  local b = CreateFrame("Button", nil, frame)
  b:SetSize(w, 30)
  b.bg = fill(b, "BACKGROUND", 1, 1, 1, 0.06)
  b.bg:SetAllPoints(b)
  local hl = fill(b, "HIGHLIGHT", 1, 1, 1, 0.08)
  hl:SetAllPoints(b)
  b.label = text(b, "GameFontHighlight", WHITE)
  b.label:SetPoint("CENTER")
  b.label:SetJustifyH("CENTER")
  b.label:SetText(label)
  b:SetScript("OnClick", onClick)
  return b
end

-- Choice cards: up to 3 per step, reused.
for i = 1, 3 do
  local c = CreateFrame("Button", nil, frame)
  c:SetSize((W - 52 - 24) / 3, 92)
  c:SetPoint("TOPLEFT", frame, "TOPLEFT", 26 + (i - 1) * ((W - 52 - 24) / 3 + 12), -150)
  c.bg = fill(c, "BACKGROUND", 1, 1, 1, 0.04)
  c.bg:SetAllPoints(c)
  c.name = text(c, "GameFontNormal", WHITE)
  c.name:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -14)
  c.desc = text(c, "GameFontHighlightSmall", DIM)
  c.desc:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -6)
  c.desc:SetWidth((W - 52 - 24) / 3 - 24)
  c:Hide()
  Installer.choices[i] = c
end

Installer.counter = text(frame, "GameFontDisableSmall", DIM)
Installer.counter:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 26, 22)

local function show()
  local s = STEPS[Installer.step]
  stepLabel:SetText("PASSO " .. Installer.step)
  title:SetText(s.title)
  body:SetText(s.text)
  Installer.counter:SetText(Installer.step .. " / " .. #STEPS)
  progress:SetWidth(W * Installer.step / #STEPS)
  for i, c in ipairs(Installer.choices) do
    local o = s.options and s.options[i]
    if o then
      c.value, c.key = o[1], s.key
      c.name:SetText(o[2])
      c.desc:SetText(o[3])
      local on = picked[s.key] == o[1]
      c.bg:SetColorTexture(on and BLUE[1] or 1, on and BLUE[2] or 1, on and BLUE[3] or 1, on and 0.35 or 0.04)
      c:Show()
    else
      c:Hide()
    end
  end
  Installer.prevButton:SetShown(Installer.step > 1)
  Installer.nextButton.label:SetText(Installer.step == #STEPS and "Concluir" or "Continuar")
end

for _, c in ipairs(Installer.choices) do
  c:SetScript("OnClick", function(self)
    picked[self.key] = self.value
    show()
  end)
end

function Installer.Finish()
  local db, oldColor = ns.db, ns.db.modernColor
  local preset = picked.role == "healer" and "Healer" or "ObsidianUI"
  for k, v in pairs(ns.Profiles.PRESETS[preset].make()) do
    if v == false and k == "layout" then db.layout = nil else db[k] = v end
  end
  db.scale = SCALE[picked.size] or 1
  db.modernColor = picked.color or oldColor
  db.installed = true
  ns.Profiles.Save()
  frame:Hide()
  ns.Profiles.ApplyLive(oldColor)
end

Installer.prevButton = button("Anterior", 110, function()
  if Installer.step > 1 then Installer.step = Installer.step - 1; show() end
end)
Installer.prevButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -146, 14)
Installer.nextButton = button("Continuar", 120, function()
  if Installer.step < #STEPS then Installer.step = Installer.step + 1; show() else Installer.Finish() end
end)
Installer.nextButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 14)
Installer.nextButton.bg:SetColorTexture(BLUE[1], BLUE[2], BLUE[3], 1)
Installer.skipButton = button("Pular", 90, function()
  ns.db.installed = true
  if ns.db.profiles then ns.Profiles.Save() end
  frame:Hide()
end)
Installer.skipButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -264, 14)

function Installer.Open()
  local db = ns.db
  picked = { size = (db.scale == 0.9 and "1440") or (db.scale == 0.8 and "2160") or "1080",
    role = db.modernRows == 3 and "healer" or "dps", color = db.modernColor or "black" }
  Installer.step = 1
  frame:Show()
  show()
end

-- First login: after the HUD is up, out of combat.
ns.On("PLAYER_ENTERING_WORLD", function()
  if ns.db and not ns.db.installed and not frame:IsShown() then ns.RunOutOfCombat(Installer.Open) end
end)
