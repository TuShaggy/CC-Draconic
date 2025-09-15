
-- Optional self-updater. Replace RAW_BASE with your repo raw URL.
-- Example: https://raw.githubusercontent.com/TuShaggy/posta/main

local RAW_BASE = "https://github.com/TuShaggy/CC-Draconic/main"
local FILES = { "startup.lua", "lib/f.lua" }

local function fetch(url)
  local h = http.get(url); if not h then error("HTTP get failed: "..url) end
  local b = h.readAll(); h.close(); return b
end

local function save(path, data)
  fs.makeDir(string.match(path, "(.+)/[^
]+$") or ".")
  local f = fs.open(path, "w"); f.write(data); f.close()
end

for _,p in ipairs(FILES) do
  local url = RAW_BASE.."/"..p
  print("Downloading ", url)
  local ok, data = pcall(fetch, url); if not ok then error(data) end
  save(p, data)
end

print("Done. Rebooting...")
os.sleep(1)
os.reboot()
