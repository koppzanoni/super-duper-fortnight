local _, ns = ...

-- Textures are padded to powers of two; draw only the real image area.
ns.Media = {}

-- Draw the horizontal slice x0..x1 (fractions of the image width), flipped when mirror.
function ns.Media.ApplyRange(texture, name, mirror, x0, x1)
  local m = ns.MediaManifest[name]
  local left, right = (m.w / m.potW) * x0, (m.w / m.potW) * x1
  local bottom = m.h / m.potH
  texture:SetTexture(m.file)
  if mirror then
    texture:SetTexCoord(right, left, 0, bottom)
  else
    texture:SetTexCoord(left, right, 0, bottom)
  end
end

-- widthFraction (0..1) draws only the left part of the image (used to cut the last connector tile).
function ns.Media.Apply(texture, name, mirror, widthFraction)
  ns.Media.ApplyRange(texture, name, mirror, 0, widthFraction or 1)
end
