-- ATM10 Draconic Reactor Controller — startup.lua (final)
-- Incluye autodetección, HUD completo, control PI, failsafes
-- y setup visual con puntero para elegir IN/OUT gates.
-- Autor: Fabian + ChatGPT

-- ===== Helpers =====
local function load_f()
  if fs.exists("lib/f.lua") then
    local ok, mod = pcall(dofile, "lib/f.lua")
    if ok and type(mod)=="table" then return mod end
  end
  if fs.exists("lib/f") then
    local ok = pcall(os.loadAPI, "lib/f")
    if ok and type(_G.f)=="table" then return _G.f end
  end
  error("No se pudo cargar la librería 'f'")
end
local f = load_f()

-- ========= CONFIG =========
local CFG = {
  CFG_FILE = "config.lua",
  TARGET_FIELD = 50.0,
  TARGET_SAT   = 65.0,
  TARGET_GEN_RFPT = 3000000,
  FIELD_LOW_TRIP = 20.0,
  TEMP_MAX = 8000,
  TEMP_SAFE = 3000,
  IN_KP = 120000, IN_KI = 20000,
  OUT_KP = 120000, OUT_KI = 30000,
  IN_MIN = 0, IN_MAX = 3000000,
  OUT_MIN = 0, OUT_MAX = 10000000,
  CHARGE_FLOW = 900000,
  UI_TICK = 0.25,
  DB_FIELD = 1.0,
  DB_SAT = 2.0,
  DB_GEN = 0.02,
}

-- ========= STATE =========
local S = {
  mon=nil, rx=nil, out=nil, inp=nil,
  monName=nil, rxName=nil, outName=nil, inName=nil,
  autoIn=true, autoOut=true,
  setIn=220000, setOut=500000,
  iErrIn=0, iErrOut=0,
  lastT=os.clock(),
  action="Boot",
  alarm=false,
  modeOut="SAT",
}

-- ========= Persistencia =========
local function saveTbl(path, tbl)
  local h=fs.open(path,"w"); h.write("return "..textutils.serialize(tbl)); h.close() end
local function loadTbl(path)
  if not fs.exists(path) then return nil end
  local ok,t=pcall(dofile,path); if ok and type(t)=="table" then return t end end

-- ========= Descubrimiento =========
local function detect()
  local names=peripheral.getNames()
  local reactor,monitor
  for _,n in ipairs(names) do if n:find("draconic_reactor") then reactor=n end end
  for _,n in ipairs(names) do if n:find("monitor") then monitor=n end end
  local gates={}
  for _,n in ipairs(names) do if n:find("flow_gate") then table.insert(gates,n) end end
  return reactor, monitor, gates
end

-- ========= Reactor Info =========
local function pct(n,d) if not n or not d or d==0 then return 0 end return (n/d)*100 end
local function rxInfo()
  local ok, info = pcall(S.rx.getReactorInfo)
  if not ok or not info then return nil end
  local t = {
    status = info.status or info.state or "unknown",
    gen = info.generationRate or 0,
    temp = info.temperature or 0,
    es = info.energySaturation or 0,
    esMax = info.maxEnergySaturation or 1,
    fs = info.fieldStrength or 0,
    fsMax = info.maxFieldStrength or 1,
    fc = info.fuelConversion or 0,
    fcMax = info.maxFuelConversion or 1,
  }
  t.satP = pct(t.es,t.esMax)
  t.fieldP = pct(t.fs,t.fsMax)
  return t
end

-- ========= Flux wrapper =========
local function wrapFluxSetter(p)
  local api={}
  if type(p.getSignalLowFlow)=="function" then
    api.get=function() return p.getSignalLowFlow() end
    api.set=function(v) return p.setSignalLowFlow(math.max(0,math.floor(v))) end
  else
    api.get=function() return p.getFlow() end
    local setter=p.setFlow or p.setFlowOverride
    api.set=function(v) return setter(math.max(0,math.floor(v))) end
  end
  api.raw=p; return api
end

-- ========= Setup visual =========
local function setupWizard()
  local reactor,monitor,gates=detect()
  if not reactor then error("No se detecta reactor (draconic_reactor_*)") end
  if not monitor then error("No se detecta monitor (monitor_*)") end
  if #gates<2 then error("No se detectan al menos 2 flow_gate_*") end

  local sel={rx=reactor, mon=monitor, inIdx=1, outIdx=2}
  local monP=peripheral.wrap(monitor)
  local monW,monH=monP.getSize()

  local function draw()
    f.clear(monP); monP.setTextScale(0.5)
    monP.setCursorPos(2,2); monP.write("SETUP VISUAL — Selecciona periféricos")

    monP.setCursorPos(2,4); monP.write("Reactor: "..(sel.rx or "?"))
    monP.setCursorPos(2,6); monP.write("Monitor: "..(sel.mon or "?"))

    monP.setCursorPos(2,8); monP.write("Input Gate (IN):")
    for i,n in ipairs(gates) do
      monP.setCursorPos(4,9+i)
      if i==sel.inIdx then
        monP.setBackgroundColor(colors.blue); monP.write("> "..n.." <"); monP.setBackgroundColor(colors.black)
      else monP.write("  "..n) end
    end

    monP.setCursorPos(2,12+#gates); monP.write("Output Gate (OUT):")
    for i,n in ipairs(gates) do
      monP.setCursorPos(4,13+#gates+i)
      if i==sel.outIdx then
        monP.setBackgroundColor(colors.blue); monP.write("> "..n.." <"); monP.setBackgroundColor(colors.black)
      else monP.write("  "..n) end
    end

    f.button(monP,2,monH-4,"Autocalibrar",colors.orange)
    f.button(monP,2,monH-2,"Guardar & Iniciar",colors.green)
    f.button(monP,monW-10,monH-2,"Cancelar",colors.red)
  end

  draw()
  while true do
    local ev,_,x,y=os.pullEvent("monitor_touch")
    for i,_ in ipairs(gates) do
      if y==9+i then sel.inIdx=i; draw() end
      if y==13+#gates+i then sel.outIdx=i; draw() end
    end
    if y==monH-4 and x>=2 and x<=17 and #gates==2 then
      sel.inIdx=1; sel.outIdx=2; draw()
    end
    if y==monH-2 and x>=2 and x<=17 then
      if sel.inIdx==sel.outIdx then
        monP.setCursorPos(2,monH-1); monP.write("IN y OUT no pueden ser iguales")
      else
        local map={reactor=sel.rx, monitor=sel.mon, in_gate=gates[sel.inIdx], out_gate=gates[sel.outIdx]}
        saveTbl(CFG.CFG_FILE,map)
        return map
      end
    end
    if y==monH-2 and x>=monW-10 then error("Setup cancelado") end
  end
end

-- ========= Discover =========
local function discover()
  local map=loadTbl(CFG.CFG_FILE)
  local rx,mon,gates=detect()
  if not rx or not mon or #gates<2 then return setupWizard() end
  if not map then
    if #gates==2 then
      map={reactor=rx, monitor=mon, in_gate=gates[1], out_gate=gates[2]}
      saveTbl(CFG.CFG_FILE,map)
    else
      map=setupWizard()
    end
  end
  return map
end

-- ========= Control =========
local function clamp(v,lo,hi) if v<lo then return lo elseif v>hi then return hi else return v end end

local function controlTick(info, dt)
  if info.fieldP <= CFG.FIELD_LOW_TRIP then
    S.action="EMERG: Field low"; S.inp.set(CFG.CHARGE_FLOW); S.out.set(CFG.OUT_MIN)
    return
  end
  if info.temp >= CFG.TEMP_MAX then
    S.action="EMERG: Temp high"; S.out.set(CFG.OUT_MIN); return
  end

  if S.autoIn then
    local err = CFG.TARGET_FIELD - info.fieldP
    if math.abs(err)<=CFG.DB_FIELD then err=0 end
    S.iErrIn = clamp(S.iErrIn + err*dt,-1000,1000)
    S.setIn = clamp(S.setIn + (CFG.IN_KP*err + CFG.IN_KI*S.iErrIn)*dt,CFG.IN_MIN,CFG.IN_MAX)
    S.inp.set(S.setIn)
  end

  if S.autoOut then
    local err
    if S.modeOut=="SAT" then
      err=CFG.TARGET_SAT-info.satP; if math.abs(err)<=CFG.DB_SAT then err=0 end
    else
      local e=(CFG.TARGET_GEN_RFPT-info.gen)/CFG.TARGET_GEN_RFPT*100
      if math.abs(e)<=CFG.DB_GEN*100 then e=0 end
      err=e
    end
    S.iErrOut=clamp(S.iErrOut+err*dt,-1000,1000)
    S.setOut=clamp(S.setOut+(CFG.OUT_KP*err+CFG.OUT_KI*S.iErrOut)*dt,CFG.OUT_MIN,CFG.OUT_MAX)
    S.out.set(S.setOut)
  end

  S.action="IN="..f.si(S.setIn).." OUT="..f.si(S.setOut)
end

-- ========= UI =========
local function draw(info)
  local mon=S.mon; f.clear(mon)
  f.textLR(mon,2,2,"Reactor ("..(S.rxName or "?")..")",string.upper(info.status),colors.white,colors.lime)
  f.textLR(mon,2,4,"Gen",f.format_int(info.gen).." RF/t",colors.white,colors.white)
  f.textLR(mon,2,6,"Temp",f.format_int(info.temp).." C",colors.white,colors.red)
  f.textLR(mon,2,8,"Action",S.action,colors.gray,colors.gray)
end

-- ========= Loops =========
local function uiLoop()
  while true do local ev,_,x,y=os.pullEvent("monitor_touch") end end
local function tickLoop()
  while true do
    local now=os.clock(); local dt=now-S.lastT; S.lastT=now
    local info=rxInfo(); if info then controlTick(info,dt); draw(info) end
    sleep(CFG.UI_TICK)
  end
end

-- ========= MAIN =========
local function main()
  local map=discover()
  S.rx=peripheral.wrap(map.reactor); S.rxName=map.reactor
  S.mon=peripheral.wrap(map.monitor); S.monName=map.monitor
  S.inp=wrapFluxSetter(peripheral.wrap(map.in_gate)); S.inName=map.in_gate
  S.out=wrapFluxSetter(peripheral.wrap(map.out_gate)); S.outName=map.out_gate
  parallel.waitForAny(tickLoop,uiLoop)
end

main()
