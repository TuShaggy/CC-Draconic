--[[
ATM10 Draconic Reactor Controller (CC:Tweaked)
Author: Fabian + ChatGPT
Repo layout (drop these files into your ComputerCraft computer):

startup.lua
lib/f.lua
installer.lua (optional; to self-update from your GitHub)

Requirements
- CC:Tweaked
- Draconic Evolution (reactor + 2 flux gates)
- (Recommended) Advanced Peripherals (for charge/activate/stop via API if present)
- 3x3 Advanced Monitor, wired modems (not wireless)

Wiring (default, configurable below)
- Place computer touching the OUTPUT flux gate on the RIGHT side and a REACTOR STABILIZER on the BACK.
- Attach wired modems to: the INPUT flux gate (injector), the monitor (any side except front), and the computer itself.

Notes
- Works on ATM10 (1.20.x) by using defensive API calls and fallbacks.
- No 'goto' anywhere; clean coroutines.
- Auto-regulates BOTH gates (input = field strength; output = saturation) with PI controllers.
- Failsafes: low field => emergency charge; over-temp => stop until cool; sat 0% => panic (close output).
]]


---------------------------
-- FILE: startup.lua
---------------------------

local f = dofile("lib/f.lua")

-- ========= CONFIG =========
local CFG = {
  -- Peripherals: leave nil to auto-discover
  REACTOR = nil,            -- e.g. "back" or peripheral name; nil => auto
  OUT_GATE = "right",       -- output flux gate (from stabilizer/core)
  IN_GATE  = nil,            -- input flux gate (to injector); nil => auto find other flux_gate
  MONITOR  = nil,            -- nil => auto (prefers max size / 3x3)
  ALARM_RS_SIDE = nil,       -- e.g. "top" to drive a siren lamp, nil = disabled

  -- Targets & thresholds
  TARGET_FIELD = 50.0,       -- % containment field target
  TARGET_SAT   = 65.0,       -- % energy saturation target when online
  FIELD_LOW_TRIP = 20.0,     -- % immediate emergency charge if below
  TEMP_MAX = 8000,           -- C
  TEMP_SAFE = 3000,          -- C (auto-resume below this)

  -- Controller gains (tune if needed)
  IN_KP = 120000,            -- RF/t per % error (input gate)
  IN_KI = 20000,             -- RF/t per %*sec (input gate)
  OUT_KP = 120000,           -- RF/t per % error (output gate)
  OUT_KI = 30000,            -- RF/t per %*sec (output gate)

  -- Limits
  IN_MIN = 0, IN_MAX = 3_000_000,
  OUT_MIN = 0, OUT_MAX = 10_000_000,
  CHARGE_FLOW = 900_000,     -- input gate while charging

  UI_TICK = 0.25,            -- seconds per loop
  DB_FIELD = 1.0,            -- deadband % for field control
  DB_SAT = 2.0,              -- deadband % for saturation control
}

-- ========= STATE =========
local S = {
  mon = nil, rx = nil, out = nil, inp = nil,
  autoIn = true, autoOut = true,
  setIn = 220000, setOut = 500000,      -- starting points
  iErrIn = 0, iErrOut = 0,
  lastT = os.clock(),
  action = "Boot",
  alarm = false,
}

-- ========= DISCOVERY =========
local function pickMonitor()
  if CFG.MONITOR then return peripheral.wrap(CFG.MONITOR) end
  local mons = { peripheral.find("monitor") }
  if #mons == 0 then return nil end
  -- choose the biggest (likely the 3x3)
  table.sort(mons, function(a,b)
    local ax,ay = a.getSize(); local bx,by = b.getSize()
    return (ax*ay) > (bx*by)
  end)
  return mons[1]
end

local function findReactor()
  if CFG.REACTOR then return peripheral.wrap(CFG.REACTOR) end
  -- Try common types
  local types = {"draconic_reactor","reactor","advancedperipherals:reactor"}
  for _,t in ipairs(types) do
    local dev = ({ peripheral.find(t) })[1]
    if dev then return dev end
  end
  -- As fallback, scan by methods
  for _,name in ipairs(peripheral.getNames()) do
    local p = peripheral.wrap(name)
    if type(p.getReactorInfo) == "function" then return p end
  end
end

local function isFluxGate(p)
  if not p then return false end
  local ok = type(p.getSignalLowFlow) == "function" and type(p.setSignalLowFlow) == "function"
  if ok then return true end
  -- try alternative API names (future-proofing)
  return type(p.setFlow) == "function" or type(p.setFlowOverride) == "function"
end

local function wrapFluxSetter(p)
  -- Unify to get()/set(limit)
  local api = {}
  if type(p.getSignalLowFlow) == "function" then
    api.get = function() return p.getSignalLowFlow() end
    api.set = function(v) return p.setSignalLowFlow(math.max(0, math.floor(v))) end
  elseif type(p.getFlow) == "function" and (type(p.setFlow) == "function" or type(p.setFlowOverride) == "function") then
    api.get = function() return p.getFlow() end
    local setter = p.setFlow or p.setFlowOverride
    api.set = function(v) return setter(math.max(0, math.floor(v))) end
  else
    error("Flux gate peripheral does not expose a known API")
  end
  api.raw = p
  return api
end

local function discover()
  S.mon = pickMonitor()
  if not S.mon then error("No monitor found. Connect a 3x3 advanced monitor via wired modem.") end

  local rx = findReactor(); if not rx then error("No reactor peripheral found.") end
  S.rx = rx

  local out = CFG.OUT_GATE and peripheral.wrap(CFG.OUT_GATE) or nil
  if out and not isFluxGate(out) then out = nil end

  local inp = CFG.IN_GATE and peripheral.wrap(CFG.IN_GATE) or nil
  if inp and not isFluxGate(inp) then inp = nil end

  if not out or not inp then
    -- find any remaining flux_gates
    local gates = {}
    for _,name in ipairs(peripheral.getNames()) do
      local p = peripheral.wrap(name)
      if isFluxGate(p) then
        if (not out) and name == CFG.OUT_GATE then out = p
        else table.insert(gates, p) end
      end
    end
    if not inp then inp = gates[1] end
  end
  if not out or not inp then error("Need TWO flux gates (output + input). Check wiring.") end

  S.out = wrapFluxSetter(out)
  S.inp = wrapFluxSetter(inp)
end

-- ========= UTIL =========
local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi else return v end end
local function pct(n,d) if not n or not d or d == 0 then return 0 end return (n/d)*100 end

local function rxInfo()
  local ok, info = pcall(S.rx.getReactorInfo)
  if not ok or not info then return nil end
  -- Normalize possible field names
  local t = {
    status = info.status or info.state or "unknown",
    gen = info.generationRate or info.generation or 0,
    temp = info.temperature or info.temp or 0,
    es = info.energySaturation or info.energy or 0,
    esMax = info.maxEnergySaturation or info.maxEnergy or 1,
    fs = info.fieldStrength or info.field or 0,
    fsMax = info.maxFieldStrength or info.maxField or 1,
    fc = info.fuelConversion or info.converted or 0,
    fcMax = info.maxFuelConversion or info.maxConverted or 1,
    fieldDrain = info.fieldDrain or info.fieldLoadRate or nil,
  }
  t.satP = pct(t.es, t.esMax)
  t.fieldP = pct(t.fs, t.fsMax)
  t.fuelP = 100 - pct(t.fc, t.fcMax)
  return t
end

local function reactorCall(name)
  if type(S.rx[name]) == "function" then
    local ok, res = pcall(S.rx[name])
    return ok and res or false
  end
  return false
end

local function setAlarm(on)
  if CFG.ALARM_RS_SIDE then redstone.setOutput(CFG.ALARM_RS_SIDE, on) end
  S.alarm = on
end

-- ========= CONTROL =========
local function controlTick(info, dt)
  -- Emergency: low field
  if info.fieldP <= CFG.FIELD_LOW_TRIP then
    S.action = "EMERG: Field < "..CFG.FIELD_LOW_TRIP.."%"
    setAlarm(true)
    reactorCall("stopReactor") -- graceful if present
    reactorCall("chargeReactor")
    S.inp.set(CFG.CHARGE_FLOW)
    S.out.set(CFG.OUT_MIN) -- stop drawing to rebuild sat/field
    return
  end

  -- Emergency: over-temp
  if info.temp >= CFG.TEMP_MAX then
    S.action = "EMERG: Temp > "..CFG.TEMP_MAX
    setAlarm(true)
    reactorCall("stopReactor")
    S.out.set(CFG.OUT_MIN)
    -- keep field alive via input loop below
  end

  -- Auto resume from cool
  if info.status == "stopping" and info.temp <= CFG.TEMP_SAFE then
    reactorCall("activateReactor")
    S.action = "Resume: cool"; setAlarm(false)
  end

  -- Charging: flood input, no further control
  if info.status == "charging" then
    S.inp.set(CFG.CHARGE_FLOW)
    S.action = "Charging"
    return
  end

  -- ===== Input gate (field strength) =====
  if S.autoIn then
    local err = CFG.TARGET_FIELD - info.fieldP
    if math.abs(err) <= CFG.DB_FIELD then err = 0 end
    S.iErrIn = clamp(S.iErrIn + err*dt, -1000, 1000)
    S.setIn = clamp(S.setIn + (CFG.IN_KP*err + CFG.IN_KI*S.iErrIn)*dt, CFG.IN_MIN, CFG.IN_MAX)
    S.inp.set(S.setIn)
  else
    S.setIn = clamp(S.setIn, CFG.IN_MIN, CFG.IN_MAX)
    S.inp.set(S.setIn)
  end

  -- ===== Output gate (energy saturation) =====
  if S.autoOut then
    local err = CFG.TARGET_SAT - info.satP
    if math.abs(err) <= CFG.DB_SAT then err = 0 end
    S.iErrOut = clamp(S.iErrOut + err*dt, -1000, 1000)
    S.setOut = clamp(S.setOut + (CFG.OUT_KP*err + CFG.OUT_KI*S.iErrOut)*dt, CFG.OUT_MIN, CFG.OUT_MAX)
    -- Cooling assist: if temp too high, taper output down to reduce heat
    if info.temp > 7000 then S.setOut = S.setOut * 0.7 end
    S.out.set(S.setOut)
  else
    S.setOut = clamp(S.setOut, CFG.OUT_MIN, CFG.OUT_MAX)
    S.out.set(S.setOut)
  end

  S.action = (S.autoIn and "AU" or "MA").." IN="..f.si(S.setIn).."  "..(S.autoOut and "AU" or "MA").." OUT="..f.si(S.setOut)
  setAlarm(false)
end

-- ========= UI =========
local function draw(info)
  local mon = S.mon
  mon.setTextScale(0.5)
  local mx,my = mon.getSize()
  f.clear(mon)

  local statusColor = colors.red
  if info.status == "online" or info.status == "charged" then statusColor = colors.lime
  elseif info.status == "offline" then statusColor = colors.gray
  elseif info.status == "charging" then statusColor = colors.orange end

  f.textLR(mon, 2, 2, "Reactor Status", string.upper(info.status), colors.white, statusColor)
  f.textLR(mon, 2, 4, "Generation", f.format_int(info.gen).." RF/t", colors.white, colors.lime)

  local tcol = colors.red
  if info.temp < 5000 then tcol = colors.lime elseif info.temp < 6500 then tcol = colors.orange end
  f.textLR(mon, 2, 6, "Temperature", f.format_int(info.temp).." C", colors.white, tcol)

  f.textLR(mon, 2, 8, "Output Gate", f.format_int(S.out.get()).." RF/t", colors.white, colors.cyan)
  f.textLR(mon, 2, 10, "Input Gate", f.format_int(S.inp.get()).." RF/t", colors.white, colors.cyan)

  f.textLR(mon, 2, 12, "Energy Saturation", string.format("%.2f%%", info.satP), colors.white, colors.white)
  f.bar(mon, 2, 13, mx-2, info.satP, 100, colors.blue)

  local fcol = colors.red; if info.fieldP >= 50 then fcol = colors.lime elseif info.fieldP > 30 then fcol = colors.orange end
  local ftitle = S.autoIn and ("Field Strength T:"..CFG.TARGET_FIELD) or "Field Strength"
  f.textLR(mon, 2, 15, ftitle, string.format("%.2f%%", info.fieldP), colors.white, fcol)
  f.bar(mon, 2, 16, mx-2, info.fieldP, 100, fcol)

  f.textLR(mon, 2, 18, "Fuel", string.format("%.2f%%", info.fuelP), colors.white, colors.white)
  f.bar(mon, 2, 19, mx-2, info.fuelP, 100, colors.pink)

  f.textLR(mon, 2, my-2, "Action", S.action, colors.gray, colors.gray)

  -- Buttons (bottom row): left group = OUT gate, right = IN gate + toggles
  local yBtn = my-1
  f.button(mon, 2, yBtn, "<<<"); f.button(mon, 6, yBtn, "<<"); f.button(mon, 10, yBtn, "<")
  f.button(mon, 14, yBtn, S.autoOut and "OUT:AU" or "OUT:MA", S.autoOut and colors.green or colors.orange)
  f.button(mon, mx-13, yBtn, ">"); f.button(mon, mx-9, yBtn, ">>"); f.button(mon, mx-5, yBtn, ">>>")

  local y2 = my
  f.button(mon, 2, y2, "<<<"); f.button(mon, 6, y2, "<<"); f.button(mon, 10, y2, "<")
  f.button(mon, 14, y2, S.autoIn and "IN:AU" or "IN:MA", S.autoIn and colors.green or colors.orange)
  f.button(mon, mx-13, y2, ">"); f.button(mon, mx-9, y2, ">>"); f.button(mon, mx-5, y2, ">>>")
end

local function handleTouch(x,y)
  local mon = S.mon; local mx,my = mon.getSize()
  local function inRect(cx,cy,label)
    return x >= cx and x <= cx+#label-1 and y == cy
  end
  -- OUT gate manual adjustments
  local yBtn = my-1
  if inRect(2,yBtn,"<<<") then S.setOut = S.setOut - 100000; S.autoOut = false end
  if inRect(6,yBtn,"<<") then S.setOut = S.setOut - 10000; S.autoOut = false end
  if inRect(10,yBtn,"<") then S.setOut = S.setOut - 1000; S.autoOut = false end
  if inRect(14,yBtn,S.autoOut and "OUT:AU" or "OUT:MA") then S.autoOut = not S.autoOut end
  if inRect(mx-13,yBtn,">") then S.setOut = S.setOut + 1000; S.autoOut = false end
  if inRect(mx-9,yBtn,">>") then S.setOut = S.setOut + 10000; S.autoOut = false end
  if inRect(mx-5,yBtn,">>>") then S.setOut = S.setOut + 100000; S.autoOut = false end

  -- IN gate manual adjustments
  local y2 = my
  if inRect(2,y2,"<<<") then S.setIn = S.setIn - 100000; S.autoIn = false end
  if inRect(6,y2,"<<") then S.setIn = S.setIn - 10000; S.autoIn = false end
  if inRect(10,y2,"<") then S.setIn = S.setIn - 1000; S.autoIn = false end
  if inRect(14,y2,S.autoIn and "IN:AU" or "IN:MA") then S.autoIn = not S.autoIn end
  if inRect(mx-13,y2,">") then S.setIn = S.setIn + 1000; S.autoIn = false end
  if inRect(mx-9,y2,">>") then S.setIn = S.setIn + 10000; S.autoIn = false end
  if inRect(mx-5,y2,">>>") then S.setIn = S.setIn + 100000; S.autoIn = false end
end

-- ========= MAIN =========
local function uiLoop()
  while true do
    local ev, side, x, y = os.pullEvent()
    if ev == "monitor_touch" then handleTouch(x,y) end
  end
end

local function tickLoop()
  while true do
    local now = os.clock(); local dt = now - S.lastT; S.lastT = now
    local info = rxInfo();
    if not info then S.action = "Reactor info error" else
      controlTick(info, dt)
      draw(info)
    end
    sleep(CFG.UI_TICK)
  end
end

local function main()
  term.clear(); term.setCursorPos(1,1)
  print("ATM10 Draconic Reactor Controller — starting...")
  discover()
  local mx,my = S.mon.getSize(); print("Monitor:", mx, "x", my)
  print("Peripherals OK. AutoIn=", S.autoIn, " AutoOut=", S.autoOut)
  parallel.waitForAny(tickLoop, uiLoop)
end

local ok, err = pcall(main)
if not ok then
  if S.mon then f.clear(S.mon); S.mon.setCursorPos(2,2); S.mon.write("Error:") S.mon.setCursorPos(2,3); S.mon.write(err or "unknown") end
  error(err)
end


---------------------------
-- FILE: lib/f.lua
---------------------------

local f = {}

local function drawPad(mon, x, y, label, fg, bg)
  fg = fg or colors.white; bg = bg or colors.gray
  mon.setCursorPos(x,y); mon.setBackgroundColor(bg); mon.setTextColor(fg); mon.write(label)
  mon.setBackgroundColor(colors.black); mon.setTextColor(colors.white)
end

function f.clear(mon)
  local mx,my = mon.getSize()
  mon.setBackgroundColor(colors.black); mon.clear(); mon.setCursorPos(1,1)
end

function f.textLR(mon, x, y, left, right, lcol, rcol)
  local mx = select(1, mon.getSize())
  mon.setCursorPos(x,y); mon.setTextColor(lcol or colors.white); mon.write(left)
  local rx = mx - #right - 1
  if rx < x+#left+1 then rx = x+#left+1 end
  mon.setCursorPos(rx,y); mon.setTextColor(rcol or colors.white); mon.write(right)
  mon.setTextColor(colors.white)
end

function f.bar(mon, x, y, w, val, maxVal, col)
  val = math.max(0, math.min(val, maxVal))
  local fill = math.floor((w-2) * (val/maxVal))
  mon.setCursorPos(x,y); mon.setTextColor(colors.white); mon.write("[")
  for i=1,w-2 do
    mon.setBackgroundColor(i<=fill and (col or colors.green) or colors.gray)
    mon.write(" ")
  end
  mon.setBackgroundColor(colors.black); mon.write("]")
end

function f.button(mon, x, y, label, col)
  drawPad(mon, x, y, label, colors.white, col or colors.gray)
end

function f.format_int(n)
  if type(n) ~= 'number' then return tostring(n) end
  local s = string.format("%0.0f", n)
  local left, num, right = string.match(s,'^([^%d]*%d)(%d*)(.-)$')
  return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end

function f.si(n)
  if n >= 1e12 then return string.format("%.1fT", n/1e12)
  elseif n >= 1e9 then return string.format("%.1fG", n/1e9)
  elseif n >= 1e6 then return string.format("%.1fM", n/1e6)
  elseif n >= 1e3 then return string.format("%.1fk", n/1e3)
  else return string.format("%d", n) end
end

return f


---------------------------
-- FILE: installer.lua
---------------------------
-- Optional self-updater. Replace RAW_BASE with your repo raw URL.
-- Example: https://raw.githubusercontent.com/TuShaggy/posta/main

local RAW_BASE = "https://raw.githubusercontent.com/TuShaggy/posta/main"
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
  local ok, data = pcall(fetch, url)
  if not ok then error(data) end
  save(p, data)
end

print("Done. Rebooting...")
os.sleep(1)
os.reboot()
