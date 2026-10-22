local _, ns = ...

-- Frame and API names differ between WoW builds; pick whichever candidate exists.
ns.Resolve = {}

function ns.Resolve.First(names, env)
  env = env or _G
  for _, name in ipairs(names) do
    local obj = env[name]
    if obj ~= nil then return obj, name end
  end
  return nil
end

-- _G.a.b.c, or nil as soon as one link is missing.
function ns.Resolve.Nested(...)
  local obj = _G
  for i = 1, select("#", ...) do
    obj = obj and obj[select(i, ...)]
  end
  return obj
end
