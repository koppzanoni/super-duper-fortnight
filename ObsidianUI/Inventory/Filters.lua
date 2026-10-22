local _, ns = ...

-- Pure: which inventory tab an item belongs to.
local Filters = {}
ns.Filters = Filters

Filters.TABS = { "all", "equip", "consumable", "material", "reagent" }
Filters.LABELS = { all = "Tudo", equip = "Equip.", consumable = "Consum.", material = "Materiais", reagent = "Reagentes" }

local REAGENT_BAG = 5
local BY_CLASS = { [2] = "equip", [4] = "equip", [0] = "consumable", [7] = "material", [5] = "material",
  [3] = "material", [8] = "material" }

function Filters.Category(classID, bagID)
  if bagID == REAGENT_BAG then return "reagent" end
  if classID == nil then return "other" end
  return BY_CLASS[classID] or "other"
end
