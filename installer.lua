-- installer.lua - reinstala desde GitHub
local base = "https://raw.githubusercontent.com/TuShaggy/CC-Draconic/main/"

local files = {
  "startup.lua",
  "lib/f.lua",
}

print("Limpiando viejos...")
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

print("Instalación completa. Escribe 'reboot' para reiniciar.")
