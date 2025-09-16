-- update.lua — full reset + update from GitHub
-- Borra todo (incluido config.lua) y reinstala desde el repo

local base = "https://raw.githubusercontent.com/TuShaggy/CC-Draconic/main/"

local files = {
  "startup.lua",
  "reactor.lua",
  "setup.lua",
  "ui.lua",
  "lib/f.lua",
  "installer.lua",
}

print("Eliminando versiones anteriores...")

-- Borra raíz
local roots = { "startup.lua","reactor.lua","setup.lua","ui.lua","installer.lua","config.lua" }
for _,f in ipairs(roots) do if fs.exists(f) then fs.delete(f) end end

-- Borra lib
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

print("✅ Actualización completa. Escribe 'reboot' para reiniciar y pasar por Setup de nuevo.")
