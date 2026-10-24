-- Minimal WoW UI layout engine for offline previews: frames, textures, font strings, status bars,
-- anchors (SetPoint/SetAllPoints/SetSize) and the few templates ObsidianUI uses. Everything else
-- falls back to a permissive stub. Coordinates are WoW's: origin bottom-left, y up.
local SCREEN_W, SCREEN_H = PREVIEW_W or 1920, PREVIEW_H or 1080

local stubmt = {}
local function newstub() return setmetatable({}, stubmt) end
local NUMERIC = { GetWidth = 32, GetHeight = 32, GetFrameLevel = 1, GetScale = 1 }
stubmt.__index = function(t, k)
  if NUMERIC[k] then local v = NUMERIC[k]; return function() return v end end
  local s = newstub(); rawset(t, k, s); return s
end
stubmt.__call = function() return newstub() end
local function zero() return 0 end
stubmt.__add, stubmt.__sub, stubmt.__mul, stubmt.__div, stubmt.__unm = zero, zero, zero, zero, zero
stubmt.__concat = function() return "" end

REGIONS = {}         -- every texture / font string / frame in creation order
local order = 0
local LAYERS = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4, HIGHLIGHT = 5 }
local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5 }

local Region = {}
Region.__index = function(t, k)
  local v = Region[k]
  if v ~= nil then return v end
  -- Unknown data fields are nil like real Lua; unknown methods / child regions become stubs.
  if type(k) == "string" and k:find("^%l") then return nil end
  local s = newstub(); rawset(t, k, s); return s
end

local function newRegion(kind, parent)
  order = order + 1
  local r = setmetatable({ kind = kind, points = {}, w = 0, h = 0, shown = true, parent = parent,
    order = order, alpha = 1, attrs = {}, handlers = {}, hooks = {}, vc = { 1, 1, 1, 1 } }, Region)
  REGIONS[#REGIONS + 1] = r
  return r
end

-- Anchors ---------------------------------------------------------------------------------------
function Region:ClearAllPoints() self.points = {}; self.all = nil end
function Region:SetAllPoints(rel) self.points = {}; self.all = rel or self.parent end
function Region:SetPoint(point, a, b, c, d)
  local rel, relPoint, x, y = self.parent, point, 0, 0
  if type(a) == "number" then x, y = a, b or 0
  elseif a ~= nil then
    rel = a
    if type(b) == "string" then relPoint, x, y = b, c or 0, d or 0
    elseif type(b) == "number" then x, y = b, c or 0 end
  end
  if type(rel) == "string" then rel = _G[rel] end
  self.all = nil
  for i, p in ipairs(self.points) do if p.point == point then table.remove(self.points, i) break end end
  table.insert(self.points, { point = point, rel = rel or UIParent, relPoint = relPoint, x = x, y = y })
end
function Region:GetPoint(i)
  local p = self.points[i or 1]
  if p then return p.point, p.rel, p.relPoint, p.x, p.y end
end
function Region:SetSize(w, h) self.w, self.h = w or 0, h or 0 end
function Region:SetWidth(w) self.w = w or 0; self.fixedW = true end
function Region:SetHeight(h) self.h = h or 0 end

local function pointXY(rect, point)
  local l, b, w, h = rect[1], rect[2], rect[3], rect[4]
  local x, y = l + w / 2, b + h / 2
  if point:find("LEFT") then x = l elseif point:find("RIGHT") then x = l + w end
  if point:find("TOP") then y = b + h elseif point:find("BOTTOM") then y = b end
  return x, y
end

-- A frame's size and anchor offsets are in its own scale: the product of its and its parents'.
function Region:EffScale()
  local s, r, n = 1, self, 0
  while r and r ~= UIParent and n < 60 do s = s * (r.scale or 1); r = r.parent; n = n + 1 end
  return s
end

function Region:Rect(depth)
  depth = (depth or 0) + 1
  if self == UIParent or depth > 60 then return { 0, 0, SCREEN_W, SCREEN_H } end
  if self.statusbarOf then
    local bar = self.statusbarOf
    local br = bar:Rect(depth)
    local lo, hi = bar.min or 0, bar.max or 1
    local f = (hi > lo) and math.max(0, math.min(1, ((bar.value or 0) - lo) / (hi - lo))) or 0
    if bar.orientation == "VERTICAL" then return { br[1], br[2], br[3], br[4] * f } end
    if bar.reverse then return { br[1] + br[3] * (1 - f), br[2], br[3] * f, br[4] } end
    return { br[1], br[2], br[3] * f, br[4] }
  end
  if self.all then return self.all:Rect(depth) end
  if #self.points == 0 then
    if self.parent and self.parent.Rect then
      local pr = self.parent:Rect(depth)
      local es = self:EffScale()
      return { pr[1], pr[2], self.w * es, self.h * es }
    end
    local es = self:EffScale()
    return { 0, 0, self.w * es, self.h * es }
  end
  local left, right, top, bottom, cx, cy
  local es = self:EffScale()
  for _, p in ipairs(self.points) do
    local rel = p.rel
    local rr = (rel and rel.Rect) and rel:Rect(depth) or { 0, 0, SCREEN_W, SCREEN_H }
    local ax, ay = pointXY(rr, p.relPoint)
    ax, ay = ax + p.x * es, ay + p.y * es
    if p.point:find("LEFT") then left = ax elseif p.point:find("RIGHT") then right = ax else cx = ax end
    if p.point:find("TOP") then top = ay elseif p.point:find("BOTTOM") then bottom = ay else cy = ay end
  end
  local w, h = self.w * es, self.h * es
  if left and right then w = right - left elseif left then right = left + w elseif right then left = right - w
  elseif cx then left = cx - w / 2 end
  if top and bottom then h = top - bottom elseif bottom then top = bottom + h elseif top then bottom = top - h
  elseif cy then bottom = cy - h / 2 end
  left, bottom = left or 0, bottom or 0
  if self.statusbarOf then
    local bar = self.statusbarOf
    local lo, hi = bar.min or 0, bar.max or 1
    local f = (hi > lo) and math.max(0, math.min(1, ((bar.value or 0) - lo) / (hi - lo))) or 0
    if bar.orientation == "VERTICAL" then h = h * f else w = w * f end
  end
  return { left, bottom, w, h }
end
-- Like the game: sizes and positions in the frame's own scale (screen units / effective scale).
function Region:GetSize() local r, es = self:Rect(), self:EffScale(); return r[3] / es, r[4] / es end
function Region:GetWidth() return self:Rect()[3] / self:EffScale() end
function Region:GetHeight() return self:Rect()[4] / self:EffScale() end
function Region:GetBottom() return self:Rect()[2] / self:EffScale() end
function Region:GetTop() local r = self:Rect(); return (r[2] + r[4]) / self:EffScale() end
function Region:GetLeft() return self:Rect()[1] / self:EffScale() end
function Region:GetRight() local r = self:Rect(); return (r[1] + r[3]) / self:EffScale() end

-- Visibility / hierarchy ------------------------------------------------------------------------
function Region:Show() self.shown = true; if self.handlers.OnShow then self.handlers.OnShow(self) end end
function Region:Hide() self.shown = false end
function Region:SetShown(v) if v then self:Show() else self:Hide() end end
function Region:IsShown() return self.shown end
function Region:IsVisible()
  local r = self
  while r do if not r.shown then return false end r = r.parent end
  return true
end
local OBJECT_TYPES = { frame = "Frame", texture = "Texture", font = "FontString", mask = "MaskTexture" }
function Region:GetObjectType() return OBJECT_TYPES[self.kind] or "Frame" end
local function kids(self, frames)
  local out = {}
  for _, r in ipairs(REGIONS) do
    if r.parent == self and (r.kind == "frame") == frames then out[#out + 1] = r end
  end
  return (table.unpack or unpack)(out)
end
function Region:GetChildren() return kids(self, true) end
function Region:GetRegions() return kids(self, false) end
function Region:SetParent(p) self.parent = p end
function Region:GetParent() return self.parent end
function Region:SetAlpha(a) self.alpha = a end
function Region:GetAlpha() return self.alpha or 1 end
function Region:IsMouseOver() return false end -- the preview has no mouse
function Region:SetAlphaFromBoolean(b, yes, no) self.alpha = b and (yes or 1) or (no or 0) end
function Region:SetFrameLevel(l) self.level = l end
function Region:GetFrameLevel()
  if self.level then return self.level end
  return self.parent and self.parent.GetFrameLevel and (self.parent:GetFrameLevel() + 1) or 0
end
function Region:SetFrameStrata(s) self.strata = s end
function Region:GetStrata()
  local r = self
  while r do if r.strata then return r.strata end r = r.parent end
  return "MEDIUM"
end
function Region:GetName() return self.name end
function Region:IsProtected() return false end
function Region:SetScale(s) self.scale = s end
function Region:GetScale() return self.scale or 1 end
function Region:GetEffectiveScale() return self:EffScale() end
function Region:SetMovable() end
function Region:StartMoving() end
function Region:StopMovingOrSizing() end
function Region:EnableMouseWheel() end
function Region:RegisterForDrag() end
-- ScrollFrame: the game pins the scroll child to the scroll frame's top-left corner.
function Region:SetScrollChild(child)
  self.scrollChild = child
  child.points = { { point = "TOPLEFT", rel = self, relPoint = "TOPLEFT", x = 0, y = self.vscroll or 0 } }
end
function Region:SetVerticalScroll(v)
  self.vscroll = v
  if self.scrollChild then self.scrollChild.points[1].y = v end
end
function Region:GetVerticalScroll() return self.vscroll or 0 end

-- Scripts / attributes --------------------------------------------------------------------------
function Region:SetScript(name, fn) self.handlers[name] = fn end
function Region:GetScript(name) return self.handlers[name] end
function Region:HookScript(name, fn) self.hooks[name] = fn end
function Region:SetAttribute(k, v)
  self.attrs[k] = v
  if self.hooks.OnAttributeChanged then self.hooks.OnAttributeChanged(self, k, v) end
end
function Region:GetAttribute(k) return self.attrs[k] end
function Region:RegisterEvent(ev) PREVIEW_EVENTS[#PREVIEW_EVENTS + 1] = { frame = self, event = ev } end

-- Textures --------------------------------------------------------------------------------------
function Region:CreateTexture(name, layer, template, sub)
  local t = newRegion("texture", self)
  t.layer, t.sub = layer or "ARTWORK", sub or 0
  if name then _G[name] = t end
  return t
end
function Region:CreateMaskTexture() local m = newRegion("mask", self); m.shown = false; return m end
function Region:CreateFontString(name, layer, font)
  local f = newRegion("font", self)
  f.layer, f.font, f.text, f.justify = layer or "OVERLAY", font, "", "CENTER"
  if name then _G[name] = f end
  return f
end
function Region:SetTexture(file) self.file = file; self.color = nil end
function Region:GetTexture() return self.file end
function Region:SetAtlas(a) self.file = "ATLAS:" .. tostring(a) end
function Region:SetColorTexture(r, g, b, a) self.color = { r, g, b, a or 1 }; self.file = nil end
function Region:SetTexCoord(...) self.tc = { ... } end
function Region:SetVertexColor(r, g, b, a) self.vc = { r, g, b, a or 1 } end
function Region:SetDesaturated(v) self.desat = v end
function Region:SetBlendMode(m) self.blend = m end
function Region:SetRotation(a) self.rot = a end
function Region:SetClipsChildren(v) self.clips = v end
function Region:SetGradient(orientation, minColor, maxColor) self.grad = { orientation, minColor, maxColor } end
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end
function Region:AddMaskTexture(m) self.mask = m end

-- Font strings ----------------------------------------------------------------------------------
-- Font strings size themselves to their text in the game; approximate that.
local FONT_PX = { GameFontNormalLarge = 17, GameFontNormal = 14, GameFontNormalSmall = 12, GameFontHighlight = 14,
  GameFontHighlightSmall = 12, NumberFontNormalSmall = 11, NumberFontNormal = 13 }
local function autosize(self)
  if self.fixedW or self.ftype == "EditBox" then return end -- an edit box keeps its size, like the game
  local px = self.fsize or FONT_PX[self.font] or 12
  self.w, self.h = #(self.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) * px * 0.56, px + 2
end
function Region:SetText(t) self.text = t and tostring(t) or ""; autosize(self) end
function Region:GetText() return self.text or "" end
function Region:GetStringWidth() return #(self.text or "") * (self.fsize or FONT_PX[self.font] or 12) * 0.55 end
function Region:SetFormattedText(fmt, ...) self.text = string.format(fmt, ...); autosize(self) end
function Region:SetTextColor(r, g, b) self.tcolor = { r, g, b } end
function Region:GetTextColor() local c = self.tcolor or { 1, 1, 1 }; return c[1], c[2], c[3] end
function Region:SetJustifyH(j) self.justify = j end
function Region:SetFont(path, size, flags) self.fsize = size; self.fontPath, self.fontFlags = path, flags; autosize(self) end
function Region:GetFont() return self.fontPath or "PREVIEW", self.fsize or FONT_PX[self.font] or 12, self.fontFlags or "" end
function Region:SetWordWrap(v) self.nowrap = not v end

-- Status bars -----------------------------------------------------------------------------------
function Region:SetMinMaxValues(a, b) self.min, self.max = a, b end
function Region:SetValue(v) self.value = v end
function Region:GetMinMaxValues() return self.min or 0, self.max or 1 end
function Region:GetValue() return self.value or 0 end
function Region:SetOrientation(o) self.orientation = o end
function Region:SetReverseFill(r) self.reverse = r end
function Region:GetStatusBarTexture()
  if not self.barTex then
    self.barTex = self:CreateTexture(nil, "ARTWORK")
    self.barTex.points = { { point = "BOTTOMLEFT", rel = self, relPoint = "BOTTOMLEFT", x = 0, y = 0 } }
    self.barTex.statusbarOf = self
    self.barTex.w, self.barTex.h = 0, 0
    self.barTex.sizeFrom = self
  end
  return self.barTex
end
function Region:SetStatusBarTexture(file) self:GetStatusBarTexture():SetTexture(file) end
function Region:SetStatusBarColor(r, g, b, a) self:GetStatusBarTexture():SetVertexColor(r, g, b, a) end

-- Frames & templates ----------------------------------------------------------------------------
-- Cooldown frames: the countdown settings the game offers, and its countdown text.
function Region:SetHideCountdownNumbers(v) self.hideNumbers = v end
function Region:SetCooldown(start, duration) self.cdStart, self.cdDuration = start, duration end
function Region:Clear() self.cdStart, self.cdDuration = nil, nil end
function Region:SetMinimumCountdownDuration(ms) self.minCountdown = ms end
function Region:SetCountdownMillisecondsThreshold(s) self.msThreshold = s end
function Region:GetCountdownFontString()
  if not self.countdownText then
    self.countdownText = self:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.countdownText:SetPoint("CENTER", self, "CENTER")
  end
  return self.countdownText
end

function CreateFrame(ftype, name, parent, template)
  local f = newRegion("frame", parent or UIParent)
  f.ftype, f.name, f.template = ftype, name, template
  if name then _G[name] = f end
  -- The game clips a scroll frame's content to its own rect.
  if ftype == "ScrollFrame" then f.clips = true end
  if template and template:find("ActionBarButtonTemplate") then
    f.icon = f:CreateTexture(nil, "ARTWORK"); f.icon:SetAllPoints(f)
    f.cooldown = CreateFrame("Cooldown", name and (name .. "Cooldown") or nil, f); f.cooldown:SetAllPoints(f)
    f.HotKey = f:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    f.HotKey:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2); f.HotKey.justify = "RIGHT"
    f.UpdateAction = function(self) self.icon:SetTexture(GetActionTexture(self.attrs.action)) end
  elseif template and template:find("ContainerFrameItemButtonTemplate") then
    f.icon = f:CreateTexture(nil, "ARTWORK"); f.icon:SetAllPoints(f)
    f.Cooldown = CreateFrame("Cooldown", name and (name .. "Cooldown") or nil, f); f.Cooldown:SetAllPoints(f)
    f.Count = f:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    f.Count:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2); f.Count.justify = "RIGHT"
  elseif template and template:find("SecureAuraHeaderTemplate") then
    f.isAuraHeader = true
  elseif template and template:find("UIPanelButtonTemplate") then
    f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); f.label:SetAllPoints(f)
    local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(f); bg:SetColorTexture(0.25, 0.05, 0.03, 0.95)
    f.SetText = function(self, t) self.label:SetText(t) end
  end
  if template and template:find("BackdropTemplate") then
    -- Flat fill plus four 1px edges, like a WHITE8X8 backdrop with edgeSize 1.
    f.SetBackdrop = function(self)
      if self.bdBg then return end
      self.bdBg = self:CreateTexture(nil, "BACKGROUND"); self.bdBg:SetAllPoints(self)
      self.bdEdges = {}
      for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = self:CreateTexture(nil, "BORDER")
        if side == "TOP" or side == "BOTTOM" then
          t:SetPoint(side .. "LEFT", self, side .. "LEFT"); t:SetPoint(side .. "RIGHT", self, side .. "RIGHT"); t:SetHeight(1)
        else
          t:SetPoint("TOP" .. side, self, "TOP" .. side); t:SetPoint("BOTTOM" .. side, self, "BOTTOM" .. side); t:SetWidth(1)
        end
        self.bdEdges[#self.bdEdges + 1] = t
      end
    end
    f.SetBackdropColor = function(self, r, g, b, a) if self.bdBg then self.bdBg:SetColorTexture(r, g, b, a) end end
    f.SetBackdropBorderColor = function(self, r, g, b, a)
      for _, t in ipairs(self.bdEdges or {}) do t:SetColorTexture(r, g, b, a) end
    end
  end
  if ftype == "StatusBar" then f.min, f.max, f.value = 0, 1, 0 end
  return f
end

-- Blizzard frames the addon touches -------------------------------------------------------------
UIParent = setmetatable({ kind = "frame", points = {}, w = SCREEN_W, h = SCREEN_H, shown = true, order = 0,
  attrs = {}, handlers = {}, hooks = {}, vc = { 1, 1, 1, 1 }, strata = "MEDIUM", level = 0 }, Region)
Minimap = CreateFrame("Frame", "Minimap", UIParent)
Minimap.isMinimap = true
PREVIEW_EVENTS = {}
function PREVIEW_FIRE(event, ...)
  for _, r in ipairs(PREVIEW_EVENTS) do
    local h = r.frame.handlers.OnEvent
    if r.event == event and h then h(r.frame, event, ...) end
  end
end

-- Aura headers: lay out a few children the way SecureAuraHeaderTemplate would.
function PREVIEW_FILL_AURAS(count)
  for _, f in ipairs(REGIONS) do
    if f.isAuraHeader then
      local n = f.attrs.filter == "HELPFUL" and count[1] or count[2]
      for i = 1, n do
        local c = CreateFrame("Button", nil, f, f.attrs.template)
        c:SetSize(26, 26)
        c:SetPoint("TOP", f, "TOP", (i - 1) * (f.attrs.xOffset or 30), 0)
        c.attrs.index = i
        f.attrs["child" .. i] = c
      end
    end
  end
end

setmetatable(_G, { __index = function(t, k)
  if type(k) == "string" and k:find("^ObsidianUI") then return nil end
  local s = newstub(); rawset(t, k, s); return s
end })
