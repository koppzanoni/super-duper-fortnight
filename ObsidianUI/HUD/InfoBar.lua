local _, ns = ...

-- Info bar (ElvUI's datatexts idea): what the player checks all the time in one strip, above the
-- menu by default and movable in the edit mode. Each item can be switched off on its page; the
-- alert colours turn a low FPS, a high latency or worn gear yellow or red.
local InfoBar = { texts = {} }
ns.InfoBar = InfoBar

InfoBar.ITEMS = {
  { "fps", "FPS", true }, { "ms", "Latência", true }, { "dur", "Durabilidade", true }, { "bags", "Bolsas", true },
  { "gold", "Ouro", false }, { "friends", "Amigos online", true }, { "guild", "Guilda online", false },
  { "clock", "Hora", true },
}

local GOOD, WARN, BAD, PLAIN = { 0.43, 0.88, 0.48 }, { 0.94, 0.78, 0.38 }, { 0.95, 0.32, 0.28 }, { 0.92, 0.93, 0.95 }
local PAD, GAP, H = 10, 18, 26

local frame = CreateFrame("Frame", "ObsidianUIInfoBar", UIParent)
frame:SetFrameStrata("LOW")
frame:SetHeight(H)
InfoBar.frame = frame
local bg = frame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(frame)
bg:SetColorTexture(0.015, 0.02, 0.028, 0.6)

for _, item in ipairs(InfoBar.ITEMS) do
  local t = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  t:SetJustifyH("LEFT")
  InfoBar.texts[item[1]] = t
end

local function on(key, default)
  local v = ns.db and ns.db["info_" .. key]
  if v == nil then return default end
  return v
end

local function color(t, c) t:SetTextColor(c[1], c[2], c[3]) end

local function durability()
  local low
  for slot = 1, 18 do
    local cur, max = GetInventoryItemDurability(slot)
    if cur and max and max > 0 then
      local p = cur / max
      if not low or p < low then low = p end
    end
  end
  return low
end

local function freeSlots()
  local free, total = 0, 0
  for bag = 0, 4 do
    local n = C_Container.GetContainerNumSlots(bag) or 0
    total = total + n
    free = free + (C_Container.GetContainerNumFreeSlots and C_Container.GetContainerNumFreeSlots(bag) or n)
  end
  return free, total
end

-- Every value is plain (never a secret): FPS, network, durability, bag slots, money, counts.
local VALUES = {
  fps = function(t)
    local f = math.floor((GetFramerate() or 0) + 0.5)
    t:SetFormattedText("FPS %d", f)
    color(t, f >= 45 and GOOD or (f >= 25 and WARN or BAD))
  end,
  ms = function(t)
    local _, _, home, world = GetNetStats()
    local ms = math.max(home or 0, world or 0)
    t:SetFormattedText("%d ms", ms)
    color(t, ms < 150 and GOOD or (ms < 300 and WARN or BAD))
  end,
  dur = function(t)
    local d = durability()
    if not d then t:SetText("Durab. --"); color(t, PLAIN); return end
    t:SetFormattedText("Durab. %d%%", math.floor(d * 100 + 0.5))
    color(t, d > 0.5 and PLAIN or (d > 0.25 and WARN or BAD))
  end,
  bags = function(t)
    local free, total = freeSlots()
    t:SetFormattedText("Bolsas %d/%d", free, total)
    color(t, free > 4 and PLAIN or (free > 0 and WARN or BAD))
  end,
  gold = function(t)
    t:SetText(GetMoneyString and GetMoneyString(GetMoney(), true) or tostring(math.floor(GetMoney() / 10000)) .. " o")
    color(t, PLAIN)
  end,
  friends = function(t)
    local n = C_FriendList and C_FriendList.GetNumOnlineFriends and C_FriendList.GetNumOnlineFriends() or 0
    t:SetFormattedText("Amigos %d", n)
    color(t, PLAIN)
  end,
  guild = function(t)
    local online = 0
    if IsInGuild and IsInGuild() then online = select(2, GetNumGuildMembers()) or 0 end
    t:SetFormattedText("Guilda %d", online)
    color(t, PLAIN)
  end,
  clock = function(t)
    t:SetText(date("%H:%M"))
    color(t, PLAIN)
  end,
}

function InfoBar.Update()
  if not frame:IsShown() then return end
  local x = PAD
  for _, item in ipairs(InfoBar.ITEMS) do
    local key, t = item[1], InfoBar.texts[item[1]]
    if on(key, item[3]) then
      local ok = pcall(VALUES[key], t)
      if not ok then t:SetText("") end
      ns.Look.SetFont(t, 12)
      t:ClearAllPoints()
      t:SetPoint("LEFT", frame, "LEFT", x, 0)
      t:Show()
      local w = tonumber(t:GetStringWidth()) or 60
      x = x + math.max(20, w) + GAP
    else
      t:Hide()
    end
  end
  frame:SetWidth(math.max(40, x - GAP + PAD))
end

-- Default: right above the menu row, bottom right (the free space beside the action bar).
local function layout()
  frame:SetShown(on("on", true))
  ns.Movers.Register("info", "Barra de informações", frame, function(f)
    f:ClearAllPoints()
    f:SetPoint("BOTTOMRIGHT", ns.MenuPanels.bandFrame, "TOPRIGHT", 0, 8)
  end)
  ns.Movers.Place("info")
  InfoBar.Update()
end
table.insert(ns.HUD.onResize, function() ns.RunOutOfCombat(layout) end)

for _, ev in ipairs({ "PLAYER_MONEY", "BAG_UPDATE_DELAYED", "UPDATE_INVENTORY_DURABILITY", "FRIENDLIST_UPDATE",
  "GUILD_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }) do
  ns.On(ev, InfoBar.Update)
end
-- FPS, latency and the clock change on their own: refreshed once a second.
local elapsed = 0
frame:SetScript("OnUpdate", function(_, dt)
  elapsed = elapsed + dt
  if elapsed < 1 then return end
  elapsed = 0
  InfoBar.Update()
end)
