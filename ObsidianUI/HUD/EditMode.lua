local _, ns = ...

-- Edit mode (EllesmereUI's Unlock Mode idea): a box over every HUD element (ns.Movers). Drag a box
-- to move its element; it sticks to the 8 px grid, to the screen's center and to the edges and
-- centers of the other elements (gold guide lines; Alt held = free). Mouse wheel resizes, arrows
-- nudge the selected element by 1 px (Shift: 10). Out of combat only: combat ends it.
-- /obui editar or the settings page starts it; Esc or the banner's button leaves.
local EditMode = { active = false, boxes = {} }
ns.EditMode = EditMode

local GRID, SNAP, STEP = 8, 6, 0.05
local TEAL, GOLD = { 0.35, 0.73, 0.84 }, { 0.94, 0.78, 0.38 }

local function screen() return UIParent:GetSize() end

-- Full-screen grid (every 32 px, the center lines in gold) and the two snap guides.
local grid = CreateFrame("Frame", nil, UIParent)
grid:SetAllPoints(UIParent)
grid:SetFrameStrata("DIALOG")
grid:Hide()
EditMode.grid = grid
local gridLines = {}
local function line(parent, color)
  local t = parent:CreateTexture(nil, "BACKGROUND")
  t:SetColorTexture(color[1], color[2], color[3], color[4])
  return t
end
local function drawGrid()
  local W, H = screen()
  for _, t in ipairs(gridLines) do t:Hide() end
  local n = 0
  local function add(vertical, pos, color)
    n = n + 1
    local t = gridLines[n] or line(grid, color)
    gridLines[n] = t
    t:SetColorTexture(color[1], color[2], color[3], color[4])
    t:ClearAllPoints()
    if vertical then
      t:SetPoint("TOPLEFT", grid, "TOPLEFT", pos, 0)
      t:SetPoint("BOTTOMLEFT", grid, "BOTTOMLEFT", pos, 0)
      t:SetWidth(1)
    else
      t:SetPoint("BOTTOMLEFT", grid, "BOTTOMLEFT", 0, pos)
      t:SetPoint("BOTTOMRIGHT", grid, "BOTTOMRIGHT", 0, pos)
      t:SetHeight(1)
    end
    t:Show()
  end
  for x = 32, W, 32 do add(true, x, { 1, 1, 1, 0.05 }) end
  for y = 32, H, 32 do add(false, y, { 1, 1, 1, 0.05 }) end
  add(true, W / 2, { GOLD[1], GOLD[2], GOLD[3], 0.3 })
  add(false, H / 2, { GOLD[1], GOLD[2], GOLD[3], 0.3 })
end
local guideX, guideY = line(grid, { GOLD[1], GOLD[2], GOLD[3], 0.9 }), line(grid, { GOLD[1], GOLD[2], GOLD[3], 0.9 })
guideX:SetDrawLayer("OVERLAY"); guideY:SetDrawLayer("OVERLAY")
guideX:SetWidth(1); guideY:SetHeight(1)
guideX:Hide(); guideY:Hide()

-- Banner: what to do, and the buttons to reset everything or leave.
local banner = CreateFrame("Frame", nil, UIParent)
banner:SetFrameStrata("FULLSCREEN_DIALOG")
banner:SetSize(560, 112)
banner:SetPoint("TOP", UIParent, "TOP", 0, -190)
banner:Hide()
local bannerBg = banner:CreateTexture(nil, "BACKGROUND")
bannerBg:SetAllPoints(banner)
bannerBg:SetColorTexture(0.02, 0.025, 0.03, 0.88)
local title = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", banner, "TOPLEFT", 14, -10)
title:SetText("Modo de edição")
title:SetTextColor(1, 1, 1)
local help = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
help:SetWidth(532)
help:SetJustifyH("LEFT")
help:SetText("Arraste para mover (Alt: sem grudar). Roda do mouse: tamanho. Setas: 1 px, Shift: 10 px.")
EditMode.selectedText = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
EditMode.selectedText:SetPoint("TOPLEFT", banner, "TOPLEFT", 14, -56)
EditMode.selectedText:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

local function button(text, x, onClick)
  local b = CreateFrame("Button", nil, banner, "UIPanelButtonTemplate")
  b:SetSize(100, 24)
  b:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", x, 8)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

-- ------------------------------------------------------------------ placing
local function others(key)
  local list = {}
  for _, k in ipairs(ns.Movers.order) do
    local item = ns.Movers.items[k]
    if k ~= key and item.box:IsVisible() then
      local r = ns.Movers.Rect(item.box)
      if r then list[#list + 1] = r end
    end
  end
  return list
end

local function syncBox(key)
  local box, item = EditMode.boxes[key], ns.Movers.items[key]
  local r = box and ns.Movers.Rect(item.box)
  if not r then return end
  box:ClearAllPoints()
  box:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", r.x, r.y)
  box:SetSize(math.max(r.w, 24), math.max(r.h, 16))
end

local function syncAll()
  for key in pairs(EditMode.boxes) do syncBox(key) end
end

local function apply(key)
  local item = ns.Movers.items[key]
  if item.ownScale then ns.HUD.Layout() else ns.Movers.Place(key) end
  syncAll()
end

-- Move an element so its box's top-left lands at (left, top) (UIParent units).
function EditMode.MoveTo(key, left, top)
  local item = ns.Movers.items[key]
  local box, frame = ns.Movers.Rect(item.box), ns.Movers.Rect(item.frame)
  if not (box and frame) then return end
  ns.Movers.Save(key, frame.x + left - box.x, frame.y + top - box.y)
  apply(key)
end

function EditMode.Resize(key, delta)
  local s = ns.Movers.Scale(key) + (delta > 0 and STEP or -STEP)
  s = math.max(0.5, math.min(2, math.floor(s * 100 + 0.5) / 100))
  local before = ns.Movers.Rect(ns.Movers.items[key].box)
  ns.Movers.Save(key, nil, nil, s)
  apply(key)
  -- a saved element keeps its top-left where it was
  if before and ns.Movers.Saved(key).x then EditMode.MoveTo(key, before.x, before.y) end
  EditMode.ShowSelected()
end

function EditMode.Nudge(dx, dy)
  local key = EditMode.selected
  local r = key and ns.Movers.Rect(ns.Movers.items[key].box)
  if r then EditMode.MoveTo(key, r.x + dx, r.y + dy) end
end

function EditMode.Center(key)
  local r = ns.Movers.Rect(ns.Movers.items[key].box)
  local W = screen()
  if r then EditMode.MoveTo(key, W / 2 - r.w / 2, r.y) end
end

function EditMode.Reset(key)
  ns.Movers.Forget(key)
  apply(key)
end

function EditMode.ResetAll()
  for _, key in ipairs(ns.Movers.order) do ns.Movers.Forget(key) end
  ns.HUD.Layout()
  for _, key in ipairs(ns.Movers.order) do ns.Movers.Place(key) end
  syncAll()
end

-- ------------------------------------------------------------------ boxes
function EditMode.ShowSelected()
  local key = EditMode.selected
  for k, box in pairs(EditMode.boxes) do
    local c = k == key and GOLD or TEAL
    for _, e in ipairs(box.edges) do e:SetColorTexture(c[1], c[2], c[3], 0.95) end
  end
  if key then
    EditMode.selectedText:SetFormattedText("%s — tamanho %d%%", ns.Movers.items[key].label, math.floor(ns.Movers.Scale(key) * 100 + 0.5))
  else
    EditMode.selectedText:SetText("Clique num elemento para selecionar.")
  end
end

function EditMode.Select(key)
  EditMode.selected = key
  EditMode.ShowSelected()
end

local dragging
local function onUpdate(box)
  if dragging ~= box then return end
  local k = UIParent:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  local left, top = cx / k - box.grabX, cy / k - box.grabY
  local W, H = screen()
  local gx, gy
  if not IsAltKeyDown() then
    local r = ns.Movers.Rect(ns.Movers.items[box.key].box)
    left, top, gx, gy = ns.Layout.Snap(left, top, r.w, r.h, others(box.key), GRID, SNAP, W, H)
  end
  guideX:SetShown(gx ~= nil); guideY:SetShown(gy ~= nil)
  if gx then guideX:ClearAllPoints(); guideX:SetPoint("TOPLEFT", grid, "TOPLEFT", gx, 0); guideX:SetPoint("BOTTOMLEFT", grid, "BOTTOMLEFT", gx, 0) end
  if gy then guideY:ClearAllPoints(); guideY:SetPoint("BOTTOMLEFT", grid, "BOTTOMLEFT", 0, gy); guideY:SetPoint("BOTTOMRIGHT", grid, "BOTTOMRIGHT", 0, gy) end
  EditMode.MoveTo(box.key, left, top)
end

local function makeBox(key)
  local item = ns.Movers.items[key]
  local box = CreateFrame("Button", nil, UIParent)
  box.key = key
  box:SetFrameStrata("DIALOG")
  box:SetFrameLevel(20)
  local fill = box:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints(box)
  fill:SetColorTexture(TEAL[1], TEAL[2], TEAL[3], 0.14)
  box.edges = {}
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local e = box:CreateTexture(nil, "BORDER")
    if side == "TOP" or side == "BOTTOM" then
      e:SetPoint(side .. "LEFT", box, side .. "LEFT"); e:SetPoint(side .. "RIGHT", box, side .. "RIGHT"); e:SetHeight(1)
    else
      e:SetPoint("TOP" .. side, box, "TOP" .. side); e:SetPoint("BOTTOM" .. side, box, "BOTTOM" .. side); e:SetWidth(1)
    end
    box.edges[#box.edges + 1] = e
  end
  local label = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetPoint("BOTTOMLEFT", box, "TOPLEFT", 2, 2)
  label:SetText(item.label)
  box:EnableMouse(true)
  box:EnableMouseWheel(true)
  box:SetScript("OnMouseDown", function(self, mouse)
    if mouse ~= "LeftButton" then return end
    EditMode.Select(key)
    local k = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    local r = ns.Movers.Rect(item.box)
    self.grabX, self.grabY = cx / k - r.x, cy / k - r.y
    dragging = self
  end)
  box:SetScript("OnMouseUp", function()
    dragging = nil
    guideX:Hide(); guideY:Hide()
  end)
  box:SetScript("OnUpdate", onUpdate)
  box:SetScript("OnMouseWheel", function(_, delta) EditMode.Select(key); EditMode.Resize(key, delta) end)
  box:Hide()
  return box
end

-- Arrows and Esc while the mode is on; every other key goes on to the game.
local catcher = CreateFrame("Frame", nil, UIParent)
catcher:SetAllPoints(UIParent)
catcher:SetFrameStrata("FULLSCREEN_DIALOG")
catcher:EnableKeyboard(false)
local ARROWS = { LEFT = { -1, 0 }, RIGHT = { 1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }
catcher:SetScript("OnKeyDown", function(self, key)
  local pass = true
  if key == "ESCAPE" then
    pass = false
    EditMode.Stop()
  elseif ARROWS[key] and EditMode.selected then
    pass = false
    local d = IsShiftKeyDown() and 10 or 1
    EditMode.Nudge(ARROWS[key][1] * d, ARROWS[key][2] * d)
  end
  if not InCombatLockdown() then self:SetPropagateKeyboardInput(pass) end
end)

button("Sair", -10, function() EditMode.Stop() end)
button("Restaurar tudo", -116, function() EditMode.ResetAll() end)
button("Centralizar", -222, function() if EditMode.selected then EditMode.Center(EditMode.selected) end end)
button("Restaurar", -328, function() if EditMode.selected then EditMode.Reset(EditMode.selected) end end)

function EditMode.Start()
  if InCombatLockdown() or EditMode.active then return end
  EditMode.active = true
  drawGrid()
  grid:Show()
  banner:Show()
  for _, key in ipairs(ns.Movers.order) do
    EditMode.boxes[key] = EditMode.boxes[key] or makeBox(key)
    EditMode.boxes[key]:Show()
  end
  syncAll()
  EditMode.Select(nil)
  catcher:EnableKeyboard(true)
  catcher:SetPropagateKeyboardInput(true)
end

function EditMode.Stop()
  EditMode.active = false
  dragging = nil
  grid:Hide()
  banner:Hide()
  guideX:Hide(); guideY:Hide()
  for _, box in pairs(EditMode.boxes) do box:Hide() end
  if not InCombatLockdown() then catcher:EnableKeyboard(false) end
end

ns.On("PLAYER_REGEN_DISABLED", function() if EditMode.active then EditMode.Stop() end end)
