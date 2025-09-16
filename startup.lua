-- startup.lua — principal
local P        = dofile("lib/perutils.lua")
local ui       = dofile("ui.lua")
local reactorM = dofile("reactor.lua")

local S = { mode = "SAT", hudTheme = "minimalist" }

-- Cargar configuración
if fs.exists("config.lua") then
  local ok, cfg = pcall(dofile, "config.lua")
  if ok and type(cfg) == "table" then for k,v in pairs(cfg) do S[k]=v end end
end

-- Periféricos
local function initPeripherals()
  local okR, rx  = pcall(P.get, S.reactor or "draconic_reactor")
  S.reactor = okR and rx or nil
  local okM, mon = pcall(P.get, S.monitor or "monitor")
  S.mon = okM and mon or term
end
initPeripherals()

-- Bucle de control + HUD
local function tickLoop()
  while true do
    local stats
    if S.reactor and S.reactor.getReactorInfo then
      stats = reactorM.read(S)
      reactorM.control(S, stats)
    else
      stats = { sat=0, field=0, temp=0, generation=0 }
    end
    ui.drawMain(S, stats)
    sleep(0.5)
  end
end

-- Eventos de toque
local function uiLoop()
  while true do
    local e, side, x, y = os.pullEvent("monitor_touch")
    ui.handleTouch(S, x, y)
  end
end

parallel.waitForAny(tickLoop, uiLoop)
