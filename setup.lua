-- setup.lua

local P = dofile("lib/perutils.lua")
local f = dofile("lib/f.lua")

local S = { step = 1, config = {} }

local steps = {
  { key="reactor", label="Selecciona el reactor (draconic_reactor)" },
  { key="monitor", label="Selecciona el monitor avanzado" },
  { key="in_gate", label="Selecciona flux gate de ENTRADA" },
  { key="out_gate", label="Selecciona flux gate de SALIDA" },
}

local function saveConfig()
  local h = fs.open("config.lua","w")
  h.write("return "..textutils.serialize(S.config))
  h.close()
end

function S.run()
  local mon = S.mon or term
  while S.step <= #steps do
    f.clear(mon, "minimalist")
    f.center(mon, 1, "SETUP - Paso "..S.step, "minimalist")
    f.center(mon, 3, steps[S.step].label, "minimalist")
    print("Periféricos detectados:")
    for _,p in ipairs(peripheral.getNames()) do
      print(" - "..p)
    end
    write("Introduce nombre: ")
    local name = read()
    S.config[steps[S.step].key] = name
    S.step = S.step + 1
  end
  saveConfig()
  print("✅ Configuración guardada en config.lua")
end

return S
