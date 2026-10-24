local _, ns = ...

-- Profiles (EllesmereUI's idea): named settings sets in ObsidianUIDB.profiles. ns.db keeps the
-- loaded profile's settings (the game's settings panel is bound to that table, so it stays the
-- same table); switching saves them into the active profile and loads the other one. Each
-- character remembers its profile, may have one per specialization, and one per kind of content
-- (solo, group, raid, PvP) when "automatic by content" is on. Presets, and export/import text.
local Profiles = {}
ns.Profiles = Profiles

local DEFAULT = "Padrão"
-- Account data that is not part of a profile.
local META = { profiles = true, chars = true, activeProfile = true, positioned = true }

local function copy(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, x in pairs(v) do t[k] = copy(x) end
  return t
end

local function charKey()
  return (UnitName("player") or "?") .. " - " .. ((GetRealmName and GetRealmName()) or "?")
end

local function char()
  local db = ns.db
  db.chars = db.chars or {}
  local key = charKey()
  db.chars[key] = db.chars[key] or {}
  local c = db.chars[key]
  c.spec, c.content = c.spec or {}, c.content or {}
  return c
end

function Profiles.Snapshot()
  local t = {}
  for k, v in pairs(ns.db) do
    if not META[k] then t[k] = copy(v) end
  end
  return t
end

local function loadInto(settings)
  for k in pairs(ns.db) do
    if not META[k] then ns.db[k] = nil end
  end
  for k, v in pairs(settings) do
    if not META[k] then ns.db[k] = copy(v) end
  end
  for k, v in pairs(ns.DEFAULTS) do
    if ns.db[k] == nil then ns.db[k] = copy(v) end
  end
end

function Profiles.Current() return ns.db.activeProfile end

function Profiles.Save()
  ns.db.profiles[ns.db.activeProfile] = Profiles.Snapshot()
end

function Profiles.List()
  local names = {}
  for name in pairs(ns.db.profiles) do names[#names + 1] = name end
  table.sort(names, function(a, b)
    if a == DEFAULT then return true end
    if b == DEFAULT then return false end
    return a < b
  end)
  return names
end

-- A new profile: a copy of `from`, or the default settings.
function Profiles.New(name, from)
  if type(name) ~= "string" or name == "" or ns.db.profiles[name] then return false end
  if from == ns.db.activeProfile then Profiles.Save() end
  ns.db.profiles[name] = copy(from and ns.db.profiles[from] or ns.DEFAULTS)
  return true
end

-- The default profile and the one in use are never deleted.
function Profiles.Delete(name)
  if name == DEFAULT or name == ns.db.activeProfile or not ns.db.profiles[name] then return false end
  ns.db.profiles[name] = nil
  return true
end

-- Re-apply everything after the settings changed under the HUD: layout, positions, bars, ring,
-- key bindings, cast bar, inventory. The colour builds textures at login: a change asks to reload.
function Profiles.ApplyLive(oldColor)
  if not ns.HUD.modernBar then return end -- before the first layout: login does it
  ns.RunOutOfCombat(function()
    ns.HUD.Layout()
    local player = ns.UnitFrames and ns.UnitFrames.frames.player
    if player and player.arcane then player.arcane:SetShown(ns.db.arcaneRing ~= false) end
    ns.ActionBars.UpdateBindings()
    if ns.CastBar.Refresh then ns.CastBar.Refresh() end
    if ns.Inventory and ns.Inventory.Layout then ns.Inventory.Layout() end
  end)
  if oldColor and oldColor ~= ns.db.modernColor then StaticPopup_Show("OBSIDIANUI_RELOAD") end
end

function Profiles.Switch(name)
  if not ns.db.profiles[name] or name == ns.db.activeProfile then return end
  local oldColor = ns.db.modernColor
  Profiles.Save()
  loadInto(ns.db.profiles[name])
  ns.db.activeProfile = name
  char().profile = name
  Profiles.ApplyLive(oldColor)
end

-- ------------------------------------------------------------------ automatic switching
function Profiles.SetSpecProfile(spec, name) char().spec[spec] = name end
function Profiles.SpecProfile(spec) return char().spec[spec] end

-- Where the player is: "pvp" (battleground, arena), "raid", "group" or "solo".
function Profiles.Content()
  local inside, kind = false, nil
  if IsInInstance then inside, kind = IsInInstance() end
  if inside and (kind == "pvp" or kind == "arena") then return "pvp" end
  if IsInRaid and IsInRaid() then return "raid" end
  if IsInGroup and IsInGroup() then return "group" end
  return "solo"
end
function Profiles.SetContentProfile(kind, name) char().content[kind] = name end
function Profiles.ContentProfile(kind) return char().content[kind] end
function Profiles.SetAutoContent(on) char().auto = on and true or false end
function Profiles.AutoContent() return char().auto == true end

local function bySpec()
  local spec = GetSpecialization and GetSpecialization()
  local name = spec and char().spec[spec]
  if name then Profiles.Switch(name) end
end
ns.On("PLAYER_SPECIALIZATION_CHANGED", function(_, unit) if unit == nil or unit == "player" then bySpec() end end)
ns.On("ACTIVE_TALENT_GROUP_CHANGED", bySpec)

local function byContent()
  if not Profiles.AutoContent() then return end
  local name = char().content[Profiles.Content()]
  if name then Profiles.Switch(name) end
end
ns.On("GROUP_ROSTER_UPDATE", byContent)
ns.On("PLAYER_ENTERING_WORLD", byContent)

-- ------------------------------------------------------------------ presets
Profiles.PRESET_ORDER = { "ObsidianUI", "Compacto", "Healer" }
Profiles.PRESETS = {
  ObsidianUI = { desc = "O layout padrão.", make = function()
    return { scale = 1, modernRows = 2, modernCols = 12, layout = false }
  end },
  Compacto = { desc = "Tudo menor, barra de 2x10.", make = function()
    return { scale = 0.85, modernRows = 2, modernCols = 10 }
  end },
  Healer = { desc = "Quadros perto do centro, para olhar o grupo.", make = function()
    local W, H = UIParent:GetSize()
    return { modernRows = 3, modernCols = 12, layout = {
      player = { x = W / 2 - 380, y = H * 0.42 }, target = { x = W / 2 + 20, y = H * 0.42 } } }
  end },
}

function Profiles.ApplyPreset(name)
  local preset = Profiles.PRESETS[name]
  if not preset then return end
  local oldColor = ns.db.modernColor
  for k, v in pairs(preset.make()) do
    if v == false and k == "layout" then ns.db.layout = nil else ns.db[k] = copy(v) end
  end
  Profiles.Save()
  Profiles.ApplyLive(oldColor)
end

-- ------------------------------------------------------------------ export / import
-- what: "all" (every setting and position) or "layout" (positions and sizes only).
function Profiles.Export(what)
  local data = what == "layout" and { layout = copy(ns.db.layout) } or Profiles.Snapshot()
  return ns.Serialize.Pack({ v = 1, what = what == "layout" and "layout" or "all", data = data })
end

function Profiles.Import(text)
  local t = ns.Serialize.Unpack(text)
  if type(t) ~= "table" or type(t.data) ~= "table" or (t.what ~= "all" and t.what ~= "layout") then
    error("not an ObsidianUI profile", 0)
  end
  local oldColor = ns.db.modernColor
  if t.what == "layout" then
    ns.db.layout = type(t.data.layout) == "table" and copy(t.data.layout) or nil
  else
    loadInto(t.data)
  end
  Profiles.Save()
  Profiles.ApplyLive(oldColor)
  return t.what
end

-- The whole saved data as text (what the game writes to disk), for tests.
function Profiles.Dump() return ns.Serialize.Encode(ns.db) end

-- ------------------------------------------------------------------ login
-- First run: the settings become the default profile. A character that had another profile gets
-- it back before anything is laid out (no reload needed).
ns.On("ADDON_LOADED", function(_, name)
  if name ~= ns.name or not ns.db then return end
  if type(ns.db.profiles) ~= "table" then
    ns.db.profiles = { [DEFAULT] = Profiles.Snapshot() }
    ns.db.activeProfile = DEFAULT
  end
  if not ns.db.profiles[ns.db.activeProfile or ""] then
    ns.db.activeProfile = DEFAULT
    ns.db.profiles[DEFAULT] = ns.db.profiles[DEFAULT] or Profiles.Snapshot()
  end
  local wanted = char().profile
  if wanted and wanted ~= ns.db.activeProfile and ns.db.profiles[wanted] then
    Profiles.Save()
    loadInto(ns.db.profiles[wanted])
    ns.db.activeProfile = wanted
  end
  char().profile = ns.db.activeProfile
end)

ns.On("PLAYER_LOGOUT", function() if ns.db and ns.db.profiles then Profiles.Save() end end)
