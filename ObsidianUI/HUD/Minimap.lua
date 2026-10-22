local _, ns = ...

-- Round minimap in the thin stone ring (spec 7.1), top-right corner.
local S = ns.Data.MINIMAP
local WIDTH = 0.222 -- of the screen height
local container = CreateFrame("Frame", "ObsidianUIMinimap", UIParent)
container:SetFrameStrata("LOW")
ns.Minimap = { frame = container }

function ns.Minimap.Width()
  local _, H = UIParent:GetSize()
  return WIDTH * H
end
local ringFrame = CreateFrame("Frame", nil, container)
local ring = ringFrame:CreateTexture(nil, "ARTWORK")
ring:SetAllPoints(container)
local zone = ringFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
zone:SetTextColor(0.91, 0.77, 0.42)
local sockets = {}
for i = 1, 4 do sockets[i] = CreateFrame("Frame", nil, ringFrame) end

local function socketTargets()
  return {
    ns.Resolve.First(ns.Data.FRAME_CANDIDATES.clock),
    ns.Resolve.First(ns.Data.FRAME_CANDIDATES.mail) or ns.Resolve.Nested("MinimapCluster", "IndicatorFrame", "MailFrame"),
    ns.Resolve.First(ns.Data.FRAME_CANDIDATES.tracking) or ns.Resolve.Nested("MinimapCluster", "Tracking"),
    ns.Resolve.First(ns.Data.FRAME_CANDIDATES.calendar),
  }
end

local function updateZone() zone:SetText(GetMinimapZoneText() or "") end

local function layout()
  local _, H = UIParent:GetSize()
  local w = WIDTH * H
  local u = w / S.w
  container:ClearAllPoints()
  container:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -0.012 * H, -0.02 * H)
  container:SetSize(w, S.h * u)
  ns.Media.Apply(ring, "minimap_ring")

  Minimap:SetParent(container)
  Minimap:ClearAllPoints()
  Minimap:SetPoint("TOPLEFT", container, "TOPLEFT", S.map.x * u, -S.map.y * u)
  Minimap:SetSize(S.map.w * u, S.map.h * u)
  Minimap:SetMaskTexture(ns.MediaManifest.mask_circle.file)
  Minimap:SetFrameLevel(container:GetFrameLevel() + 1)
  ringFrame:SetFrameLevel(Minimap:GetFrameLevel() + 5)

  zone:ClearAllPoints()
  zone:SetPoint("CENTER", container, "TOPLEFT", (S.plate.x + S.plate.w / 2) * u, -(S.plate.y + S.plate.h / 2) * u)
  zone:SetWidth(S.plate.w * u * 0.92)

  local targets = socketTargets()
  for i, s in ipairs(sockets) do
    local cx, cy = S.sockets[i][1], S.sockets[i][2]
    s:ClearAllPoints()
    s:SetPoint("CENTER", container, "TOPLEFT", cx * u, -cy * u)
    s:SetSize(S.socketSize * u, S.socketSize * u)
    local t = targets[i]
    if t then
      t:SetParent(s)
      t:ClearAllPoints()
      t:SetPoint("CENTER", s, "CENTER")
      t:SetScale(math.max(0.35, (S.socketSize * u) / math.max(1, t:GetWidth())) * 0.9)
    end
  end
end

local function hideDefault()
  for _, key in ipairs({ "MinimapBackdrop", "MinimapBorder", "MinimapBorderTop", "MinimapCompassTexture",
    "MinimapZoomIn", "MinimapZoomOut", "MinimapZoneTextButton", "MiniMapWorldMapButton" }) do
    local f = _G[key]
    if f and f.Hide then f:Hide() end
  end
  if Minimap.ZoomIn then Minimap.ZoomIn:Hide() end
  if Minimap.ZoomOut then Minimap.ZoomOut:Hide() end
  local cluster = ns.Resolve.First(ns.Data.FRAME_CANDIDATES.minimapcluster)
  if cluster then
    if cluster.BorderTop then cluster.BorderTop:Hide() end
    if cluster.ZoneTextButton then cluster.ZoneTextButton:Hide() end
    ns.HideFrame(cluster)
  end
end

Minimap:EnableMouseWheel(true)
Minimap:SetScript("OnMouseWheel", function(_, delta)
  if delta > 0 then
    if Minimap.ZoomIn then Minimap.ZoomIn:Click() elseif Minimap_ZoomIn then Minimap_ZoomIn() end
  else
    if Minimap.ZoomOut then Minimap.ZoomOut:Click() elseif Minimap_ZoomOut then Minimap_ZoomOut() end
  end
end)

ns.On("PLAYER_LOGIN", function()
  ns.RunOutOfCombat(function()
    layout()
    hideDefault()
    updateZone()
  end)
end)
for _, ev in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do
  ns.On(ev, updateZone)
end
table.insert(ns.HUD.onResize, function() ns.RunOutOfCombat(layout) end)
