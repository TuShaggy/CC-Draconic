-- lib/perutils.lua
local P = { cache = {} }

local function isAlive(obj)
  if type(obj) ~= "table" then return false end
  local ok, name = pcall(peripheral.getName, obj)
  return ok and name and peripheral.isPresent(name)
end

function P.get(nameOrType)
  assert(type(nameOrType) == "string" and #nameOrType > 0,
    "Peripheral name/type required")

  local cached = P.cache[nameOrType]
  if isAlive(cached) then return cached end

  if peripheral.isPresent(nameOrType) then
    local obj = peripheral.wrap(nameOrType)
    P.cache[nameOrType] = obj
    return obj
  end

  local found = peripheral.find(nameOrType)
  if found then
    P.cache[nameOrType] = found
    return found
  end

  error(("No se encontró periférico para '%s'"):format(nameOrType))
end

return P
