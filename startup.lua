-- startup.lua — controlador principal v2.0

local reactor = require("reactor")
local ui = require("ui")

local S = {
  mon = nil,
  reactor = nil,
  in_gate = nil,
  out_gate = nil,
  hudTheme = "minimalist",
  hudStyle = "CIRCLE",
  mode = "SAT",
  running = true,
}

-- cargar config
if fs.exists("config.lua") then
  local ok, cfg = pcall(dofile, "config.lua")
  if ok and type(cfg) == "table" then
    for k,v in pairs(cfg) do S[k] = v end
  end
end

-- periféricos
local function wrap(name)
  if name and peripheral.isPresent(name) then
    return peripheral.wrap(name)
  end
end

S.reactor = wrap(S.reactor)
S.mon = wrap(S.monitor)
S.in_gate = wrap(S.in_gate)
S.out_gate = wrap(S.out_gate)

-- loop principal
local function tickLoop()
  while true do
    if S.reactor then
      local stats = reactor.read(S)
      reactor.control(S, stats)
      if S.mon then
        ui.drawMain(S, stats)
      else
        term.setCursorPos(1,1)
        print("SAT:"..math.floor(stats.sat*100).."% FLD:"..math.floor(stats.field*100).."%")
      end
    else
      term.setCursorPos(1,1)
      term.setTextColor(colors.red)
      print("Reactor no detectado! Ejecuta setup.")
    end
    sleep(1)
  end
end

-- UI loop
local function uiLoop()
  while true do
    local e, side, x, y = os.pullEvent("monitor_touch")
    ui.handleTouch(S, x, y)
  end
end

parallel.waitForAny(tickLoop, uiLoop)
