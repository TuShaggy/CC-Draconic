-- ATM10 Draconic Reactor Controller — 5 modos automáticos
-- SAT / MAXGEN / ECO / TURBO / PROTECT
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
  error("No se pudo cargar la librería 'f' (lib/f.lua)")
end
local f = load_f()

-- ========= CONFIG =========
local CFG = {
  CFG_FILE = "config.lua",

  -- Objetivos base
  TARGET_FIELD = 50.0,
  TARGET_SAT   = 80.0,

  -- Límites y protección
  FIELD_LOW_TRIP = 20.0,
  TEMP_MAX = 8000,
  TEMP_SOFT = 6500,
  TEMP_TURBO = 7500,
  TEMP_ECO   = 6000,

  -- Control IN (campo)
  IN_KP = 120000, IN_KI = 20000,

  -- Control OUT (PI cuando aplica)
  OUT_KP = 60000, OUT_KI = 15000,

  -- Límites de flujos
  IN_MIN = 0, IN_MAX = 3000000,
  OUT_MIN = 0, OUT_MAX = 10000000,

  CHARGE_FLOW = 900000,

  -- UI / tasa de control
  UI_TICK = 0.25,

  -- Zonas muertas
  DB_FIELD = 1.0,
  DB_SAT   = 5.0,

  -- Rampas (slew)
  IN_SLEW_PER_SEC  = 200000,
  OUT_SLEW_PER_SEC = 300000,

  -- Filtros
  EMA_ALPHA = 0.25,

  -- MAXGEN bandas
  MAXGEN_LOW  = 75.0,
  MAXGEN_HIGH = 95.0,

  -- ECO bandas / topes
  ECO_LOW     = 72.0,
  ECO_HIGH    = 82.0,
  ECO_OUT_CAP = 0.55,

  -- TURBO bandas / topes
  TURBO_LOW     = 80.0,
  TURBO_HIGH    = 97.0,
  TURBO_OUT_CAP = 0.95,

  -- PROTECT
  DSAT_STRONG = 12.0,
  DSAT_SOFT   = 6.0,
}

-- ========= STATE =========
local S = {
  mon=nil, rx=nil, out=nil, inp=nil,
  monName=nil, rxName=nil, outName=nil, inName=nil,

  modeOut="SAT",

  setIn=220000, setOut=500000,
  iErrIn=0, iErrOut=0,

  satMA=nil, fieldMA=nil, genMA=nil, tempMA=nil,
  satPrev=nil, lastT=os.clock(), dSat=0,

  action="Boot",
}

-- ========= Persistencia =========
local function saveTbl(path, tbl)
  local h=fs.open(path,"w"); h.write("return "..textutils.serialize(tbl)); h.close()
end
local function loadTbl(path)
  if not fs.exists(path) then return nil end
  local ok,t=pcall(dofile,path); if ok and type(t)=="table" then return t end
end

-- ========= Descubrimiento =========
local function detect()
  local names=peripheral.getNames()
  local rx,mon; local gates={}
  for _,n in ipairs(names) do if n:find("draconic_reactor") then rx=n end end
  for _,n in ipairs(names) do if n:find("monitor") then mon=n end end
  for _,n in ipairs(names) do if n:find("flow_gate") then gates[#gates+1]=n end end
  return rx, mon, gates
end

local function discover()
  local map=loadTbl(CFG.CFG_FILE)
  local rx,mon,gates=detect()
  if not rx then error("No se detecta draconic_reactor_* (módem cableado)") end
  if not mon then error("No se detecta monitor_*") end
  if #gates<2 then error("Necesitas al menos 2 flow_gate_*") end

  if not map then
    map={reactor=rx, monitor=mon, in_gate=gates[1], out_gate=gates[2], modeOut=S.modeOut}
    saveTbl(CFG.CFG_FILE,map)
  end

  if map.modeOut then S.modeOut=map.modeOut end
  return map
end

-- ========= Utils =========
local function clamp(v,lo,hi) if v<lo then return lo elseif v>hi then return hi else return v end end
local function slew(prev, desired, rate_per_sec, dt)
  local maxDelta = (rate_per_sec or 1e9) * (dt or 0)
  local delta = desired - prev
  if delta > maxDelta then return prev + maxDelta end
  if delta < -maxDelta then return prev - maxDelta end
  return desired
end

-- ========= Reactor info =========
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
  t.satP   = pct(t.es,t.esMax)
  t.fieldP = pct(t.fs,t.fsMax)
  return t
end

-- ========= Control =========
local function controlTick(info, dt)
  if not info then S.action="No reactor info"; return end

  local a = CFG.EMA_ALPHA
  S.satMA   = S.satMA   and (S.satMA   + a*(info.satP   - S.satMA))   or info.satP
  S.fieldMA = S.fieldMA and (S.fieldMA + a*(info.fieldP - S.fieldMA)) or info.fieldP
  S.genMA   = S.genMA   and (S.genMA   + a*(info.gen    - S.genMA))   or info.gen
  S.tempMA  = S.tempMA  and (S.tempMA  + a*(info.temp   - S.tempMA))  or info.temp

  if S.satPrev then S.dSat = (S.satMA - S.satPrev) / math.max(dt,1e-3) else S.dSat=0 end
  S.satPrev = S.satMA

  local sat   = S.satMA
  local field = S.fieldMA
  local temp  = S.tempMA
  local gen   = S.genMA

  if field <= CFG.FIELD_LOW_TRIP then
    S.action="EMERG: Field low"
    S.inp.set(CFG.CHARGE_FLOW); S.setOut = CFG.OUT_MIN; S.out.set(S.setOut)
    return
  end
  if temp >= CFG.TEMP_MAX then
    S.action="EMERG: Temp high"
    S.setOut = CFG.OUT_MIN; S.out.set(S.setOut)
    return
  end

  local errF = CFG.TARGET_FIELD - field
  if math.abs(errF) <= CFG.DB_FIELD then errF = 0 end
  S.iErrIn = clamp(S.iErrIn + errF*dt, -1000, 1000)
  local desiredIn = clamp(S.setIn + (CFG.IN_KP*errF + CFG.IN_KI*S.iErrIn)*dt, CFG.IN_MIN, CFG.IN_MAX)
  S.setIn = slew(S.setIn, desiredIn, CFG.IN_SLEW_PER_SEC, dt)
  S.inp.set(S.setIn)

  local desiredOut = S.setOut

  if S.modeOut=="SAT" then
    local err = sat - CFG.TARGET_SAT
    if math.abs(CFG.TARGET_SAT - sat) <= CFG.DB_SAT then err = 0 end
    S.iErrOut = clamp(S.iErrOut + err*dt, -1000, 1000)
    desiredOut = clamp(S.setOut + (CFG.OUT_KP*err + CFG.OUT_KI*S.iErrOut)*dt, CFG.OUT_MIN, CFG.OUT_MAX)
    if S.dSat > CFG.DSAT_SOFT then
      desiredOut = math.min(desiredOut + S.dSat*40000, CFG.OUT_MAX*0.8)
    end

  elseif S.modeOut=="MAXGEN" then
    if sat > CFG.MAXGEN_HIGH then
      desiredOut = CFG.OUT_MAX * 0.8
    elseif sat < CFG.MAXGEN_LOW then
      desiredOut = CFG.OUT_MIN
    else
      desiredOut = CFG.OUT_MAX * 0.7
    end
    if temp > CFG.TEMP_SOFT then
      local k = 1 - math.min((temp - CFG.TEMP_SOFT) / (CFG.TEMP_MAX - CFG.TEMP_SOFT), 1)
      desiredOut = desiredOut * (0.4 + 0.6*k)
    end

  elseif S.modeOut=="ECO" then
    if sat > CFG.ECO_HIGH then
      desiredOut = math.min(S.setOut + (sat-CFG.ECO_HIGH)*40000, CFG.OUT_MAX*CFG.ECO_OUT_CAP)
    elseif sat < CFG.ECO_LOW then
      desiredOut = CFG.OUT_MIN
    else
      desiredOut = math.min(S.setOut, CFG.OUT_MAX*CFG.ECO_OUT_CAP)
    end
    if temp > CFG.TEMP_ECO then desiredOut = math.min(desiredOut, CFG.OUT_MAX*0.4) end

  elseif S.modeOut=="TURBO" then
    if sat > CFG.TURBO_HIGH then
      desiredOut = CFG.OUT_MAX * CFG.TURBO_OUT_CAP
    elseif sat < CFG.TURBO_LOW then
      desiredOut = CFG.OUT_MIN
    else
      desiredOut = CFG.OUT_MAX * (CFG.TURBO_OUT_CAP - 0.1)
    end
    if temp > CFG.TEMP_TURBO then desiredOut = math.min(desiredOut, CFG.OUT_MAX*0.7) end

  elseif S.modeOut=="PROTECT" then
    if sat < 60 or S.dSat < -CFG.DSAT_SOFT then
      desiredOut = CFG.OUT_MIN
    elseif sat > 90 or S.dSat > CFG.DSAT_STRONG then
      desiredOut = CFG.OUT_MAX * 0.6
    else
      desiredOut = math.min(S.setOut, CFG.OUT_MAX*0.5)
    end
    if temp > CFG.TEMP_SOFT then desiredOut = math.min(desiredOut, CFG.OUT_MAX*0.4) end
  end

  S.setOut = slew(S.setOut, desiredOut, CFG.OUT_SLEW_PER_SEC, dt)
  S.out.set(S.setOut)

  S.action = ("IN=%s OUT=%s | %s  SAT=%.1f%% dSAT=%.1f%%/s T=%dC")
    :format(f.si(S.setIn), f.si(S.setOut), S.modeOut, sat, S.dSat, temp)
end

-- ========= HUD =========
local function drawBar(mon,x,y,w,pct,color)
  pct=math.max(0,math.min(100,pct))
  local fill=math.floor((pct/100)*w)
  for i=0,w-1 do
    mon.setCursorPos(x+i,y)
    if i<fill then mon.setBackgroundColor(color or colors.green)
    else mon.setBackgroundColor(colors.gray) end
    mon.write(" ")
  end
  mon.setBackgroundColor(colors.black)
end

local function drawMarker(mon,x,y,w,pct)
  local pos=x+math.floor((math.max(0,math.min(100,pct))/100)*w)
  if pos>x+w-1 then pos=x+w-1 end
  mon.setCursorPos(pos,y); mon.setBackgroundColor(colors.black)
  mon.setTextColor(colors.white); mon.write("|"); mon.setTextColor(colors.white)
end

local function draw(info)
  local mon=S.mon
  mon.setTextScale(0.5)
  f.clear(mon)
  local mx,_=mon.getSize()
  local barW=math.max(20,math.min(50,mx-12))

  f.textLR(mon,2,2,"Reactor ("..(S.rxName or "?")..")",string.upper(info.status),colors.white,colors.lime)
  f.textLR(mon,2,4,"Gen",f.format_int(info.gen).." RF/t",colors.white,colors.white)
  f.textLR(mon,2,6,"Temp",f.format_int(info.temp).." C",colors.white,colors.red)

  mon.setCursorPos(2,8);  mon.write(("SAT: %.1f%%"):format(S.satMA or info.satP))
  drawBar(mon,10,8,barW,S.satMA or info.satP,colors.blue)
  drawMarker(mon,10,8,barW,80); drawMarker(mon,10,8,barW,95)

  mon.setCursorPos(2,10); mon.write(("Field: %.1f%%"):format(S.fieldMA or info.fieldP))
  drawBar(mon,10,10,barW,S.fieldMA or info.fieldP,colors.cyan)
  drawMarker(mon,10,10,barW,50)

  f.textLR(mon,2,12,"Action",S.action,colors.gray,colors.gray)

  f.button(mon,mx-14,2,"MODE:"..S.modeOut,colors.orange)
end

-- ========= Loops =========
local function uiLoop()
  while true do
    local _,_,x,y=os.pullEvent("monitor_touch")
    local mx,_=S.mon.getSize()
    if y==2 and x>=mx-14 then
      local order = { "SAT","MAXGEN","ECO","TURBO","PROTECT" }
      local idx=1
      for i,v in ipairs(order) do if v==S.modeOut then idx=i break end end
      S.modeOut = order[(idx % #order)+1]
      local map = loadTbl(CFG.CFG_FILE) or {}
      map.modeOut = S.modeOut; saveTbl(CFG.CFG_FILE,map)
    end
  end
end

local function tickLoop()
  while true do
    local now=os.clock(); local dt=now-S.lastT; S.lastT=now
    local info=rxInfo()
    if info then controlTick(info,dt); draw(info) end
    sleep(CFG.UI_TICK)
  end
end

-- ========= MAIN =========
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

local function main()
  local map=discover()
  S.rx=peripheral.wrap(map.reactor); S.rxName=map.reactor
  S.mon=peripheral.wrap(map.monitor); S.monName=map.monitor
  S.inp=wrapFluxSetter(peripheral.wrap(map.in_gate)); S.inName=map.in_gate
  S.out=wrapFluxSetter(peripheral.wrap(map.out_gate)); S.outName=map.out_gate
  parallel.waitForAny(tickLoop,uiLoop)
end

main()
