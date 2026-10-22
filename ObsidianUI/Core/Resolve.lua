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
