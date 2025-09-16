-- setup.lua — configuración interactiva
local function ask(label)
  term.setTextColor(colors.white)
  write(label..": ")
  return read()
end

local function runSetup()
  term.clear()
  term.setCursorPos(1,1)
  print("=== SETUP DRACONIC CONTROLLER ===")
  local cfg = {}
  cfg.reactor = ask("Nombre del reactor")
  cfg.monitor = ask("Nombre del monitor")
  cfg.in_gate = ask("Flux gate de entrada")
  cfg.out_gate = ask("Flux gate de salida")
  cfg.hudTheme = "minimalist"
  cfg.hudStyle = "CIRCLE"
  local file = fs.open("config.lua", "w")
  file.write("return "..textutils.serialize(cfg))
  file.close()
  print("Guardado en config.lua")
end

runSetup()
