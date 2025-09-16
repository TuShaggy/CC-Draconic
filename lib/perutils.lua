-- lib/perutils.lua
-- Utilidad para envolver periféricos de forma segura

local P = { cache = {} }

local function isAlive(obj)
  if type(obj) ~= "table" then return false end
  local ok, name = pcall(peripheral.getName, obj)
  return ok and name and peripheral.isPresent(name)
end

--- Obtiene un periférico por nombre exacto o tipo
-- @param nameOrType string ("back", "draconic_reactor", "monitor", etc.)
function P.get(nameOrType)
  assert(type(nameOrType) == "string" and #nameOrType > 0,
    "Peripheral name/type required")

  -- Cache
  local cached = P.cache[nameOrType]
  if isAlive(cached) then return cached end

  -- Nombre/lado exacto
  if peripheral.isPresent(nameOrType) then
    local obj = peripheral.wrap(nameOrType)
    P.cache[nameOrType] = obj
    return obj
  end

  -- Tipo
  local found = peripheral.find(nameOrType)
  if found then
    P.cache[nameOrType] = found
    return found
  end

  error(("No se encontró periférico para '%s'"):format(nameOrType))
end

return P
