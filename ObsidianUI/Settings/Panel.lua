local _, ns = ...

-- ObsidianUI's own settings window (EllesmereUI's idea, the prototype the user approved): a module
-- sidebar in groups, a search box, every change applied at once. Modules not built yet are listed
-- as "em breve" instead of showing controls that do nothing. /obui opens it.
local Panel = { rows = {} }
ns.Panel = Panel

local W, H, SIDE = 960, 720, 230
local WHITE, DIM, MUTED = { 0.93, 0.94, 0.96 }, { 0.6, 0.63, 0.67 }, { 0.42, 0.45, 0.48 }
local BLUE = { 0.17, 0.56, 0.75 }

local function relayout() ns.RunOutOfCombat(ns.HUD.Layout) end

-- string.upper leaves accented letters alone ("LATêNCIA"): the Portuguese ones by hand.
local ACCENTS = { ["á"] = "Á", ["à"] = "À", ["â"] = "Â", ["ã"] = "Ã", ["é"] = "É", ["ê"] = "Ê", ["í"] = "Í", ["ó"] = "Ó",
  ["ô"] = "Ô", ["õ"] = "Õ", ["ú"] = "Ú", ["ç"] = "Ç" }
local function upper(str)
  str = string.upper(str)
  for lower, up in pairs(ACCENTS) do str = str:gsub(lower, up) end
  return str
end
Panel.Upper = upper
local function askReload() StaticPopup_Show("OBSIDIANUI_RELOAD") end

-- ------------------------------------------------------------------ what the panel shows
-- Row kinds: toggle / steps (number with - and +) / choice (segmented) / button. key: ns.db field.
local function toggle(label, key, default, onChange, help) return { kind = "toggle", label = label, key = key, default = default, onChange = onChange, help = help } end
local function steps(label, key, default, min, max, step, fmt, onChange, help)
  return { kind = "steps", label = label, key = key, default = default, min = min, max = max, step = step, fmt = fmt, onChange = onChange, help = help }
end
local function choice(label, key, default, options, onChange, help) return { kind = "choice", label = label, key = key, default = default, options = options, onChange = onChange, help = help } end
local function button(label, text, run, help) return { kind = "button", label = label, text = text, run = run, help = help } end
local pct = function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end
local int = function(v) return string.format("%d", v) end

Panel.SECTIONS = {
  { id = "general", name = "Geral", lead = "Cor e tamanho de toda a interface, ferramentas.", cards = {
    { "Aparência", {
      choice("Cor da HUD", "modernColor", "black", { { "black", "Preto translúcido" }, { "blue", "Azul" } }, askReload,
        "Trocar a cor recarrega a interface."),
      steps("Escala da interface", "scale", 1, 0.6, 1.4, 0.05, pct, relayout, "Aumenta ou diminui a HUD inteira."),
    } },
    { "Ferramentas", {
      button("Modo de edição", "Abrir", function() Panel.Close(); ns.EditMode.Start() end, "Mover, grudar e redimensionar cada elemento."),
      button("Teclas de atalho da barra", "Definir teclas", function() Panel.Close(); ns.KeybindMode.Start() end,
        "Passe o mouse num botão e aperte a tecla. Backspace limpa, Esc sai."),
      button("Restaurar posições", "Restaurar", function() ns.ResetPositions() end, "Tudo volta para o lugar padrão."),
    } },
  } },
  { id = "bar", group = "HUD", name = "Barras de ação", lead = "A barra central sem fundo e as barras verticais.", cards = {
    { "Layout", {
      steps("Linhas", "modernRows", 2, 1, 4, 1, int, relayout),
      steps("Colunas", "modernCols", 12, 4, 18, 1, int, relayout, "Até 36 botões."),
    } },
    { "Visual", {
      toggle("Números das teclas", "showHotkeys", true, function() ns.ActionBars.UpdateBindings() end),
    } },
    { "Barras verticais", {
      toggle("Barra vertical 1", "vbar1", false, function() ns.VerticalBars.Refresh() end, "12 botões na direita (barra direita 1 do jogo)."),
      toggle("Barra vertical 2", "vbar2", false, function() ns.VerticalBars.Refresh() end),
    } },
  } },
  { id = "frames", group = "HUD", name = "Quadros de unidade", lead = "Jogador, alvo, alvo do alvo, foco e pet.", cards = {
    { "Jogador", {
      toggle("Anel arcano no retrato", "arcaneRing", true, function()
        local player = ns.UnitFrames and ns.UnitFrames.frames.player
        if player and player.arcane then player.arcane:SetShown(ns.db.arcaneRing ~= false) end
      end, "Anel roxo girando por dentro do aro."),
    } },
  } },
  { id = "cast", group = "HUD", name = "Barra de cast", lead = "Preenchimento azul e o indicador de latência.", cards = {
    { "Latência", {
      toggle("Zona da latência (verde)", "castLag", true, function() ns.CastBar.Refresh() end, "Quando o azul entra no verde, já pode agir."),
      toggle("Mostrar os ms", "castMs", true, function() ns.CastBar.Refresh() end),
      toggle("Marca da janela de fila", "castQueue", true, function() ns.CastBar.Refresh() end, "Linha branca: dali a próxima magia entra na fila."),
    } },
  } },
  { id = "inventory", group = "Interface", name = "Inventário", lead = "Personagem e mochila na mesma janela.", cards = {
    { "Janela", {
      steps("Tamanho", "invScale", 1, 0.8, 1.3, 0.05, pct, function() if ns.Inventory then ns.RunOutOfCombat(ns.Inventory.Layout) end end,
        "Acima de 100% a janela pode cobrir parte da HUD."),
      button("Abrir inventário", "Abrir", function() Panel.Close(); if ns.Inventory then ns.Inventory.Open() end end),
    } },
  } },
  -- planned (the prototype has their options); listed so the panel shows where things are going
  { id = "visual", name = "Visual", soon = true },
  { id = "resources", group = "HUD", name = "Recursos de classe", soon = true },
  { id = "auras", group = "HUD", name = "Auras", soon = true },
  { id = "databars", group = "HUD", name = "Barras de dados", soon = true },
  { id = "infobar", group = "HUD", name = "Barra de informações", soon = true },
  { id = "party", group = "Grupo", name = "Grupo", soon = true },
  { id = "raid", group = "Grupo", name = "Raide", soon = true },
  { id = "plates", group = "Grupo", name = "Nameplates", soon = true },
  { id = "chat", group = "Interface", name = "Chat", soon = true },
  { id = "quests", group = "Interface", name = "Rastreador de missões", soon = true },
  { id = "tooltip", group = "Interface", name = "Dicas (tooltip)", soon = true },
  { id = "skins", group = "Interface", name = "Janelas da Blizzard", soon = true },
  { id = "cursor", group = "Interface", name = "Cursor", soon = true },
  { id = "automation", group = "Qualidade de vida", name = "Automação", soon = true },
  { id = "cooldowns", group = "Qualidade de vida", name = "Recarga nos ícones", soon = true },
  { id = "reminders", group = "Qualidade de vida", name = "Lembretes", soon = true },
  { id = "classes", group = "Classes", name = "Classes", soon = true },
  { id = "profiles", name = "Perfis", soon = true },
}
local GROUP_ORDER = { [""] = 0, HUD = 1, Grupo = 2, Interface = 3, ["Qualidade de vida"] = 4, Classes = 5 }
local function rank(sec)
  if sec.id == "profiles" then return 99 end
  if sec.id == "visual" then return 0.5 end
  return GROUP_ORDER[sec.group or ""]
end
-- stable: inside a group the list keeps its written order (table.sort alone does not)
for i, sec in ipairs(Panel.SECTIONS) do sec.index = i end
table.sort(Panel.SECTIONS, function(a, b)
  if rank(a) ~= rank(b) then return rank(a) < rank(b) end
  return a.index < b.index
end)

function Panel.Get(row)
  local v = ns.db and ns.db[row.key]
  if v == nil then return row.default end
  return v
end

function Panel.Set(row, value)
  ns.db[row.key] = value
  if row.onChange then row.onChange(value) end
end

-- ------------------------------------------------------------------ window
local frame = CreateFrame("Frame", "ObsidianUIConfig", UIParent)
frame:SetSize(W, H)
frame:SetPoint("CENTER")
frame:SetFrameStrata("DIALOG")
frame:SetToplevel(true)
frame:EnableMouse(true)
frame:SetMovable(true)
frame:Hide()
Panel.frame = frame
UISpecialFrames[#UISpecialFrames + 1] = "ObsidianUIConfig" -- Esc closes it

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
local function edge(f, alpha)
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local e = fill(f, "BORDER", 1, 1, 1, alpha)
    if side == "TOP" or side == "BOTTOM" then
      e:SetPoint(side .. "LEFT"); e:SetPoint(side .. "RIGHT"); e:SetHeight(1)
    else
      e:SetPoint("TOP" .. side); e:SetPoint("BOTTOM" .. side); e:SetWidth(1)
    end
  end
end

fill(frame, "BACKGROUND", 0.024, 0.028, 0.035, 0.94):SetAllPoints(frame)
edge(frame, 0.1)

local header = CreateFrame("Frame", nil, frame)
header:SetPoint("TOPLEFT"); header:SetPoint("TOPRIGHT"); header:SetHeight(52)
header:EnableMouse(true)
header:RegisterForDrag("LeftButton")
header:SetScript("OnDragStart", function() frame:StartMoving() end)
header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
local logo = text(header, "GameFontNormalLarge", WHITE)
logo:SetPoint("LEFT", header, "LEFT", 16, 0)
logo:SetText("ObsidianUI")
local sub = text(header, "GameFontHighlightSmall", DIM)
sub:SetPoint("LEFT", logo, "RIGHT", 8, -1)
sub:SetText("Configurações")
local headerLine = fill(header, "BORDER", 1, 1, 1, 0.08)
headerLine:SetPoint("BOTTOMLEFT"); headerLine:SetPoint("BOTTOMRIGHT"); headerLine:SetHeight(1)

local function flatButton(parent, label, w, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, 28)
  local bg = fill(b, "BACKGROUND", 1, 1, 1, 0.05)
  bg:SetAllPoints(b)
  edge(b, 0.14)
  local hl = fill(b, "HIGHLIGHT", 1, 1, 1, 0.07)
  hl:SetAllPoints(b)
  b.label = text(b, "GameFontHighlightSmall", WHITE)
  b.label:SetPoint("CENTER")
  b.label:SetText(label)
  b.bg = bg
  b:SetScript("OnClick", onClick)
  return b
end

local close = flatButton(header, "X", 28, function() Panel.Close() end)
close:SetPoint("RIGHT", header, "RIGHT", -12, 0)
local editBtn = flatButton(header, "Modo de edição", 120, function() Panel.Close(); ns.EditMode.Start() end)
editBtn:SetPoint("RIGHT", close, "LEFT", -8, 0)
Panel.editButton, Panel.closeButton = editBtn, close

local search = CreateFrame("EditBox", "ObsidianUIConfigSearch", header)
search:SetSize(240, 28)
search:SetPoint("RIGHT", editBtn, "LEFT", -10, 0)
search:SetAutoFocus(false)
search:SetFontObject("GameFontHighlightSmall")
search:SetTextInsets(10, 10, 0, 0)
fill(search, "BACKGROUND", 0, 0, 0, 0.45):SetAllPoints(search)
edge(search, 0.14)
local searchHint = text(search, "GameFontDisableSmall", MUTED)
searchHint:SetPoint("LEFT", search, "LEFT", 10, 0)
searchHint:SetText("Buscar opção...")
Panel.search = search
search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

-- sidebar
local side = CreateFrame("Frame", nil, frame)
side:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -52)
side:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
side:SetWidth(SIDE)
local sideLine = fill(side, "BORDER", 1, 1, 1, 0.08)
sideLine:SetPoint("TOPRIGHT"); sideLine:SetPoint("BOTTOMRIGHT"); sideLine:SetWidth(1)
Panel.sideButtons = {}

-- content
local body = CreateFrame("Frame", nil, frame)
body:SetPoint("TOPLEFT", side, "TOPRIGHT", 22, -18)
body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 18)
Panel.body = body
local title = text(body, "GameFontNormalLarge", WHITE)
title:SetPoint("TOPLEFT")
local lead = text(body, "GameFontHighlightSmall", DIM)
lead:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
Panel.title, Panel.lead = title, lead

-- ------------------------------------------------------------------ rows
local pool = {}
local function clearRows()
  for _, r in ipairs(Panel.rows) do r:Hide() end
  Panel.rows = {}
end

local function newRow()
  local r = CreateFrame("Frame", nil, body)
  r:SetHeight(42)
  r.label = text(r, "GameFontHighlight", WHITE)
  r.label:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -6)
  r.help = text(r, "GameFontDisableSmall", MUTED)
  r.help:SetPoint("TOPLEFT", r.label, "BOTTOMLEFT", 0, -3)
  local line = fill(r, "BORDER", 1, 1, 1, 0.05)
  line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(1)
  r.controls = {}
  return r
end

local function clearControls(r)
  for _, c in ipairs(r.controls) do c:Hide() end
  r.controls = {}
end

local function switch(r, row)
  local s = CreateFrame("Button", nil, r)
  s:SetSize(40, 22)
  s:SetPoint("RIGHT", r, "RIGHT", 0, 0)
  local track = fill(s, "BACKGROUND", 1, 1, 1, 0.14)
  track:SetAllPoints(s)
  local knob = fill(s, "ARTWORK", 0.85, 0.87, 0.9, 1)
  knob:SetSize(16, 16)
  local function draw()
    local on = Panel.Get(row) and true or false
    track:SetColorTexture(on and BLUE[1] or 1, on and BLUE[2] or 1, on and BLUE[3] or 1, on and 1 or 0.14)
    knob:ClearAllPoints()
    knob:SetPoint("LEFT", s, "LEFT", on and 21 or 3, 0)
    s.on = on
  end
  s:SetScript("OnClick", function() Panel.Set(row, not Panel.Get(row)); draw() end)
  draw()
  return s
end

local function stepper(r, row)
  local holder = CreateFrame("Frame", nil, r)
  holder:SetSize(160, 26)
  holder:SetPoint("RIGHT", r, "RIGHT", 0, 0)
  local value = text(holder, "GameFontHighlight", WHITE)
  value:SetPoint("CENTER")
  value:SetJustifyH("CENTER")
  local function draw() value:SetText(row.fmt(Panel.Get(row))) end
  local function bump(dir)
    local v = Panel.Get(row) + dir * row.step
    v = math.max(row.min, math.min(row.max, math.floor(v / row.step + 0.5) * row.step))
    Panel.Set(row, v)
    draw()
  end
  local minus = flatButton(holder, "-", 32, function() bump(-1) end)
  minus:SetPoint("LEFT")
  local plus = flatButton(holder, "+", 32, function() bump(1) end)
  plus:SetPoint("RIGHT")
  holder.minus, holder.plus, holder.value = minus, plus, value
  draw()
  return holder
end

local function segmented(r, row)
  local holder = CreateFrame("Frame", nil, r)
  holder:SetHeight(26)
  local x, buttons = 0, {}
  local function draw()
    for _, b in ipairs(buttons) do
      local on = Panel.Get(row) == b.value
      b.bg:SetColorTexture(1, 1, 1, on and 0.16 or 0.04)
      b.label:SetTextColor(on and 1 or DIM[1], on and 1 or DIM[2], on and 1 or DIM[3])
    end
  end
  for i = #row.options, 1, -1 do
    local o = row.options[i]
    local b = flatButton(holder, o[2], 130, function() Panel.Set(row, o[1]); draw() end)
    b.value = o[1]
    b:SetPoint("RIGHT", holder, "RIGHT", -x, 0)
    x = x + 134
    buttons[#buttons + 1] = b
  end
  holder:SetWidth(x)
  holder:SetPoint("RIGHT", r, "RIGHT", 0, 0)
  holder.buttons = buttons
  draw()
  return holder
end

local function fillRow(r, row, where)
  clearControls(r)
  r.label:SetText(row.label .. (where and ("  |cff6d737a" .. where .. "|r") or ""))
  r.help:SetText(row.help or "")
  r.row = row
  local c
  if row.kind == "toggle" then c = switch(r, row)
  elseif row.kind == "steps" then c = stepper(r, row)
  elseif row.kind == "choice" then c = segmented(r, row)
  else c = flatButton(r, row.text, 130, row.run); c:SetPoint("RIGHT", r, "RIGHT", 0, 0) end
  r.control = c
  r.controls[1] = c
end

local function addHeading(textValue, y)
  local r = pool[#Panel.rows + 1] or newRow()
  pool[#Panel.rows + 1] = r
  clearControls(r)
  r.row = nil
  r.label:SetText("|cff7f858c" .. upper(textValue) .. "|r")
  r.help:SetText("")
  r:ClearAllPoints()
  r:SetPoint("TOPLEFT", body, "TOPLEFT", 0, y)
  r:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, y)
  r:SetHeight(28)
  r:Show()
  Panel.rows[#Panel.rows + 1] = r
  return y - 30
end

local function addRow(row, y, where)
  local r = pool[#Panel.rows + 1] or newRow()
  pool[#Panel.rows + 1] = r
  r:ClearAllPoints()
  r:SetPoint("TOPLEFT", body, "TOPLEFT", 0, y)
  r:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, y)
  r:SetHeight(row.help and 46 or 38)
  fillRow(r, row, where)
  r:Show()
  Panel.rows[#Panel.rows + 1] = r
  return y - (row.help and 48 or 40)
end

-- ------------------------------------------------------------------ pages
function Panel.Show(id)
  Panel.current = id
  clearRows()
  local sec
  for _, s in ipairs(Panel.SECTIONS) do if s.id == id then sec = s end end
  title:SetText(sec.name)
  local y = -48
  if sec.soon then
    lead:SetText("Em breve: este módulo está no protótipo aprovado e será feito numa próxima etapa.")
  else
    lead:SetText(sec.lead or "")
    for _, card in ipairs(sec.cards) do
      y = addHeading(card[1], y)
      for _, row in ipairs(card[2]) do y = addRow(row, y) end
      y = y - 10
    end
  end
  for _, b in ipairs(Panel.sideButtons) do b.bg:SetColorTexture(1, 1, 1, b.id == id and 0.09 or 0) end
end

function Panel.Search(query)
  query = string.lower(query or "")
  if query == "" then return Panel.Show(Panel.current or "general") end
  clearRows()
  title:SetText("Resultados")
  lead:SetText("Opções com \"" .. query .. "\".")
  local y, n = -48, 0
  for _, sec in ipairs(Panel.SECTIONS) do
    for _, card in ipairs(sec.cards or {}) do
      for _, row in ipairs(card[2]) do
        local hay = string.lower(row.label .. " " .. (row.help or "") .. " " .. sec.name)
        if hay:find(query, 1, true) then y = addRow(row, y, sec.name); n = n + 1 end
      end
    end
  end
  if n == 0 then lead:SetText("Nada encontrado para \"" .. query .. "\".") end
end

search:SetScript("OnTextChanged", function(self)
  local q = self:GetText() or ""
  searchHint:SetShown(q == "")
  Panel.Search(q)
end)

local function buildSide()
  local y, lastGroup = -10, nil
  for _, sec in ipairs(Panel.SECTIONS) do
    if sec.id == "profiles" then y = y - 10 end
    if sec.group and sec.group ~= lastGroup then
      local g = text(side, "GameFontDisableSmall", MUTED)
      g:SetPoint("TOPLEFT", side, "TOPLEFT", 16, y - 4)
      g:SetText(upper(sec.group))
      y = y - 18
    end
    lastGroup = sec.group
    local b = CreateFrame("Button", nil, side)
    b:SetPoint("TOPLEFT", side, "TOPLEFT", 8, y)
    b:SetPoint("TOPRIGHT", side, "TOPRIGHT", -8, y)
    b:SetHeight(21)
    b.bg = fill(b, "BACKGROUND", 1, 1, 1, 0)
    b.bg:SetAllPoints(b)
    local hl = fill(b, "HIGHLIGHT", 1, 1, 1, 0.05)
    hl:SetAllPoints(b)
    b.label = text(b, "GameFontHighlightSmall", sec.soon and DIM or WHITE)
    b.label:SetPoint("LEFT", b, "LEFT", 10, 0)
    b.label:SetText(sec.name)
    if sec.soon then
      local tag = text(b, "GameFontDisableSmall", MUTED)
      tag:SetPoint("RIGHT", b, "RIGHT", -8, 0)
      tag:SetText("em breve")
    end
    b.id = sec.id
    b:SetScript("OnClick", function() search:SetText(""); Panel.Show(sec.id) end)
    Panel.sideButtons[#Panel.sideButtons + 1] = b
    y = y - 22
  end
end
buildSide()

function Panel.Open(id)
  frame:Show()
  Panel.Show(id or Panel.current or "general")
end

function Panel.Close()
  frame:Hide()
end

function Panel.Toggle()
  if frame:IsShown() then Panel.Close() else Panel.Open() end
end
