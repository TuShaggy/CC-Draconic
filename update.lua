-- update.lua — actualiza controlador CC-Draconic
local base = "https://raw.githubusercontent.com/TuShaggy/CC-Draconic/main/"

local files = {
  "startup.lua",
  "reactor.lua",
  "setup.lua",
  "ui.lua",
  "update.lua",
  "lib/f.lua",
}

print("== CC-Draconic :: Actualizador ==")

-- Borrar todo excepto config.lua
for _,file in ipairs(files) do
  if fs.exists(file) then fs.delete(file) end
end
if not fs.exists("lib") then fs.makeDir("lib") end

-- Descargar de nuevo
for _,file in ipairs(files) do
  local url = base..file
  print("Actualizando "..file.." ...")
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

print("Actualización completa. Reinicia con 'reboot'.")
