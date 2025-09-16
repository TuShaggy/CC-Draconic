-- startup.lua — ciclo principal con HUD estilo drmon y animación de arranque
local P        = dofile("lib/perutils.lua")
local f        = dofile("lib/f.lua")
local ui       = dofile("ui.lua")
local reactorM = dofile("reactor.lua")

local S = { mode="SAT" }

-- cargar config
if fs.exists("config.lua") then
  local ok, cfg = pcall(dofile,"config.lua")
  if ok and type(cfg)=="table" then for k,v in pairs(cfg) do S[k]=v end end
end

-- periféricos
local function initPeripherals()
  local okR, rx  = pcall(P.get, S.reactor or "draconic_reactor")
  S.reactor = okR and rx or nil
  local okM, mon = pcall(P.get, S.monitor or "monitor")
  S.mon = okM and mon or term
end

-- animación de arranque
local function startupAnim()
  local mon = S.mon or term
  mon.setBackgroundColor(colors.black)
  mon.clear()

  local w,h = mon.getSize()

  f.center(mon, math.floor(h/2)-1, "DRACONIC REACTOR", colors.orange)
  f.center(mon, math.floor(h/2),    "Controller v2.0", colors.white)

  for i=1,w-4 do
    mon.setCursorPos(2, h-2)
    mon.setBackgroundColor(colors.orange)
    mon.write(string.rep(" ", i))
    sleep(0.02)
  end

  mon.setBackgroundColor(colors.black)
  mon.clear()
end

-- bucle reactor + HUD
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

-- bucle eventos de UI
local function uiLoop()
  while true do
    local e, side, x, y = os.pullEvent("monitor_touch")
    ui.handleTouch(S, x, y)
  end
end

-- flujo principal
initPeripherals()
startupAnim()
parallel.waitForAny(tickLoop, uiLoop)
