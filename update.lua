-- update.lua — actualiza todo el proyecto desde GitHub

local http = require("http")

local repo = "TuShaggy/CC-Draconic"
local branch = "main"
local api = ("https://api.github.com/repos/%s/contents/?ref=%s"):format(repo, branch)
local raw = ("https://raw.githubusercontent.com/%s/%s/"):format(repo, branch)

-- función recursiva para descargar todo el árbol
local function fetchTree(path, url)
  local res = http.get(url)
  if not res then
    print("⚠️ Error al acceder a "..url)
    return
  end
  local data = textutils.unserializeJSON(res.readAll())
  res.close()

  for _, file in ipairs(data) do
    if file.type == "file" then
      local rawUrl = raw..file.path
      print("↓ "..file.path)
      local ok, err = pcall(function()
        local r = http.get(rawUrl)
        if not r then error("No se pudo descargar "..rawUrl) end
        local content = r.readAll()
        r.close()
        local dir = fs.getDir(file.path)
        if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
        if file.path ~= "config.lua" then
          local h = fs.open(file.path, "w")
          h.write(content)
          h.close()
        end
      end)
      if not ok then print("   ⚠️ "..tostring(err)) end
    elseif file.type == "dir" then
      fetchTree(file.path, file.url)
    end
  end
end

print("🚀 Actualizando proyecto desde GitHub...")
fetchTree("", api)
print("✅ Actualización completada. Ejecuta `reboot`.")
