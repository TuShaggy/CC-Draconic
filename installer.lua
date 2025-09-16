-- installer.lua — descarga todos los archivos necesarios desde GitHub

local repo = "https://raw.githubusercontent.com/TuShaggy/CC-Draconic/main/"

local files = {
  ["startup.lua"]     = repo.."startup.lua",
  ["reactor.lua"]     = repo.."reactor.lua",
  ["ui.lua"]          = repo.."ui.lua",
  ["setup.lua"]       = repo.."setup.lua",
  ["themes.lua"]      = repo.."themes.lua",
  ["lib/f.lua"]       = repo.."lib/f.lua",
  ["lib/perutils.lua"]= repo.."lib/perutils.lua",
}

local function ensureDir(path)
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then
    fs.makeDir(dir)
  end
end

for path, url in pairs(files) do
  print("Descargando "..path.." ...")
  ensureDir(path)
  local ok, err = pcall(function()
    if fs.exists(path) then fs.delete(path) end
    shell.run("wget", url, path)
  end)
  if not ok then
    print("  ⚠️ Error: "..tostring(err))
  end
end

print("✅ Instalación completa. Ejecuta `reboot` para iniciar.")
