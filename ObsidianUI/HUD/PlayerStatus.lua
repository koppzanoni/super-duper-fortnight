local _, ns = ...

-- Level and state icons (combat or resting, group leader) at the top of the health orb,
-- standing in for the hidden player frame.
local ICONS = {
  combat = { file = "Interface\\CharacterFrame\\UI-StateIcon", coords = { 0.5, 1, 0, 0.49 } },
  rest = { file = "Interface\\CharacterFrame\\UI-StateIcon", coords = { 0, 0.5, 0, 0.421875 } },
  leader = { file = "Interface\\GroupFrame\\UI-Group-LeaderIcon", coords = { 0, 1, 0, 1 } },
}

local PlayerStatus = {}
ns.PlayerStatus = PlayerStatus

local well = ns.Orbs.health.well
local holder = CreateFrame("Frame", nil, ns.HUD.over)
PlayerStatus.holder = holder
holder:SetAllPoints(well)
local level = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
level:SetTextColor(0.91, 0.77, 0.42)
level:SetShadowOffset(1, -1)
local slots = {}
for i = 1, 3 do slots[i] = holder:CreateTexture(nil, "OVERLAY") end

function PlayerStatus.Current()
  local leader = UnitIsGroupLeader and UnitIsGroupLeader("player")
  return ns.Data.PlayerStatusIcons(UnitAffectingCombat("player") == true, IsResting() == true, leader == true)
end

local function update(newLevel)
  level:SetText("Nv " .. (tonumber(newLevel) or UnitLevel("player")))
  local list = PlayerStatus.Current()
  local h = well:GetHeight()
  local size, gap = 0.09 * h, 2
  for i, t in ipairs(slots) do
    local key = list[i]
    if key then
      local icon = ICONS[key]
      t:SetTexture(icon.file)
      t:SetTexCoord(icon.coords[1], icon.coords[2], icon.coords[3], icon.coords[4])
      t:SetSize(size, size)
      t:ClearAllPoints()
      t:SetPoint("TOP", holder, "TOP", (i - (#list + 1) / 2) * (size + gap), -0.22 * h)
      t:Show()
    else
      t:Hide()
    end
  end
end

local function layout()
  holder:SetShown(not ns.HUD.modern) -- Moderno: no orb; the player frame shows the level
  level:ClearAllPoints()
  level:SetPoint("TOP", holder, "TOP", 0, -0.11 * well:GetHeight())
  update()
end

table.insert(ns.HUD.onResize, layout)
ns.On("PLAYER_ENTERING_WORLD", function() update() end)
ns.On("PLAYER_LEVEL_UP", function(_, newLevel) update(newLevel) end)
for _, ev in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_UPDATE_RESTING",
  "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED" }) do
  ns.On(ev, function() update() end)
end
