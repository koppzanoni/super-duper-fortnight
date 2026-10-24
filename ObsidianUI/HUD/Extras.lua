local _, ns = ...

-- Blizzard frames the HUD left homeless (their parent is hidden) or that would land on it:
-- LFG queue eye and instance difficulty in the minimap corners, durability doll beside the
-- minimap, loot rolls above the action bar stack, breath/fatigue timers under the debuffs.
local F = ns.Data.FRAME_CANDIDATES

local function find(key, ...)
  return ns.Resolve.First(F[key]) or (... and ns.Resolve.Nested(...))
end

local adopted = {}
-- Frames whose parent we hid live on the minimap container from now on.
local function adopt(frame)
  if not frame or adopted[frame] then return end
  adopted[frame] = true
  frame:SetParent(ns.Minimap.frame)
  if frame.SetFrameLevel then frame:SetFrameLevel(ns.Minimap.frame:GetFrameLevel() + 10) end
end

local function layout()
  local _, H = UIParent:GetSize()
  local map, w = ns.Minimap.frame, ns.Minimap.Width()

  local queue = find("queue")
  adopt(queue)
  ns.Pin(queue, function(f)
    f:ClearAllPoints()
    f:SetPoint("CENTER", map, "BOTTOMLEFT", 0.07 * w, 0.07 * w)
  end)

  local difficulty = find("difficulty", "MinimapCluster", "InstanceDifficulty")
  adopt(difficulty)
  ns.Pin(difficulty, function(f)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", map, "TOPLEFT", 0, 0)
  end)

  ns.Pin(find("durability"), function(f)
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", map, "TOPLEFT", -4, -0.25 * w)
  end)

  ns.Pin(find("lootrolls"), function(f)
    f:ClearAllPoints()
    f:SetPoint("BOTTOM", ns.Stack.Anchor(), "TOP", 0, 260)
  end)

  ns.Pin(find("mirrortimers"), function(f)
    f:ClearAllPoints()
    f:SetPoint("TOP", UIParent, "TOP", 0, -0.16 * H)
  end)
end

table.insert(ns.HUD.onResize, function() ns.RunOutOfCombat(layout) end)
