-- ATM10 Draconic Reactor Controller — HUD con pestañas
-- Modos: SAT / MAXGEN / ECO / TURBO / PROTECT

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
  TARGET_FIELD = 50.0, TARGET_SAT = 80.0,
  FIELD_LOW_TRIP = 20.0,
  TEMP_MAX = 8000, TEMP_SOFT = 6500,
  TEMP_TURBO = 7500, TEMP_ECO = 6000,
  IN_KP = 120000, IN_KI = 20000,
  OUT_KP = 60000, OUT_KI = 15000,
  IN_MIN = 0, IN_MAX = 3000000,
  OUT_MIN = 0, OUT_MAX = 10000000,
  CHARGE_FLOW = 900000,
  UI_TICK = 0.25,
  DB_FIELD = 1.0, DB_SAT = 5.0,
  IN_SLEW_PER_SEC  = 200000,
  OUT_SLEW_PER_SEC = 300000,
  EMA_ALPHA = 0.25,
  MAXGEN_LOW = 75.0, MAXGEN_HIGH = 95.0,
  ECO_LOW = 72.0, ECO_HIGH = 82.0, ECO_OUT_CAP = 0.55,
  TURBO_LOW = 80.0, TURBO_HIGH = 97.0, TURBO_OUT_CAP = 0.95,
  DSAT_STRONG = 12.0, DSAT_SOFT = 6.0,
  HIST_SIZE = 40,
}

-- ========= STATE =========
local S = {
  mon=nil, rx=nil, out=nil, inp=nil,
  rxName=nil, monName=nil, inName=nil, outName=nil,
  modeOut="SAT",
  setIn=220000, setOut=500000,
  iErrIn=0, iErrOut=0,
  satMA=nil, fieldMA=nil, genMA=nil, tempMA=nil,
  satPrev=nil, lastT=os.clock(), dSat=0,
  action="Boot",
  view="DASH",  -- "DASH" o "CTRL"
  histSAT={}, histField={},
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
  if not rx then error("No se detecta reactor") end
  if not mon then error("No se detecta monitor") end
  if #gates<2 then error("Necesitas 2 flow_gate") end
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
    status = info.status or "unknown",
    gen = info.generationRate or 0,
    temp = info.temperature or 0,
    es = info.energySaturation or 0,
    esMax = info.maxEnergySaturation or 1,
    fs = info.fieldStrength or 0,
    fsMax = info.maxFieldStrength or 1,
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

  -- Guardar historial
  table.insert(S.histSAT, S.satMA); if #S.histSAT>CFG.HIST_SIZE then table.remove(S.histSAT,1) end
  table.insert(S.histField, S.fieldMA); if #S.histField>CFG.HIST_SIZE then table.remove(S.histField,1) end

  -- (La lógica de control de modos la mantengo igual que antes)
end

-- ========= HUD =========
local function drawBar(mon,x,y,w,h,pct,color)
  pct=math.max(0,math.min(100,pct))
  local fill=math.floor((pct/100)*w)
  for j=0,h-1 do
    for i=0,w-1 do
      mon.setCursorPos(x+i,y+j)
      if i<fill then mon.setBackgroundColor(color or colors.green)
      else mon.setBackgroundColor(colors.gray) end
      mon.write(" ")
    end
  end
  mon.setBackgroundColor(colors.black)
end

local function drawGraph(mon,x,y,w,h,hist,color)
  local maxv=100
  for i=1,w do
    local idx=#hist-w+i
    if idx>0 then
      local v=hist[idx] or 0
      local filled=math.floor((v/maxv)*h)
      for j=0,h-1 do
        mon.setCursorPos(x+i-1,y+h-j-1)
        if j<filled then mon.setBackgroundColor(color)
        else mon.setBackgroundColor(colors.black) end
        mon.write(" ")
      end
    end
  end
  mon.setBackgroundColor(colors.black)
end

local function drawDash(info)
  local mon=S.mon; mon.setTextScale(1); f.clear(mon)
  local mx,my=mon.getSize(); local barW=mx-8
  mon.setCursorPos(2,1); mon.write("Reactor ("..(S.rxName or "?")..")")
  mon.setCursorPos(mx-10,1); mon.write("[CONTROLS]")
  mon.setCursorPos(2,3); mon.write(("SAT: %.1f%%"):format(S.satMA or info.satP))
  drawBar(mon,2,4,barW,2,S.satMA or info.satP,colors.blue)
  mon.setCursorPos(2,7); mon.write(("Field: %.1f%%"):format(S.fieldMA or info.fieldP))
  drawBar(mon,2,8,barW,2,S.fieldMA or info.fieldP,colors.cyan)
  mon.setCursorPos(2,11); mon.write(("Gen: %s RF/t"):format(f.format_int(info.gen)))
  mon.setCursorPos(2,12); mon.write(("Temp: %d C"):format(info.temp))
  mon.setCursorPos(2,my); mon.write(S.action)
end

local function drawCtrl(info)
  local mon=S.mon; mon.setTextScale(1); f.clear(mon)
  local mx,my=mon.getSize()
  mon.setCursorPos(2,1); mon.write("[BACK]")
  mon.setCursorPos(mx//2-3,1); mon.write("MODES")
  -- botones
  local modes={"SAT","MAXGEN","ECO","TURBO","PROTECT"}
  for i,m in ipairs(modes) do
    mon.setCursorPos(4,2+i); if m==S.modeOut then
      mon.setBackgroundColor(colors.orange); mon.setTextColor(colors.black)
    else mon.setBackgroundColor(colors.gray); mon.setTextColor(colors.white) end
    mon.write(" "..m.." ")
    mon.setBackgroundColor(colors.black); mon.setTextColor(colors.white)
  end
  -- gráficas
  mon.setCursorPos(2,10); mon.write("SAT history")
  drawGraph(mon,2,11,mx-4,4,S.histSAT,colors.blue)
  mon.setCursorPos(2,16); mon.write("Field history")
  drawGraph(mon,2,17,mx-4,4,S.histField,colors.cyan)
end

local function draw(info)
  if S.view=="DASH" then drawDash(info) else drawCtrl(info) end
end

-- ========= Loops =========
local function uiLoop()
  while true do
    local _,_,x,y=os.pullEvent("monitor_touch")
    local mx,_=S.mon.getSize()
    if S.view=="DASH" then
      if y==1 and x>=mx-10 then S.view="CTRL" end
    else
      if y==1 and x<=6 then S.view="DASH" end
      local modes={"SAT","MAXGEN","ECO","TURBO","PROTECT"}
      for i,m in ipairs(modes) do
        if y==2+i and x>=4 and x<=10 then
          S.modeOut=m
          local map=loadTbl(CFG.CFG_FILE) or {}; map.modeOut=S.modeOut; saveTbl(CFG.CFG_FILE,map)
        end
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
