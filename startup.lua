-- startup.lua — controlador principal estable
local reactorM = dofile("reactor.lua")
local ui       = dofile("ui.lua")
local P        = dofile("lib/perutils.lua")

local S = {}

-- detectar periféricos
local function initPeripherals()
  local okR, rx = pcall(P.get, "draconic_reactor")
  if okR then S.reactor = rx end

  local okM, mon = pcall(P.get, "monitor")
  if okM then S.mon = mon else S.mon = term end
end

-- bucle reactor
local function tickLoop()
  while true do
    if S.reactor and S.reactor.getReactorInfo then
      local stats = reactorM.read(S)
      reactorM.control(S, stats)
      ui.drawMain(S, stats)
    else
      ui.drawMain(S, {sat=0,field=0,temp=0,generation=0})
    end
    sleep(0.5)
  end
end

-- bucle UI
local function uiLoop()
  while true do
    local e, side, x, y = os.pullEvent("monitor_touch")
    ui.handleTouch(S, x, y)
  end
end

initPeripherals()
parallel.waitForAny(tickLoop, uiLoop)
