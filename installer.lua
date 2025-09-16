-- installer.lua — instala el controlador CC-Draconic
local base = "https://raw.githubusercontent.com/TuShaggy/CC-Draconic/main/"

local files = {
  "startup.lua",
  "reactor.lua",
  "setup.lua",
  "ui.lua",
  "update.lua",
  "lib/f.lua",
}

print("== CC-Draconic :: Instalador ==")

-- Crear carpeta lib si no existe
if not fs.exists("lib") then fs.makeDir("lib") end

for _,file in ipairs(files) do
  local url = base..file
  print("Descargando "..file.." ...")
  local ok,resp = pcall(http.get,url)
  if ok and resp then
    local h = fs.open(file,"w")
    h.write(resp.readAll())
    h.close()
    resp.close()
    print(" ✔ "..file)
  else
    print(" ✖ ERROR: no se pudo bajar "..file)
  end
end

print("Instalación completa. Reinicia con 'reboot'.")
