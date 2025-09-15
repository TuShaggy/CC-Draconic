-- ATM10 Draconic Reactor Controller — startup.lua (3 modos: MAN, SAT, MAXGEN)
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
  TARGET_SAT   = 80.0,
  TARGET_GEN_RFPT = 3000000,
  FIELD_LOW_TRIP = 20.0,
  TEMP_MAX = 8000,
  TEMP_SAFE = 3000,
  IN_KP = 120000, IN_KI = 20000,
  OUT_KP = 60000, OUT_KI = 15000,
  IN_MIN = 0, IN_MAX = 3000000,
  OUT_MIN = 0, OUT_MAX = 10000000,
  CHARGE_FLOW = 900000,
  UI_TICK = 0.25,
  DB_FIELD = 1.0,
  DB_SAT = 5.0,
  DB_GEN = 0.02,
  IN_SLEW_PER_SEC  = 200000,
  OUT_SLEW_PER_SEC = 300000,
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
  modeOut="SAT",   -- MAN | SAT | MAXGEN
  satMA=nil, fieldMA=nil, genMA=nil,
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

-- ========= Control =========
local function clamp(v,lo,hi) if v<lo then return lo elseif v>hi then return hi else return v end end
local function slew(prev, desired, rate_per_sec, dt)
  local maxDelta = (rate_per_sec or 1e9) * (dt or 0)
  local delta = desired - prev
  if delta > maxDelta then return prev + maxDelta end
  if delta < -maxDelta then return prev - maxDelta end
  return desired
end

local function controlTick(info, dt)
  if not info then S.action="No reactor info"; return end

  -- EMA filters
  local a=0.25
  S.satMA   = S.satMA   and (S.satMA   + a*(info.satP - S.satMA))     or info.satP
  S.fieldMA = S.fieldMA and (S.fieldMA + a*(info.fieldP - S.fieldMA)) or info.fieldP
  S.genMA   = S.genMA   and (S.genMA   + a*(info.gen   - S.genMA))     or info.gen

  local sat   = S.satMA or info.satP
  local field = S.fieldMA or info.fieldP
  local gen   = S.genMA or info.gen

  -- Failsafes
  if field <= CFG.FIELD_LOW_TRIP then
    S.action="EMERG: Field low"; S.inp.set(CFG.CHARGE_FLOW); S.setOut=CFG.OUT_MIN; S.out.set(S.setOut); return
  end
  if info.temp >= CFG.TEMP_MAX then
    S.action="EMERG: Temp high"; S.setOut=CFG.OUT_MIN; S.out.set(S.setOut); return
  end

  -- IN control siempre PI (campo)
  if S.autoIn then
    local err = CFG.TARGET_FIELD - field
    if math.abs(err)<=CFG.DB_FIELD then err=0 end
    S.iErrIn=clamp(S.iErrIn+err*dt,-1000,1000)
    local desiredIn=clamp(S.setIn+(CFG.IN_KP*err+CFG.IN_KI*S.iErrIn)*dt,CFG.IN_MIN,CFG.IN_MAX)
    S.setIn=slew(S.setIn,desiredIn,CFG.IN_SLEW_PER_SEC,dt)
    S.inp.set(S.setIn)
  end

  -- OUT control según modo
  if S.modeOut=="MAN" then
    -- Manual: solo failsafes actúan, valores los mueve el operador
    S.out.set(S.setOut)
  elseif S.modeOut=="SAT" then
    local err = sat - CFG.TARGET_SAT
    if math.abs(CFG.TARGET_SAT - sat) <= CFG.DB_SAT then err=0 end
    S.iErrOut=clamp(S.iErrOut+err*dt,-1000,1000)
    local desiredOut=clamp(S.setOut+(CFG.OUT_KP*err+CFG.OUT_KI*S.iErrOut)*dt,CFG.OUT_MIN,CFG.OUT_MAX)
    S.setOut=slew(S.setOut,desiredOut,CFG.OUT_SLEW_PER_SEC,dt)
    S.out.set(S.setOut)
  elseif S.modeOut=="MAXGEN" then
    local desiredOut=S.setOut
    if sat > 95 then
      desiredOut=CFG.OUT_MAX*0.8
    elseif sat < 75 then
      desiredOut=CFG.OUT_MIN
    else
      desiredOut=CFG.OUT_MAX*0.7
    end
    if info.temp > 6500 then desiredOut=math.min(desiredOut,CFG.OUT_MAX*0.6) end
    S.setOut=slew(S.setOut,desiredOut,CFG.OUT_SLEW_PER_SEC,dt)
    S.out.set(S.setOut)
  end

  S.action="IN="..f.si(S.setIn).." OUT="..f.si(S.setOut).." | MODE="..S.modeOut
end

-- ========= HUD =========
local function drawBar(mon,x,y,w,pct,color)
  pct=math.max(0,math.min(100,pct))
  local fill=math.floor((pct/100)*w)
  for i=0,w-1 do
    mon.setCursorPos(x+i,y)
    if i<fill then
      mon.setBackgroundColor(color or colors.green)
    else
      mon.setBackgroundColor(colors.gray)
    end
    mon.write(" ")
  end
  mon.setBackgroundColor(colors.black)
end

local function drawMarker(mon,x,y,w,pct)
  local pos=x+math.floor((math.max(0,math.min(100,pct))/100)*w)
  if pos>x+w-1 then pos=x+w-1 end
  mon.setCursorPos(pos,y)
  mon.setBackgroundColor(colors.black)
  mon.setTextColor(colors.white)
  mon.write("|")
  mon.setTextColor(colors.white)
end

local function draw(info)
  local mon=S.mon
  mon.setTextScale(0.5)
  f.clear(mon)
  local mx,my=mon.getSize()
  local barW=math.max(20,math.min(50,mx-12))

  f.textLR(mon,2,2,"Reactor ("..(S.rxName or "?")..")",string.upper(info.status),colors.white,colors.lime)
  f.textLR(mon,2,4,"Gen",f.format_int(info.gen).." RF/t",colors.white,colors.white)
  f.textLR(mon,2,6,"Temp",f.format_int(info.temp).." C",colors.white,colors.red)

  mon.setCursorPos(2,8); mon.write("SAT: "..string.format("%.1f%%",S.satMA or info.satP))
  drawBar(mon,10,8,barW,S.satMA or info.satP,colors.blue)
  drawMarker(mon,10,8,barW,80)
  drawMarker(mon,10,8,barW,95)

  mon.setCursorPos(2,10); mon.write("Field: "..string.format("%.1f%%",S.fieldMA or info.fieldP))
  drawBar(mon,10,10,barW,S.fieldMA or info.fieldP,colors.cyan)
  drawMarker(mon,10,10,barW,50)

  f.textLR(mon,2,12,"Action",S.action,colors.gray,colors.gray)

  -- Botón de cambio de modo
  f.button(mon,mx-12,2,"MODE:"..S.modeOut,colors.orange)

  -- En manual, botones de ajuste
  if S.modeOut=="MAN" then
    f.button(mon,2,my-2,"OUT -",colors.red)
    f.button(mon,10,my-2,"OUT +",colors.green)
    f.button(mon,18,my-2,"IN -",colors.red)
    f.button(mon,26,my-2,"IN +",colors.green)
  end
end

-- ========= Loops =========
local function uiLoop()
  while true do
    local _,_,x,y=os.pullEvent("monitor_touch")
    local mx,my=S.mon.getSize()
    -- Botón de modo
    if y==2 and x>=mx-12 then
      if S.modeOut=="MAN" then S.modeOut="SAT"
      elseif S.modeOut=="SAT" then S.modeOut="MAXGEN"
      else S.modeOut="MAN" end
    end
    -- En manual, botones de ajuste
    if S.modeOut=="MAN" then
      if y==my-2 then
        if x>=2 and x<=7 then S.setOut=clamp(S.setOut-100000,CFG.OUT_MIN,CFG.OUT_MAX) end
        if x>=10 and x<=15 then S.setOut=clamp(S.setOut+100000,CFG.OUT_MIN,CFG.OUT_MAX) end
        if x>=18 and x<=23 then S.setIn=clamp(S.setIn-100000,CFG.IN_MIN,CFG.IN_MAX) end
        if x>=26 and x<=31 then S.setIn=clamp(S.setIn+100000,CFG.IN_MIN,CFG.IN_MAX) end
      end
    end
  end
end

local function tickLoop()
  while true do
    local now=os.clock(); local dt=now-S.lastT; S.lastT=now
    local info=rxInfo(); if info then controlTick(info,dt); draw(info) end
    sleep(CFG.UI_TICK)
  end
end

-- ========= Discover + MAIN =========
local function discover()
  local map=loadTbl(CFG.CFG_FILE)
  local rx,mon,gates=detect()
  if not rx or not mon or #gates<2 then error("Setup simplificado pendiente") end
  if not map then map={reactor=rx, monitor=mon, in_gate=gates[1], out_gate=gates[2]}; saveTbl(CFG.CFG_FILE,map) end
  return map
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
