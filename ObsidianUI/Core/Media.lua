local _, ns = ...

-- Textures are padded to powers of two; draw only the real image area.
ns.Media = {}

-- widthFraction (0..1) draws only the left part of the image (used to cut the last connector tile).
function ns.Media.Apply(texture, name, mirror, widthFraction)
  local m = ns.MediaManifest[name]
  local right = (m.w / m.potW) * (widthFraction or 1)
  local bottom = m.h / m.potH
  texture:SetTexture(m.file)
  if mirror then
    texture:SetTexCoord(right, 0, 0, bottom)
  else
    texture:SetTexCoord(0, right, 0, bottom)
  end
end
