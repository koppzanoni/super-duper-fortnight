local _, ns = ...

-- Pure: which slots are visible in a tab, in what order, and where they go in the grid.
local GridModel = {}
ns.GridModel = GridModel

local MIN_ROWS = 6

-- slots: list of { bag, slot, classID } (classID nil = empty slot).
-- "all" keeps every slot (empty ones too) in bag/slot order; other tabs keep only matching items.
function GridModel.Build(slots, tab)
  local out = {}
  for _, s in ipairs(slots) do
    local cat = ns.Filters.Category(s.classID, s.bag)
    if tab == "all" or (s.classID ~= nil and cat == tab) or (tab == "reagent" and cat == "reagent") then
      out[#out + 1] = s
    end
  end
  table.sort(out, function(a, b)
    if a.bag ~= b.bag then return a.bag < b.bag end
    return a.slot < b.slot
  end)
  return out
end

function GridModel.Rows(n, cols)
  return math.max(MIN_ROWS, math.ceil(n / cols))
end

function GridModel.Pos(index, cols)
  return (index - 1) % cols + 1, math.floor((index - 1) / cols) + 1
end
