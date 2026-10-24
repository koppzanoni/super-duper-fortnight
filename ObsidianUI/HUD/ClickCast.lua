local _, ns = ...

-- Click-casting on the group and raid frames: a spell for each modifier + mouse button, as the
-- frames' own secure attributes (shift-type1 = "spell", shift-spell1 = name), so a click casts it
-- on that member, in combat too. Left click still targets and right click opens the menu. The
-- attributes change out of combat only (protected frames). Saved in ns.db.clickcast[combo].
local ClickCast = {}
ns.ClickCast = ClickCast

-- { key, modifier prefix, mouse button, label }
ClickCast.COMBOS = {
  { "shift-1", "shift-", 1, "Shift + esquerdo" }, { "ctrl-1", "ctrl-", 1, "Ctrl + esquerdo" },
  { "alt-1", "alt-", 1, "Alt + esquerdo" }, { "shift-2", "shift-", 2, "Shift + direito" },
  { "ctrl-2", "ctrl-", 2, "Ctrl + direito" }, { "alt-2", "alt-", 2, "Alt + direito" },
  { "3", "", 3, "Botão do meio" }, { "4", "", 4, "Botão 4" }, { "5", "", 5, "Botão 5" },
}

local function spells() return ns.db and ns.db.clickcast or {} end

function ClickCast.Apply()
  ns.RunOutOfCombat(function()
    for _, f in ipairs(ns.GroupFrames.AllOwners()) do
      for _, c in ipairs(ClickCast.COMBOS) do
        local spell = spells()[c[1]]
        f:SetAttribute(c[2] .. "type" .. c[3], spell and "spell" or nil)
        f:SetAttribute(c[2] .. "spell" .. c[3], spell)
      end
    end
  end)
end

-- A combo's spell by name ("" or spaces clear it).
function ClickCast.Set(key, name)
  name = name and name:match("^%s*(.-)%s*$") or ""
  ns.db.clickcast = ns.db.clickcast or {}
  ns.db.clickcast[key] = name ~= "" and name or nil
  if ns.Profiles and ns.db.profiles then ns.Profiles.Save() end
  ClickCast.Apply()
end

-- The panel page (Settings/Panel.lua builds it when it opens).
function ClickCast.Cards()
  local rows = {}
  for i, c in ipairs(ClickCast.COMBOS) do
    local key = c[1]
    rows[#rows + 1] = { kind = "text", label = c[4], key = "cc_" .. key,
      get = function() return spells()[key] or "" end,
      set = function(v) ClickCast.Set(key, v) end,
      help = i == 1 and "O nome como no livro de magias." or nil }
  end
  return { { "Magias", rows } }
end

ns.On("PLAYER_LOGIN", ClickCast.Apply)
ns.On("GROUP_ROSTER_UPDATE", ClickCast.Apply) -- new cells get their attributes too
table.insert(ns.HUD.onResize, function() ClickCast.Apply() end)
