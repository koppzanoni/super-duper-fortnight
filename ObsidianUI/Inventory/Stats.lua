local _, ns = ...

-- Rows for the inventory stats panel, grouped in sections. Stats this client leaves at zero
-- (haste, mastery, parry...) and sections left empty are dropped.
local Stats = {}
ns.Stats = Stats

local STAT_NAMES = { "Força", "Agilidade", "Vigor", "Intelecto", "Espírito" }
local PCT = "%.1f%%"

-- api: table of functions returning a number or nil (see GameAPI).
function Stats.Rows(api)
  local rows, sectionStart = {}, nil
  local function section(title)
    if sectionStart and #rows == sectionStart then rows[#rows] = nil end
    rows[#rows + 1] = { header = title }
    sectionStart = #rows
  end
  -- key/index: which stat the row shows (for its tooltip).
  local function row(label, v, fmt, optional, key, index)
    if type(v) ~= "number" or (optional and v == 0) then return end
    local text = fmt and string.format(fmt, v) or string.format("%d", math.floor(v + 0.5))
    rows[#rows + 1] = { label = label, value = text, key = key, index = index }
  end

  section("Primários")
  for i, name in ipairs(STAT_NAMES) do row(name, api.stat(i), nil, false, "stat", i) end
  section("Ataque")
  row("Poder de Ataque", api.attackPower(), nil, false, "attackPower")
  row("Crítico", api.crit(), PCT, false, "crit")
  row("Aceleração", api.haste(), PCT, true, "haste")
  row("Maestria", api.mastery(), PCT, true, "mastery")
  section("Magia")
  row("Poder Mágico", api.spellPower(), nil, true, "spellPower")
  row("Crítico Mágico", api.spellCrit(), PCT, true, "spellCrit")
  section("Defesa")
  row("Armadura", api.armor(), nil, false, "armor")
  row("Esquiva", api.dodge(), PCT, true, "dodge")
  row("Aparar", api.parry(), PCT, true, "parry")
  row("Bloqueio", api.block(), PCT, true, "block")
  if #rows == sectionStart then rows[#rows] = nil end
  return rows
end

-- The game's values, each read safely (missing API or error: nil, the row is skipped).
local function num(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, ...)
  if ok and type(v) == "number" then return v end
  return nil
end

local function second(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, _, v = pcall(fn, ...)
  if ok and type(v) == "number" then return v end
  return nil
end

function Stats.GameAPI()
  return {
    -- UnitStat/UnitArmor: the second value is the effective one (gear and buffs included).
    stat = function(i) return second(UnitStat, "player", i) end,
    armor = function() return second(UnitArmor, "player") end,
    attackPower = function()
      if type(UnitAttackPower) ~= "function" then return nil end
      local ok, base, pos, neg = pcall(UnitAttackPower, "player")
      if not ok or type(base) ~= "number" then return nil end
      return base + (pos or 0) + (neg or 0)
    end,
    crit = function() return num(GetCritChance) end,
    haste = function() return num(GetHaste) end,
    mastery = function() return num(GetMasteryEffect) end,
    spellPower = function()
      local best
      for school = 2, 7 do
        local v = num(GetSpellBonusDamage, school)
        if v and (not best or v > best) then best = v end
      end
      return best
    end,
    spellCrit = function() return num(GetSpellCritChance, 2) end,
    dodge = function() return num(GetDodgeChance) end,
    parry = function() return num(GetParryChance) end,
    block = function() return num(GetBlockChance) end,
  }
end
