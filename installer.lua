-- installer.lua — descarga todos los módulos del controlador
local base = "https://raw.githubusercontent.com/TuShaggy/CC-Draconic/main/"

local files = {
  "startup.lua",
  "reactor.lua",
  "setup.lua",
  "ui.lua",
  "lib/f.lua",
}

print("Preparando directorios...")
if fs.exists("lib") then fs.delete("lib") end
fs.makeDir("lib")

for _,file in ipairs(files) do
  local url = base..file
  print("Descargando "..file.." ...")
  local h = http.get(url)
  if h then
    local out = fs.open(file,"w")
    out.write(h.readAll())
    out.close()
    h.close()
    print("OK -> "..file)
  else
    print("ERROR al bajar "..file)
  end
end

print("Instalación completa. Ejecuta 'reboot' para arrancar el controlador.")
