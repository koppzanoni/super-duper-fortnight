local _, ns = ...

-- State icons (combat or resting, group leader) at the top of the player's portrait. The level is
-- in the player frame's gold badge.
local ICONS = {
  combat = { file = "Interface\\CharacterFrame\\UI-StateIcon", coords = { 0.5, 1, 0, 0.49 } },
  rest = { file = "Interface\\CharacterFrame\\UI-StateIcon", coords = { 0, 0.5, 0, 0.421875 } },
  leader = { file = "Interface\\GroupFrame\\UI-Group-LeaderIcon", coords = { 0, 1, 0, 1 } },
}

local PlayerStatus = {}
ns.PlayerStatus = PlayerStatus

local holder = CreateFrame("Frame", nil, ns.HUD.over)
holder:SetFrameStrata("MEDIUM")
PlayerStatus.holder = holder
local slots = {}
for i = 1, 3 do slots[i] = holder:CreateTexture(nil, "OVERLAY") end

local function portrait()
  local player = ns.UnitFrames and ns.UnitFrames.frames.player
  return player and player.portrait
end

function PlayerStatus.Current()
  local leader = UnitIsGroupLeader and UnitIsGroupLeader("player")
  return ns.Data.PlayerStatusIcons(UnitAffectingCombat("player") == true, IsResting() == true, leader == true)
end

local function update()
  local list = PlayerStatus.Current()
  local h = holder:GetHeight()
  local size, gap = 0.16 * h, 2
  for i, t in ipairs(slots) do
    local key = list[i]
    if key then
      local icon = ICONS[key]
      t:SetTexture(icon.file)
      t:SetTexCoord(icon.coords[1], icon.coords[2], icon.coords[3], icon.coords[4])
      t:SetSize(size, size)
      t:ClearAllPoints()
      t:SetPoint("TOP", holder, "TOP", (i - (#list + 1) / 2) * (size + gap), -0.04 * h)
      t:Show()
    else
      t:Hide()
    end
  end
end

-- The player frame is made at login, after the first layout: placed again once it exists.
local function layout()
  local p = portrait()
  if not p then return end
  holder:ClearAllPoints()
  holder:SetAllPoints(p)
  update()
end

table.insert(ns.HUD.onResize, layout)
ns.On("PLAYER_ENTERING_WORLD", layout)
ns.On("PLAYER_LEVEL_UP", function()
  local player = ns.UnitFrames and ns.UnitFrames.frames.player
  if player then ns.UnitFrames.Update(player) end
end)
for _, ev in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_UPDATE_RESTING",
  "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED" }) do
  ns.On(ev, update)
end
