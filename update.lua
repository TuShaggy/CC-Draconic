-- update.lua — fuerza actualización desde GitHub
-- Borra startup.lua, módulos y lib/, luego reinstala todo

local base = "https://raw.githubusercontent.com/TuShaggy/CC-Draconic/main/"

local files = {
  "startup.lua",
  "reactor.lua",
  "setup.lua",
  "ui.lua",
  "lib/f.lua",
  "installer.lua", -- opcional, para que también se actualice el instalador
}

print("Eliminando versiones anteriores...")
if fs.exists("startup.lua") then fs.delete("startup.lua") end
if fs.exists("reactor.lua") then fs.delete("reactor.lua") end
if fs.exists("setup.lua") then fs.delete("setup.lua") end
if fs.exists("ui.lua") then fs.delete("ui.lua") end
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

print("Actualización completa. Escribe 'reboot' para reiniciar.")
