-- update.lua — actualiza a la última versión desde GitHub
local repo = "https://raw.githubusercontent.com/TuShaggy/CC-Draconic/main/"

local files = {
  "startup.lua",
  "reactor.lua",
  "setup.lua",
  "ui.lua",
  "installer.lua",
  "update.lua",
  "lib/f.lua",
}

for _,file in ipairs(files) do
  if file ~= "config.lua" then
    print("Actualizando "..file)
    local url = repo..file
    local h = http.get(url)
    if h then
      local c = h.readAll()
      h.close()
      fs.makeDir(fs.getDir(file))
      local f = fs.open(file, "w")
      f.write(c)
      f.close()
    else
      print("Fallo al actualizar "..file)
    end
  end
end

print("Actualización completa. Ejecuta reboot.")
