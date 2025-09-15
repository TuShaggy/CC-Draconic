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
- 3x3 Advanced Monitor, **all devices connected only via wired modems** (ningún bloque tocando al reactor)

Design goals
- **No suposiciones de lados**: ningún periférico necesita tocar al reactor; todo va por red cableada.
- **Descubrimiento automático** + **asistente de mapeo** (UI) para elegir qué flux gate es **INPUT** y cuál es **OUTPUT** cuando hay más de 2.
- **Calibración automática segura** para diferenciar puertas si solo hay 2.
- **PI controllers** para regular input (campo) y output (saturación o generación objetivo).
- **Failsafes** y sin `goto`.
]]


---------------------------
-- FILE: startup.lua
---------------------------

local f = dofile("lib/f.lua")

-- ========= CONFIG =========
local CFG = {
  -- Puedes fijar NOMBRES EXACTOS (como salen en `peripheral.getNames()`)
  REACTOR = "draconic_reactor_1", -- nil => auto o asistente
  OUT_GATE = "flow_gate_9",        -- nil => auto/calibración/asistente
  IN_GATE  = "flow_gate_4",        -- nil => auto/calibración/asistente
  MONITOR  = "monitor_5",          -- nil => auto (elige el más grande)
  ALARM_RS_SIDE = nil,              -- e.g. "top" para lámpara/sirena por redstone

  -- Targets & thresholds
  TARGET_FIELD = 50.0,      -- % objetivo de campo
  TARGET_SAT   = 65.0,      -- % objetivo de saturación (modo SAT)
  TARGET_GEN_RFPT = 3_000_000, -- RF/t objetivo (modo GEN)
  FIELD_LOW_TRIP = 20.0,    -- % emergencia si baja de esto
  TEMP_MAX = 8000,          -- C
  TEMP_SAFE = 3000,         -- C (reanudar por debajo)

  -- Control gains (tuneables)
  IN_KP = 120000, IN_KI = 20000,
  OUT_KP = 120000, OUT_KI = 30000,

  -- Límites de flujo
  IN_MIN = 0, IN_MAX = 3_000_000,
  OUT_MIN = 0, OUT_MAX = 10_000_000,
  CHARGE_FLOW = 900_000,    -- input gate durante carga

  UI_TICK = 0.25,           -- s por ciclo
  DB_FIELD = 1.0,           -- histéresis campo
  DB_SAT = 2.0,             -- histéresis saturación
  DB_GEN = 0.02,            -- 2% del target gen como zona muerta

  -- Persistencia
  CFG_FILE = "config.lua",  -- guarda el mapeo aquí
  MODE_OUT = "SAT",         -- "SAT" (por saturación) o "GEN" (por generación)
}

-- ========= STATE =========
local S = {
  mon = nil, rx = nil, out = nil, inp = nil,
  monName=nil, rxName=nil, outName=nil, inName=nil,
  autoIn = true, autoOut = true,
  setIn = 220000, setOut = 500000,
  iErrIn = 0, iErrOut = 0,
  lastT = os.clock(),
  action = "Boot",
  alarm = false,
  setupMode = false,
  modeOut = CFG.MODE_OUT, -- "SAT" o "GEN"
}

-- ========= PERSISTENCE =========
local function saveTbl(path, tbl)
  local h = fs.open(path, "w"); h.write("return "..textutils.serialize(tbl)); h.close()
end
local function loadTbl(path)
  if not fs.exists(path) then return nil end
  local ok, t = pcall(dofile, path)
  if ok and type(t)=="table" then return t end
  return nil
end

-- ========= DISCOVERY =========
local function listPeriph(t)
  local arr = { peripheral.find(t) }; return arr
end

local function pickMonitor()
  if CFG.MONITOR then S.monName = CFG.MONITOR; return peripheral.wrap(CFG.MONITOR) end
  local mons = listPeriph("monitor")
  if #mons == 0 then return nil end
  table.sort(mons, function(a,b)
    local ax,ay=a.getSize(); local bx,by=b.getSize(); return ax*ay>bx*by
  end)
  for _,name in ipairs(peripheral.getNames()) do
    local p=peripheral.wrap(name); if p==mons[1] then S.monName=name; break end
  end
  return mons[1]
end

local function findReactors()
  local out = {}
  local types = {"draconic_reactor","reactor","advancedperipherals:reactor"}
  for _,t in ipairs(types) do
    for _,p in ipairs(listPeriph(t)) do table.insert(out, p) end
  end
  -- fallback: por método
  for _,name in ipairs(peripheral.getNames()) do
    local p = peripheral.wrap(name)
    if type(p.getReactorInfo)=="function" then table.insert(out, p) end
  end
  -- dedupe
  local seen = {}; local res = {}
  for _,p in ipairs(out) do if not seen[tostring(p)] then seen[tostring(p)]=true; table.insert(res,p) end end
  return res
end

local function isFluxGate(p)
  if not p then return false end
  if type(p.getSignalLowFlow)=="function" and type(p.setSignalLowFlow)=="function" then return true end
  if type(p.getFlow)=="function" and (type(p.setFlow)=="function" or type(p.setFlowOverride)=="function") then return true end
  return false
end

local function findFluxGates()
  local gates = {}
  for _,name in ipairs(peripheral.getNames()) do
    local p = peripheral.wrap(name)
    if isFluxGate(p) then table.insert(gates, {name=name, p=p}) end
  end
  return gates
end

local function wrapFluxSetter(p)
  local api = {}
  if type(p.getSignalLowFlow)=="function" then
    api.get=function() return p.getSignalLowFlow() end
    api.set=function(v) return p.setSignalLowFlow(math.max(0, math.floor(v))) end
  else
    api.get=function() return p.getFlow() end
    local setter=p.setFlow or p.setFlowOverride
    api.set=function(v) return setter(math.max(0, math.floor(v))) end
  end
  api.raw=p; return api
end

local function nameOf(wrapped)
  for _,n in ipairs(peripheral.getNames()) do if peripheral.wrap(n)==wrapped then return n end end
  return nil
end

-- ========= REACTOR INFO =========
local function pct(n,d) if not n or not d or d==0 then return 0 end return (n/d)*100 end
local function rxInfo()
  local ok, info = pcall(S.rx.getReactorInfo)
  if not ok or not info then return nil end
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
  t.satP = pct(t.es, t.esMax); t.fieldP = pct(t.fs, t.fsMax); t.fuelP = 100 - pct(t.fc, t.fcMax)
  return t
end

local function reactorCall(name)
  if type(S.rx[name])=="function" then local ok,res=pcall(S.rx[name]); return ok and res or false end
  return false
end

-- ========= UTILS =========
local function clamp(v, lo, hi) if v<lo then return lo elseif v>hi then return hi else return v end end
local function setAlarm(on) if CFG.ALARM_RS_SIDE then redstone.setOutput(CFG.ALARM_RS_SIDE, on) end S.alarm=on end

-- ========= CALIBRATION (auto-roles) =========
local function calibrateRoles(inpGate, outGate, gates)
  local info = rxInfo(); if not info then return nil end
  if info.status ~= "online" and info.status ~= "charged" then return nil end
  if #gates ~= 2 then return nil end

  local oldAutoIn, oldAutoOut = S.autoIn, S.autoOut
  S.autoIn=false; S.autoOut=false
  local g1, g2 = gates[1], gates[2]
  local g1w, g2w = wrapFluxSetter(g1.p), wrapFluxSetter(g2.p)
  local s1o, s2o = g1w.get(), g2w.get()

  local function measureDelta(fn)
    local i0 = rxInfo(); sleep(0.6); fn(); sleep(1.0); local i1 = rxInfo();
    return i0, i1
  end

  local step = 20000
  local i0, i1 = measureDelta(function() g1w.set(s1o + step) end)
  g1w.set(s1o)
  local df_field1 = (i1.fieldP - i0.fieldP)
  local df_sat1   = (i1.satP - i0.satP)

  local j0, j1 = measureDelta(function() g2w.set(s2o + step) end)
  g2w.set(s2o)
  local df_field2 = (j1.fieldP - j0.fieldP)
  local df_sat2   = (j1.satP - j0.satP)

  local input, output
  if df_field1 > 0.05 and df_sat1 > -0.1 then input=g1; output=g2 end
  if df_field2 > 0.05 and df_sat2 > -0.1 then input=g2; output=g1 end

  S.autoIn=oldAutoIn; S.autoOut=oldAutoOut
  if input and output then
    return input.name, output.name
  end
  return nil
end

-- ========= DISCOVER + SETUP WIZARD =========
local function applyMapping(map)
  S.rx = peripheral.wrap(map.reactor); S.rxName = map.reactor
  S.mon = peripheral.wrap(map.monitor); S.monName = map.monitor
  S.inp = wrapFluxSetter(peripheral.wrap(map.in_gate)); S.inName = map.in_gate
  S.out = wrapFluxSetter(peripheral.wrap(map.out_gate)); S.outName = map.out_gate
end

local function drawSetup(state)
  local mon=S.mon; local mx,my=mon.getSize(); f.clear(mon); mon.setTextScale(0.5)
  f.textLR(mon,2,2,"SETUP — asigna periféricos", "", colors.white, colors.white)
  mon.setCursorPos(2,4); mon.write("Reactor:")
  f.button(mon, 12,4, state.rxList[state.rxIdx] or "—")
  mon.setCursorPos(2,6); mon.write("Monitor:")
  f.button(mon, 12,6, state.monList[state.monIdx] or "—")
  mon.setCursorPos(2,8); mon.write("Input Gate:")
  f.button(mon, 12,8, state.gateList[state.inIdx] and state.gateList[state.inIdx].name or "—")
  mon.setCursorPos(2,10); mon.write("Output Gate:")
  f.button(mon, 12,10, state.gateList[state.outIdx] and state.gateList[state.outIdx].name or "—")

  f.button(mon, 2, my-3, "Auto-calibrar (si online)", colors.green)
  f.button(mon, mx-16, my-1, "Guardar & Iniciar", colors.blue)
  f.button(mon, 2, my-1, "Refrescar", colors.gray)
end

local function setupWizard()
  S.setupMode=true
  local reactors = {}
  for _,p in ipairs(findReactors()) do table.insert(reactors, nameOf(p)) end
  local mons = {}
  for _,n in ipairs(peripheral.getNames()) do if peripheral.getType(n)=="monitor" then table.insert(mons,n) end end
  local gates = findFluxGates()

  if #mons==0 then error("No hay monitores conectados por módem.") end
  if #gates<2 then error("Se requieren al menos 2 flux gates en la red.") end
  if #reactors==0 then error("No se detecta reactor por módem (stabilizer).") end

  local st = { rxList=reactors, monList=mons, gateList=gates, rxIdx=1, monIdx=1, inIdx=1, outIdx=2 }
  drawSetup(st)

  while true do
    local ev,side,x,y=os.pullEvent("monitor_touch")
    local mx,my=S.mon.getSize()
    local function inRect(cx,cy,label) return x>=cx and x<=cx+#label-1 and y==cy end

    if inRect(12,4, st.rxList[st.rxIdx] or "—") then st.rxIdx = st.rxIdx % #st.rxList + 1; drawSetup(st) end
    if inRect(12,6, st.monList[st.monIdx] or "—") then st.monIdx = st.monIdx % #st.monList + 1; drawSetup(st) end
    if inRect(12,8, (st.gateList[st.inIdx] and st.gateList[st.inIdx].name) or "—") then st.inIdx = st.inIdx % #st.gateList + 1; drawSetup(st) end
    if inRect(12,10,(st.gateList[st.outIdx] and st.gateList[st.outIdx].name) or "—") then st.outIdx = st.outIdx % #st.gateList + 1; drawSetup(st) end

    if inRect(2, my-3, "Auto-calibrar (si online)") then
      local map = {reactor=st.rxList[st.rxIdx], monitor=st.monList[st.monIdx]}
      S.rx = peripheral.wrap(map.reactor); S.mon = peripheral.wrap(map.monitor)
      local pair = {st.gateList[1], st.gateList[2]}
      if #pair==2 then
        local inName, outName = calibrateRoles(nil,nil, pair)
        if inName and outName then st.inIdx = (inName==pair[1].name) and 1 or 2; st.outIdx = (outName==pair[1].name) and 1 or 2 end
      end
      drawSetup(st)
    end

    if inRect(2, my-1, "Refrescar") then return setupWizard() end
    if inRect(mx-16, my-1, "Guardar & Iniciar") then
      if st.inIdx==st.outIdx then
        -- ignorar, deben ser distintos
      else
        local map = {reactor=st.rxList[st.rxIdx], monitor=st.monList[st.monIdx], in_gate=st.gateList[st.inIdx].name, out_gate=st.gateList[st.outIdx].name}
        saveTbl(CFG.CFG_FILE, map)
        applyMapping(map)
        S.setupMode=false
        return
      end
    end
  end
end

local function discover()
  local persisted = loadTbl(CFG.CFG_FILE)
  if persisted and peripheral.wrap(persisted.reactor) and peripheral.wrap(persisted.monitor)
     and peripheral.wrap(persisted.in_gate) and peripheral.wrap(persisted.out_gate) then
    applyMapping(persisted)
  else
    S.mon = pickMonitor(); if not S.mon then error("Sin monitor (con módem)") end
    local rxs = findReactors(); if #rxs==0 then error("Sin reactor por módem (stabilizer)") end
    S.rx = rxs[1]; S.rxName = nameOf(S.rx)
    local gates = findFluxGates(); if #gates<2 then error("Se necesitan 2 flux gates") end

    if #gates==2 then
      local inName, outName = calibrateRoles(nil,nil, gates)
      if not inName then S.setupMode = true else
        local map = {reactor=S.rxName, monitor=S.monName or nameOf(S.mon), in_gate=inName, out_gate=outName}
        saveTbl(CFG.CFG_FILE, map); applyMapping(map)
      end
    else
      setupWizard()
    end
  end

  if not S.inp or not S.out then
    S.inp = wrapFluxSetter(peripheral.wrap(S.inName))
    S.out = wrapFluxSetter(peripheral.wrap(S.outName))
  end
end

-- ========= CONTROL =========
local function controlTick(info, dt)
  -- Emergencia: campo bajo
  if info.fieldP <= CFG.FIELD_LOW_TRIP then
    S.action = "EMERG: Field < "..CFG.FIELD_LOW_TRIP.."%"; setAlarm(true)
    reactorCall("stopReactor"); reactorCall("chargeReactor")
    S.inp.set(CFG.CHARGE_FLOW); S.out.set(CFG.OUT_MIN)
    return
  end
  -- Sobretemperatura
  if info.temp >= CFG.TEMP_MAX then
    S.action = "EMERG: Temp > "..CFG.TEMP_MAX; setAlarm(true)
    reactorCall("stopReactor"); S.out.set(CFG.OUT_MIN)
  end
  -- Reanudar en frío
  if info.status=="stopping" and info.temp<=CFG.TEMP_SAFE then
    reactorCall("activateReactor"); S.action = "Resume: cool"; setAlarm(false)
  end
  -- Cargando
  if info.status=="charging" then
    S.inp.set(CFG.CHARGE_FLOW); S.action = "Charging"; return
  end

  -- Input: mantener campo
  if S.autoIn then
    local err = CFG.TARGET_FIELD - info.fieldP; if math.abs(err)<=CFG.DB_FIELD then err=0 end
    S.iErrIn = clamp(S.iErrIn + err*dt, -1000, 1000)
    S.setIn = clamp(S.setIn + (CFG.IN_KP*err + CFG.IN_KI*S.iErrIn)*dt, CFG.IN_MIN, CFG.IN_MAX)
    S.inp.set(S.setIn)
  else
    S.setIn = clamp(S.setIn, CFG.IN_MIN, CFG.IN_MAX); S.inp.set(S.setIn)
  end

  -- Output: modo SAT o GEN
  if S.autoOut then
    local err
    if S.modeOut=="SAT" then
      err = CFG.TARGET_SAT - info.satP
      if math.abs(err) <= CFG.DB_SAT then err = 0 end
    else -- GEN
      -- Normaliza error de generación como % del objetivo para reutilizar ganancias
      local target = math.max(1, CFG.TARGET_GEN_RFPT)
      local e = (CFG.TARGET_GEN_RFPT - info.gen) / target * 100
      if math.abs(e) <= (CFG.DB_GEN*100) then e = 0 end
      err = e
    end
    S.iErrOut = clamp(S.iErrOut + err*dt, -1000, 1000)
    S.setOut = clamp(S.setOut + (CFG.OUT_KP*err + CFG.OUT_KI*S.iErrOut)*dt, CFG.OUT_MIN, CFG.OUT_MAX)
    if info.temp > 7000 then S.setOut = S.setOut * 0.7 end
    S.out.set(S.setOut)
  else
    S.setOut = clamp(S.setOut, CFG.OUT_MIN, CFG.OUT_MAX); S.out.set(S.setOut)
  end

  S.action = (S.autoIn and "AU" or "MA").." IN="..f.si(S.setIn).."  "..(S.autoOut and "AU" or "MA").." OUT="..f.si(S.setOut)
  setAlarm(false)
end

-- ========= UI =========
local function draw(info)
  local mon=S.mon; mon.setTextScale(0.5); local mx,my=mon.getSize(); f.clear(mon)
  local statusColor=colors.red
  if info.status=="online" or info.status=="charged" then statusColor=colors.lime
  elseif info.status=="offline" then statusColor=colors.gray elseif info.status=="charging" then statusColor=colors.orange end

  f.textLR(mon,2,2,"Reactor ("..(S.rxName or "?")..")", string.upper(info.status), colors.white, statusColor)
  f.textLR(mon,2,4,"Monitor", S.monName or "?", colors.gray, colors.gray)
  f.textLR(mon,2,6,"Gates", (S.inName or "?").." [IN]  |  "..(S.outName or "?").." [OUT]", colors.gray, colors.cyan)

  -- Botones de cabecera: MODE y SETUP, siempre visibles
  local modeLabel = "MODE:"..S.modeOut
  local modeX = math.max(2, (mx - 10) - (#modeLabel + 2))
  f.button(mon, modeX, 2, modeLabel, colors.blue)
  f.button(mon, mx-10, 2, "SETUP", colors.orange)

  f.textLR(mon,2,8,"Generation", f.format_int(info.gen).." RF/t", colors.white, colors.lime)
  local tcol=colors.red; if info.temp<5000 then tcol=colors.lime elseif info.temp<6500 then tcol=colors.orange end
  f.textLR(mon,2,10,"Temperature", f.format_int(info.temp).." C", colors.white, tcol)

  f.textLR(mon,2,12,"Output Gate", f.format_int(S.out.get()).." RF/t", colors.white, colors.cyan)
  f.textLR(mon,2,13,"Input Gate",  f.format_int(S.inp.get()).." RF/t", colors.white, colors.cyan)

  f.textLR(mon,2,15,"Energy Saturation", string.format("%.2f%%", info.satP), colors.white, colors.white)
  f.bar(mon,2,16,mx-2,info.satP,100,colors.blue)

  local fcol=colors.red; if info.fieldP>=50 then fcol=colors.lime elseif info.fieldP>30 then fcol=colors.orange end
  f.textLR(mon,2,18,(S.autoIn and ("Field Strength T:"..CFG.TARGET_FIELD) or "Field Strength"), string.format("%.2f%%", info.fieldP), colors.white, fcol)
  f.bar(mon,2,19,mx-2,info.fieldP,100,fcol)

  f.textLR(mon,2,my-3,"Action", S.action, colors.gray, colors.gray)

  -- Botonera OUT (fila my-1) e IN (fila my)
  local y1=my-1; local y2=my
  f.button(mon,2,y1,"<<<"); f.button(mon,6,y1,"<<"); f.button(mon,10,y1,"<")
  f.button(mon,14,y1,S.autoOut and "OUT:AU" or "OUT:MA", S.autoOut and colors.green or colors.orange)
  f.button(mon,mx-13,y1,">"); f.button(mon,mx-9,y1,">>"); f.button(mon,mx-5,y1,">>>")

  f.button(mon,2,y2,"<<<"); f.button(mon,6,y2,"<<"); f.button(mon,10,y2,"<")
  f.button(mon,14,y2,S.autoIn and "IN:AU" or "IN:MA", S.autoIn and colors.green or colors.orange)
  f.button(mon,mx-13,y2,">"); f.button(mon,mx-9,y2,">>"); f.button(mon,mx-5,y2,">>>")
end

local function handleTouch(x,y)
  local mon=S.mon; local mx,my=mon.getSize()
  local function inRect(cx,cy,label) return x>=cx and x<=cx+#label-1 and y==cy end

  -- SETUP siempre visible
  if inRect(mx-10,2,"SETUP") then setupWizard(); return end

  -- MODE toggle (SAT/GEN)
  local modeLabel = "MODE:"..S.modeOut
  local modeX = math.max(2, (mx - 10) - (#modeLabel + 2))
  if inRect(modeX,2,modeLabel) then S.modeOut = (S.modeOut=="SAT") and "GEN" or "SAT"; return end

  -- OUT manual
  local y1=my-1
  if inRect(2,y1,"<<<") then S.setOut=S.setOut-100000; S.autoOut=false end
  if inRect(6,y1,"<<") then S.setOut=S.setOut-10000;  S.autoOut=false end
  if inRect(10,y1,"<") then S.setOut=S.setOut-1000;   S.autoOut=false end
  if inRect(14,y1,S.autoOut and "OUT:AU" or "OUT:MA") then S.autoOut=not S.autoOut end
  if inRect(mx-13,y1,">") then S.setOut=S.setOut+1000;   S.autoOut=false end
  if inRect(mx-9,y1,">>") then S.setOut=S.setOut+10000;  S.autoOut=false end
  if inRect(mx-5,y1,">>>") then S.setOut=S.setOut+100000; S.autoOut=false end

  -- IN manual
  local y2=my
  if inRect(2,y2,"<<<") then S.setIn=S.setIn-100000; S.autoIn=false end
  if inRect(6,y2,"<<") then S.setIn=S.setIn-10000;  S.autoIn=false end
  if inRect(10,y2,"<") then S.setIn=S.setIn-1000;   S.autoIn=false end
  if inRect(14,y2,S.autoIn and "IN:AU" or "IN:MA") then S.autoIn=not S.autoIn end
  if inRect(mx-13,y2,">") then S.setIn=S.setIn+1000;   S.autoIn=false end
  if inRect(mx-9,y2,">>") then S.setIn=S.setIn+10000;  S.autoIn=false end
  if inRect(mx-5,y2,">>>") then S.setIn=S.setIn+100000; S.autoIn=false end
end

-- ========= LOOPS =========
local function uiLoop()
  while true do
    local ev, side, x, y = os.pullEvent()
    if ev=="monitor_touch" then handleTouch(x,y) end
  end
end

local function tickLoop()
  while true do
    local now=os.clock(); local dt=now-S.lastT; S.lastT=now
    local info=rxInfo(); if not info then S.action="Reactor info error" else controlTick(info,dt); draw(info) end
    sleep(CFG.UI_TICK)
  end
end

local function main()
  term.clear(); term.setCursorPos(1,1); print("ATM10 Draconic Reactor Controller — starting...")
  S.mon = pickMonitor(); if not S.mon then error("Conecta un monitor por módem") end
  discover()
  print("Periféricos:")
  print("  Reactor:", S.rxName)
  print("  Monitor:", S.monName)
  print("  IN gate:", S.inName)
  print("  OUT gate:", S.outName)
  parallel.waitForAny(tickLoop, uiLoop)
end

local ok, err = pcall(main)
if not ok then if S.mon then f.clear(S.mon); S.mon.setCursorPos(2,2); S.mon.write("Error:"); S.mon.setCursorPos(2,3); S.mon.write(err or "unknown") end error(err) end
