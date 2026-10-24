local _, ns = ...

-- Visual settings shared by every HUD piece: font, outline, status bar texture, number format,
-- reaction and power colours. Modules ask Look when they draw; a change re-runs the layout
-- (Look.Apply), so nothing has to be reloaded.
local Look = {}
ns.Look = Look

-- The game's own fonts (present on every client). nil: keep each text's original font.
Look.FONTS = {
  { "default", "Padrão do jogo", nil },
  { "arial", "Arial estreita", "Fonts\\ARIALN.TTF" },
  { "friz", "Friz Quadrata", "Fonts\\FRIZQT__.TTF" },
  { "morpheus", "Morpheus", "Fonts\\MORPHEUS.TTF" },
  { "skurri", "Skurri", "Fonts\\SKURRI.TTF" },
}
Look.TEXTURES = {
  { "gloss", "Vidro" }, { "soft", "Suave" }, { "flat", "Lisa" }, { "blizzard", "Blizzard" },
}

local function db() return ns.db or {} end

function Look.Font()
  for _, f in ipairs(Look.FONTS) do
    if f[1] == db().font then return f[3] end
  end
  return nil
end

function Look.Outline()
  local o = db().outline
  if o == "NONE" then return "" end
  return o or "OUTLINE"
end

-- A text at `size`, in the chosen font and outline.
function Look.SetFont(text, size)
  local path, current = text:GetFont()
  path = Look.Font() or text.obOriginalFont or path
  text.obOriginalFont = text.obOriginalFont or (Look.Font() == nil and path) or nil
  if path then text:SetFont(path, math.max(9, math.floor((size or current or 12) + 0.5)), Look.Outline()) end
end

function Look.BarTexture()
  local t = db().barTex
  local M = ns.MediaManifest
  if t == "flat" then return "Interface\\Buttons\\WHITE8X8" end
  if t == "soft" then return M.bar_fill.file end
  if t == "blizzard" then return "Interface\\TargetingFrame\\UI-StatusBar" end
  return M.mod_gloss.file
end

-- "current / max" with the chosen format. The game's number functions take secret values too;
-- a failure (an older client) leaves the text to the caller's pcall.
function Look.Number(n)
  if db().numFmt == "full" and BreakUpLargeNumbers then return BreakUpLargeNumbers(n) end
  return AbbreviateNumbers(n)
end

-- A colour override from the Visual page ({r, g, b}), or nil.
function Look.Color(key)
  local c = db().colors and db().colors[key]
  if type(c) == "table" and c[1] then return c[1], c[2], c[3] end
  return nil
end

-- Everything again with the new look.
function Look.Apply()
  ns.Widgets.ApplyGlass()
  ns.RunOutOfCombat(function()
    ns.HUD.Layout()
    if ns.UnitFrames and ns.UnitFrames.RefreshAll then ns.UnitFrames.RefreshAll() end
  end)
end
