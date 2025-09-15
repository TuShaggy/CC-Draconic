-- installer.lua - reinstala siempre desde GitHub
local base = "https://raw.githubusercontent.com/TuShaggy/CC-Draconic/main/"

local files = {
  "startup.lua",
  "lib/f.lua",
}

-- Borrar viejos
print("Limpiando archivos viejos...")
if fs.exists("startup.lua") then fs.delete("startup.lua") end
if fs.exists("config.lua") then fs.delete("config.lua") end
if fs.exists("lib") then fs.delete("lib") end
fs.makeDir("lib")

-- Descargar nuevos
for _,file in ipairs(files) do
  local url = base..file
  print("Descargando "..file.." ...")
  local h = http.get(url)
  if not h then
    print("ERROR al bajar "..file)
  else
    local out = fs.open(file,"w")
    out.write(h.readAll())
    out.close()
    h.close()
    print("OK -> "..file)
  end
end

print("Instalación completa.")
print("Escribe 'reboot' para reiniciar y arrancar el controlador.")
