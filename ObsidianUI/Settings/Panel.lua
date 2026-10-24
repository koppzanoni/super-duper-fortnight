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

-- Colour presets for the Visual page (a picker would need the game's colour window).
Panel.COLORS = {
  { "", "Padrão" }, { "red", "Vermelho", { 0.89, 0.2, 0.17 } }, { "orange", "Laranja", { 0.95, 0.5, 0.12 } },
  { "yellow", "Amarelo", { 0.95, 0.8, 0.15 } }, { "green", "Verde", { 0.25, 0.75, 0.25 } }, { "teal", "Azul-petróleo", { 0.13, 0.6, 0.7 } },
  { "blue", "Azul", { 0.09, 0.52, 0.96 } }, { "purple", "Roxo", { 0.6, 0.3, 0.9 } }, { "grey", "Cinza", { 0.55, 0.57, 0.6 } },
}
-- The token of the player's class resource (for its colour), or a stand-in.
function Panel.ResourceToken()
  local _, classToken = UnitClass("player")
  local r = ns.Data.ClassResourceFor(classToken, GetSpecialization and GetSpecialization(), (UnitPowerType("player")))
  return r and r.token or "COMBO_POINTS"
end
-- Test mode of the group frames: stand-ins to place and size them while solo (combat ends it).
function Panel.TestRow()
  return { kind = "choice", label = "Modo de teste", key = "groupTest",
    options = { { "", "Desligado" }, { "party", "Grupo" }, { "raid", "Raide" } },
    get = function() return ns.GroupFrames.testing or "" end,
    set = function(v) ns.GroupFrames.Test(v ~= "" and v or nil) end,
    help = "Mostra quadros de exemplo para posicionar. Some ao entrar em combate." }
end
function Panel.ColorOptions() local o = {}; for _, c in ipairs(Panel.COLORS) do o[#o + 1] = { c[1], c[2] } end; return o end
function Panel.ColorGet(key)
  local c = ns.db.colors and ns.db.colors[key]
  if not c then return "" end
  for _, p in ipairs(Panel.COLORS) do
    if p[3] and math.abs(p[3][1] - c[1]) < 0.01 and math.abs(p[3][2] - c[2]) < 0.01 then return p[1] end
  end
  return ""
end
function Panel.ColorSet(key, id)
  ns.db.colors = ns.db.colors or {}
  local rgb
  for _, p in ipairs(Panel.COLORS) do if p[1] == id then rgb = p[3] end end
  ns.db.colors[key] = rgb and { rgb[1], rgb[2], rgb[3] } or nil
  if ns.Profiles and ns.db.profiles then ns.Profiles.Save() end
  ns.Look.Apply()
end

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
      button("Instalador", "Abrir", function() Panel.Close(); ns.Installer.Open() end, "Refazer a configuração guiada (tamanho, função, cor)."),
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
  { id = "visual", name = "Visual", lead = "Fonte, textura das barras, números e cores de toda a HUD.", cards = {
    { "Texto", {
      { kind = "cycle", label = "Fonte", key = "font", default = "default", onChange = function() ns.Look.Apply() end,
        options = function() local o = {}; for _, f in ipairs(ns.Look.FONTS) do o[#o + 1] = { f[1], f[2] } end; return o end },
      choice("Contorno", "outline", "OUTLINE", { { "NONE", "Nenhum" }, { "OUTLINE", "Fino" }, { "THICKOUTLINE", "Grosso" } },
        function() ns.Look.Apply() end),
      choice("Números", "numFmt", "short", { { "short", "48.3K" }, { "full", "48.320" } }, function() ns.Look.Apply() end,
        "Vida e mana nos quadros."),
    } },
    { "Barras", {
      choice("Textura das barras", "barTex", "gloss", { { "gloss", "Vidro" }, { "soft", "Suave" }, { "flat", "Lisa" }, { "blizzard", "Blizzard" } },
        function() ns.Look.Apply() end),
    } },
    { "Cores", {
      { kind = "cycle", label = "Inimigo", key = "c_hostile", options = Panel.ColorOptions, get = function() return Panel.ColorGet("hostile") end,
        set = function(v) Panel.ColorSet("hostile", v) end },
      { kind = "cycle", label = "Neutro", key = "c_neutral", options = Panel.ColorOptions, get = function() return Panel.ColorGet("neutral") end,
        set = function(v) Panel.ColorSet("neutral", v) end },
      { kind = "cycle", label = "Aliado", key = "c_friendly", options = Panel.ColorOptions, get = function() return Panel.ColorGet("friendly") end,
        set = function(v) Panel.ColorSet("friendly", v) end },
      { kind = "cycle", label = "Mana", key = "c_mana", options = Panel.ColorOptions, get = function() return Panel.ColorGet("MANA") end,
        set = function(v) Panel.ColorSet("MANA", v) end, help = "Escolha entre cores prontas; \"Padrão\" volta à original." },
    } },
  } },
  { id = "resources", group = "HUD", name = "Recursos de classe",
    lead = "Pontos de combo, poder sagrado, runas, fragmentos, chi e cargas arcanas. Posição e tamanho: modo de edição.", cards = {
    { "Visual", {
      toggle("Mostrar o recurso", "res_on", true, function() ns.ClassResource.Redraw() end),
      choice("Estilo", "resStyle", "gems", { { "gems", "Gemas" }, { "bar", "Barra" } }, function() ns.ClassResource.Redraw() end,
        "A barra continua aparecendo em combate mesmo quando o jogo esconde os números."),
      toggle("Esconder fora de combate quando vazio", "resHide", false, function() ns.ClassResource.Redraw() end),
    } },
    { "Cor", {
      { kind = "cycle", label = "Cor do recurso", options = function() return Panel.ColorOptions() end,
        get = function() return Panel.ColorGet(Panel.ResourceToken()) end,
        set = function(v) Panel.ColorSet(Panel.ResourceToken(), v); ns.ClassResource.Redraw() end,
        help = "Vale para o recurso da sua classe." },
    } },
  } },
  { id = "auras", group = "HUD", name = "Auras", lead = "Buffs e debuffs do jogador. Posição: modo de edição.", cards = {
    { "Mostrar", {
      toggle("Buffs", "buffs_on", true, function() ns.Auras.Update() end),
      toggle("Debuffs", "debuffs_on", true, function() ns.Auras.Update() end, "A borda pega a cor do tipo: magia, maldição, doença, veneno."),
    } },
    { "Tamanho", {
      steps("Tamanho dos ícones", "buffSize", 26, 18, 48, 2, int, function() ns.HUD.Layout() end),
      steps("Ícones por linha", "buffRow", 16, 4, 24, 1, int, function() ns.HUD.Layout() end),
    } },
  } },
  { id = "databars", group = "HUD", name = "Barras de dados", lead = "Experiência e reputação embaixo da barra de ações. Posição: modo de edição.", cards = {
    { "Mostrar", {
      toggle("Experiência", "xp_on", true, function() ns.DataBars.Update() end, "Some sozinha no nível máximo."),
      toggle("Reputação", "rep_on", true, function() ns.DataBars.Update() end, "A facção acompanhada no painel de reputação."),
    } },
    { "Aparência", {
      choice("Texto", "dataText", "hover", { { "always", "Sempre" }, { "hover", "Ao passar o mouse" }, { "never", "Nunca" } },
        function() ns.DataBars.Update() end),
      steps("Altura", "dataHeight", 5, 3, 14, 1, int, function() ns.DataBars.Update() end),
    } },
  } },
  { id = "infobar", group = "HUD", name = "Barra de informações", lead = "FPS, latência, durabilidade, bolsas, ouro, amigos, guilda e hora numa faixa.",
    build = function()
      local items = { toggle("Mostrar a barra", "info_on", true, function() ns.HUD.Layout() end, "Arraste no modo de edição.") }
      for _, it in ipairs(ns.InfoBar.ITEMS) do
        items[#items + 1] = toggle(it[2], "info_" .. it[1], it[3], function() ns.InfoBar.Update() end)
      end
      return { { "Itens", items } }
    end },
  { id = "party", group = "Grupo", name = "Grupo", lead = "Os outros quatro do grupo, no visual dos quadros. Posição: modo de edição.", cards = {
    { "Quadros", {
      toggle("Mostrar", "party_on", true, function() ns.GroupFrames.Refresh() end,
        "Desligado, os quadros da Blizzard voltam depois de recarregar."),
      toggle("Você no grupo", "partyPlayer", false, function() ns.GroupFrames.Refresh() end, "Seu quadro em cima dos outros."),
      choice("Estilo", "partyStyle", "frames", { { "frames", "Quadros" }, { "cells", "Células do raide" } },
        function() ns.GroupFrames.Refresh() end, "As células usam o tamanho e a direção da página Raide."),
    } },
    { "Teste", { Panel.TestRow() } },
  } },
  { id = "raid", group = "Grupo", name = "Raide", lead = "Células compactas por grupo, na cor da classe. Posição: modo de edição.", cards = {
    { "Quadros", {
      toggle("Mostrar", "raid_on", true, function() ns.GroupFrames.Refresh() end,
        "Desligado, os quadros da Blizzard voltam depois de recarregar."),
      choice("Grupos", "raidGrowth", "rows", { { "rows", "Em linhas" }, { "columns", "Em colunas" } },
        function() ns.GroupFrames.Refresh() end),
      toggle("Debuffs nos quadros", "groupDebuffs", true, function() ns.GroupFrames.Refresh() end,
        "Até três por membro, no raide e no grupo."),
      toggle("Ferramentas de raide", "raidTools", true, function() ns.RaidTools.Update() end,
        "Pronto?, contagem e marcadores do alvo. Só para quem lidera ou é assistente."),
    } },
    { "Tamanho", {
      steps("Largura", "raidW", 72, 40, 140, 4, int, function() ns.GroupFrames.Refresh() end),
      steps("Altura", "raidH", 36, 20, 80, 2, int, function() ns.GroupFrames.Refresh() end),
    } },
    { "Teste", { Panel.TestRow() } },
  } },
  { id = "plates", group = "Grupo", name = "Nameplates", lead = "As barras em cima dos inimigos, no visual da HUD.", cards = {
    { "Mostrar", {
      toggle("Usar as nameplates da ObsidianUI", "plates_on", true, function() ns.Nameplates.Refresh() end,
        "Desligado, volta o visual do jogo."),
      toggle("Porcentagem de vida", "plateHP", true, function() ns.Nameplates.Refresh() end),
      toggle("Barra de cast", "plateCast", true, function() ns.Nameplates.Refresh() end, "Cinza quando não dá para interromper."),
      toggle("Seus debuffs", "plateDebuffs", true, function() ns.Nameplates.Refresh() end, "Até quatro, acima do nome."),
      toggle("Apagar quem não é o alvo", "plateFade", true, function() ns.Nameplates.Refresh() end),
    } },
    { "Tamanho", {
      steps("Largura", "plateW", 140, 80, 260, 10, int, function() ns.Nameplates.Refresh() end),
      steps("Altura", "plateH", 10, 4, 24, 1, int, function() ns.Nameplates.Refresh() end),
    } },
  } },
  { id = "chat", group = "Interface", name = "Chat", lead = "Painel preto, abas lisas, caixa de digitar embaixo e botão de copiar.", cards = {
    { "Visual", {
      toggle("Usar o chat da ObsidianUI", "chat_on", true, function() ns.Chat.Apply() end,
        "Desligado, o chat volta ao normal depois de recarregar."),
      toggle("Botões do lado do chat", "chatButtons", false, function() ns.Chat.Apply() end,
        "Menu, canais e grupo rápido."),
    } },
    { "Mensagens", {
      steps("Mensagens somem depois de", "chatFade", 120, 0, 600, 10, function(v) return v == 0 and "nunca" or (v .. " s") end,
        function() ns.Chat.Apply() end, "Passe o mouse no chat para ver de novo."),
    } },
  } },
  { id = "quests", group = "Interface", name = "Rastreador de missões", lead = "Títulos em branco com linha roxa. Posição: modo de edição.", cards = {
    { "Visual", {
      toggle("Usar o visual da ObsidianUI", "quest_on", true, nil, "Desligado, volta ao normal depois de recarregar."),
    } },
    { "Comportamento", {
      toggle("Recolher em combate", "questCombat", true, nil, "Abre de novo quando o combate acaba."),
      toggle("Recolher em instâncias", "questInstance", false, nil, "Masmorras, raides e campos de batalha."),
    } },
  } },
  { id = "tooltip", group = "Interface", name = "Dicas (tooltip)", lead = "Painel preto com a borda na cor da raridade ou da classe.", cards = {
    { "Visual", {
      toggle("Usar as dicas da ObsidianUI", "tip_on", true, nil, "Desligado, as dicas voltam ao normal depois de recarregar."),
    } },
    { "Comportamento", {
      choice("Posição", "tipAnchor", "default", { { "default", "Padrão" }, { "cursor", "No cursor" }, { "hud", "Acima da barra de informações" } }),
      toggle("Em combate", "tipCombat", true, nil, "Desligado, as dicas de quem está no mundo somem em combate; as dos botões continuam."),
    } },
  } },
  { id = "skins", group = "Interface", name = "Janelas da Blizzard", lead = "Personagem, amigos, talentos, coleções, mapa, comerciante, correio e as outras no painel preto.", cards = {
    { "Visual", {
      toggle("Usar o visual da ObsidianUI", "skins_on", true, nil,
        "Desligado, as janelas voltam ao normal depois de recarregar. A de conquistas fica com a arte dela."),
    } },
  } },
  { id = "cursor", group = "Interface", name = "Cursor", lead = "Deixar o cursor fácil de achar no meio da luta.", cards = {
    { "Efeitos", {
      toggle("Anel em volta do cursor", "curRing", false, function() ns.Cursor.Refresh() end),
      toggle("Rastro", "curTrail", false, function() ns.Cursor.Refresh() end, "Pontos que somem atrás do cursor quando ele se move."),
      { kind = "cycle", label = "Cor", key = "c_cursor", options = Panel.ColorOptions, get = function() return Panel.ColorGet("cursor") end,
        set = function(v) Panel.ColorSet("cursor", v) end, help = "\"Padrão\" usa o roxo da HUD." },
    } },
    { "Quando", {
      toggle("Só em combate", "curCombat", true, function() ns.Cursor.Refresh() end),
      steps("Tamanho", "curSize", 1, 0.5, 2, 0.1, pct, function() ns.Cursor.Refresh() end),
    } },
  } },
  { id = "automation", group = "Qualidade de vida", name = "Automação", soon = true },
  { id = "cooldowns", group = "Qualidade de vida", name = "Recarga nos ícones", lead = "O tempo que falta em cima de cada ícone, desenhado pelo próprio jogo.", cards = {
    { "Mostrar", {
      toggle("Números de recarga", "cd_on", true, function() ns.Cooldowns.Refresh() end, "Barras de ação e itens das bolsas."),
      toggle("Também nos buffs e debuffs", "cdAuras", true, function() ns.Cooldowns.Refresh() end, "Os seus e os debuffs no alvo."),
      toggle("Décimos nos últimos 3 segundos", "cdDecimals", true, function() ns.Cooldowns.Refresh() end),
    } },
    { "Quando", {
      steps("Só a partir de", "cdMin", 1.5, 0, 10, 0.5, function(v) return string.format("%.1f s", v) end,
        function() ns.Cooldowns.Refresh() end, "Recargas mais curtas (como a global) ficam sem número."),
    } },
  } },
  { id = "reminders", group = "Qualidade de vida", name = "Lembretes", soon = true },
  { id = "classes", group = "Classes", name = "Classes", soon = true },
  { id = "profiles", name = "Perfis", lead = "Salve layouts, um por especialização ou por conteúdo, e compartilhe por texto.",
    build = function() return Panel.ProfileCards() end },
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
  if row.get then return row.get() end
  local v = ns.db and ns.db[row.key]
  if v == nil then return row.default end
  return v
end

function Panel.Set(row, value)
  if row.set then
    row.set(value)
  else
    ns.db[row.key] = value
  end
  if row.onChange then row.onChange(value) end
  -- every change lands in the active profile too
  if ns.Profiles and ns.db.profiles and not row.set then ns.Profiles.Save() end
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
-- The page scrolls with the mouse wheel when it is taller than the window (Perfis is).
local view = CreateFrame("ScrollFrame", "ObsidianUIConfigView", frame)
view:SetPoint("TOPLEFT", side, "TOPRIGHT", 22, -18)
view:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 18)
local body = CreateFrame("Frame", nil, view)
body:SetSize(W - SIDE - 44, 10)
view:SetScrollChild(body)
view:EnableMouseWheel(true)
view:SetScript("OnMouseWheel", function(self, delta)
  local max = math.max(0, body:GetHeight() - self:GetHeight())
  self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - delta * 40)))
end)
Panel.body, Panel.view = body, view
local function pageHeight(y)
  body:SetHeight(math.max(10, -y + 10))
  view:SetVerticalScroll(0)
end
local title = text(body, "GameFontNormalLarge", WHITE)
title:SetPoint("TOPLEFT")
local lead = text(body, "GameFontHighlightSmall", DIM)
lead:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
Panel.title, Panel.lead = title, lead

-- ------------------------------------------------------------------ Perfis page
local P = function() return ns.Profiles end
local function profileOptions(withNone)
  local list = withNone and { { "", "(nenhum)" } } or {}
  for _, name in ipairs(P().List()) do list[#list + 1] = { name, name } end
  return list
end
local function refreshPage() if Panel.current == "profiles" then Panel.Show("profiles") end end

local CONTENT = { { "solo", "Sozinho" }, { "group", "Grupo" }, { "raid", "Raide" }, { "pvp", "JxJ" } }

function Panel.ProfileCards()
  local active = {
    { kind = "cycle", label = "Perfil deste personagem", options = function() return profileOptions(false) end,
      get = function() return P().Current() end, set = function(v) P().Switch(v) end,
      help = "Trocar aplica na hora. Cada personagem lembra o seu." },
    button("Novo perfil", "Criar (cópia)", function()
      local n = 2
      while ns.db.profiles["Perfil " .. n] do n = n + 1 end
      P().New("Perfil " .. n, P().Current())
      P().Switch("Perfil " .. n)
      refreshPage()
    end, "Começa como uma cópia do perfil atual."),
    button("Excluir este perfil", "Excluir", function()
      local name = P().Current()
      if name == "Padrão" then return end
      P().Switch("Padrão")
      P().Delete(name)
      refreshPage()
    end, "Volta para o perfil Padrão (que não pode ser excluído)."),
  }
  local specs = {}
  local count = (GetNumSpecializations and GetNumSpecializations()) or 3
  if type(count) ~= "number" or count < 1 then count = 3 end
  for i = 1, count do
    local name = GetSpecializationInfo and select(2, GetSpecializationInfo(i))
    specs[#specs + 1] = { kind = "cycle", label = (type(name) == "string" and name) or ("Especialização " .. i),
      options = function() return profileOptions(true) end,
      get = function() return P().SpecProfile(i) or "" end,
      set = function(v) P().SetSpecProfile(i, v ~= "" and v or nil) end }
  end
  specs[1].help = "Ao trocar de especialização, o perfil dela carrega sozinho."
  local content = {
    { kind = "toggle", label = "Trocar sozinho pelo tipo de conteúdo", get = function() return P().AutoContent() end,
      set = function(v) P().SetAutoContent(v) end, help = "Grupo, raide ou JxJ carregam o perfil escolhido abaixo." },
  }
  for _, c in ipairs(CONTENT) do
    content[#content + 1] = { kind = "cycle", label = c[2], options = function() return profileOptions(true) end,
      get = function() return P().ContentProfile(c[1]) or "" end,
      set = function(v) P().SetContentProfile(c[1], v ~= "" and v or nil) end }
  end
  local presets = {}
  for _, name in ipairs(P().PRESET_ORDER) do
    presets[#presets + 1] = button(name, "Aplicar", function() P().ApplyPreset(name) end, P().PRESETS[name].desc)
  end
  local share = {
    button("Exportar tudo", "Exportar", function() Panel.TextBox("export", P().Export("all")) end, "Todas as opções e posições deste perfil."),
    button("Exportar só posições", "Exportar", function() Panel.TextBox("export", P().Export("layout")) end),
    button("Importar", "Colar texto", function() Panel.TextBox("import", "") end, "Cole um texto OBUI1 de um amigo."),
  }
  return { { "Perfil ativo", active }, { "Por especialização", specs }, { "Por conteúdo", content },
    { "Presets", presets }, { "Compartilhar", share } }
end

-- Export/import text box over the panel.
local box = CreateFrame("Frame", "ObsidianUIProfileText", UIParent)
box:SetSize(560, 300)
box:SetPoint("CENTER")
box:SetFrameStrata("FULLSCREEN_DIALOG")
box:EnableMouse(true)
box:Hide()
fill(box, "BACKGROUND", 0.02, 0.025, 0.03, 0.97):SetAllPoints(box)
edge(box, 0.16)
local boxTitle = text(box, "GameFontNormal", WHITE)
boxTitle:SetPoint("TOPLEFT", box, "TOPLEFT", 14, -12)
local boxHelp = text(box, "GameFontDisableSmall", MUTED)
boxHelp:SetPoint("TOPLEFT", boxTitle, "BOTTOMLEFT", 0, -4)
local scroll = CreateFrame("ScrollFrame", "ObsidianUIProfileScroll", box, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", box, "TOPLEFT", 14, -52)
scroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -34, 46)
local edit = CreateFrame("EditBox", "ObsidianUIProfileEdit", scroll)
edit:SetMultiLine(true)
edit:SetAutoFocus(false)
edit:SetFontObject("GameFontHighlightSmall")
edit:SetWidth(500)
edit:SetScript("OnEscapePressed", function() box:Hide() end)
scroll:SetScrollChild(edit)
fill(scroll, "BACKGROUND", 0, 0, 0, 0.4):SetAllPoints(scroll)
local boxStatus = text(box, "GameFontHighlightSmall", DIM)
boxStatus:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 14, 16)
local apply = flatButton(box, "Importar", 110, function()
  local ok, result = pcall(ns.Profiles.Import, edit:GetText())
  if ok then
    boxStatus:SetText(result == "layout" and "Posições importadas." or "Perfil importado.")
    refreshPage()
  else
    boxStatus:SetText("Não deu para importar: o texto não é de um perfil da ObsidianUI.")
  end
end)
apply:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -126, 10)
local closeBox = flatButton(box, "Fechar", 100, function() box:Hide() end)
closeBox:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -14, 10)
Panel.textBox, Panel.textEdit, Panel.textApply, Panel.textStatus = box, edit, apply, boxStatus

function Panel.TextBox(mode, value)
  boxTitle:SetText(mode == "export" and "Exportar perfil" or "Importar perfil")
  boxHelp:SetText(mode == "export" and "Copie com Ctrl+C e mande para quem quiser." or "Cole o texto com Ctrl+V e clique em Importar.")
  edit:SetText(value or "")
  apply:SetShown(mode == "import")
  boxStatus:SetText("")
  box:Show()
  edit:SetFocus()
  if mode == "export" then edit:HighlightText() end
end

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

local function cycler(r, row)
  local holder = CreateFrame("Frame", nil, r)
  holder:SetSize(240, 26)
  holder:SetPoint("RIGHT", r, "RIGHT", 0, 0)
  local value = text(holder, "GameFontHighlight", WHITE)
  value:SetPoint("CENTER")
  value:SetJustifyH("CENTER")
  local function label(v)
    for _, o in ipairs(row.options()) do if o[1] == v then return o[2] end end
    return tostring(v)
  end
  local function draw() value:SetText(label(Panel.Get(row))) end
  local function step(dir)
    local list, current, at = row.options(), Panel.Get(row), 1
    for i, o in ipairs(list) do if o[1] == current then at = i end end
    local nxt = list[(at - 1 + dir) % #list + 1]
    Panel.Set(row, nxt[1])
    draw()
  end
  local prev = flatButton(holder, "<", 32, function() step(-1) end)
  prev:SetPoint("LEFT")
  local nxt = flatButton(holder, ">", 32, function() step(1) end)
  nxt:SetPoint("RIGHT")
  holder.prev, holder.next, holder.value = prev, nxt, value
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
  elseif row.kind == "cycle" then c = cycler(r, row)
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
    pageHeight(y)
  elseif sec.build then
    lead:SetText(sec.lead or "")
    for _, card in ipairs(sec.build()) do
      y = addHeading(card[1], y)
      for _, row in ipairs(card[2]) do y = addRow(row, y) end
      y = y - 10
    end
  else
    lead:SetText(sec.lead or "")
    for _, card in ipairs(sec.cards) do
      y = addHeading(card[1], y)
      for _, row in ipairs(card[2]) do y = addRow(row, y) end
      y = y - 10
    end
  end
  pageHeight(y)
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
  pageHeight(y)
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
