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

-- Bag search: plain, case-insensitive substring of the item name ("" matches everything).
function Filters.MatchesSearch(text, name)
  if not text or text == "" then return true end
  if not name then return false end
  return string.find(string.lower(name), string.lower(text), 1, true) ~= nil
end

-- Overlays for one bag slot. info: ContainerItemInfo or nil; quest: ItemQuestInfo or nil.
function Filters.Markers(info, quest, isNew)
  local m = { junk = false, quest = false, questStarter = false, new = false }
  if not info then return m end
  m.junk = info.quality == 0 and not info.hasNoValue
  if quest then
    m.questStarter = quest.questID ~= nil and not quest.isActive
    m.quest = quest.isQuestItem == true or m.questStarter
  end
  m.new = isNew == true
  return m
end
