local _, ns = ...

-- Keep a Blizzard frame where we put it. Blizzard code re-anchors many frames (UIParent's
-- position manager, Edit Mode); a post-hook on SetPoint puts it back. place(frame) does the
-- ClearAllPoints/SetPoint. Protected frames are only moved out of combat (once, not per move).
local pins = {}

local function apply(frame, entry)
  if frame:IsProtected() and InCombatLockdown() then
    if not entry.queued then
      entry.queued = true
      ns.RunOutOfCombat(function()
        entry.queued = false
        apply(frame, entry)
      end)
    end
    return
  end
  entry.applying = true
  entry.place(frame)
  entry.applying = false
end

function ns.Pin(frame, place)
  if not frame then return end
  local entry = pins[frame]
  if not entry then
    entry = { applying = false, queued = false }
    pins[frame] = entry
    hooksecurefunc(frame, "SetPoint", function(self)
      if not entry.applying then apply(self, entry) end
    end)
  end
  entry.place = place
  apply(frame, entry)
end
