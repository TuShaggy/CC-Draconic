-- installer.lua — descarga archivos desde tu GitHub y reinicia
local RAW_BASE = "https://raw.githubusercontent.com/TuShaggy/CC-Draconic/main"
local FILES = { "startup.lua", "lib/f.lua" }

local function fetch(url)
  local h = http.get(url)
  if not h then error("HTTP get failed: "..url) end
  local b = h.readAll(); h.close(); return b
end

local function save(path, data)
  local dir = fs.getDir(path)
  if dir ~= "" then fs.makeDir(dir) end
  local f = fs.open(path, "w"); f.write(data); f.close()
end

for _,p in ipairs(FILES) do
  local url = RAW_BASE.."/"..p
  print("Downloading ", url)
  local ok, data = pcall(fetch, url); if not ok then error(data) end
  save(p, data)
  -- Compat: algunos scripts aún llaman os.loadAPI("lib/f")
  if p == "lib/f.lua" then save("lib/f", data) end
end

print("Done. Rebooting...")
os.sleep(1)
os.reboot()
