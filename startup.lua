-- ATM10 Draconic Reactor Controller — HUD con pestañas + Animaciones + Sonidos
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
  error("No se pudo cargar la librería 'f' (lib/f.lua')")
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
  mon=nil, rx=nil, out=nil, inp=nil, spk=nil,
  rxName=nil, monName=nil, inName=nil, outName=nil,
  modeOut="SAT",
  setIn=220000, setOut=500000,
  iErrIn=0, iErrOut=0,
  satMA=nil, fieldMA=nil, genMA=nil, tempMA=nil,
  satPrev=nil, lastT=os.clock(), dSat=0,
  action="Boot",
  view="DASH",
  histSAT={}, histField={}, histTemp={},
  alarmActive=false,
}

-- ========= Sonido =========
local function play(sound)
  if not S.spk then return end
  pcall(function() S.spk.playSound(sound) end)
end
local function playNote(inst,oct,vol)
  if not S.spk then return end
  pcall(function() S.spk.playNote(inst,oct,vol) end)
end

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
  local rx,mon,spk; local gates={}
  for _,n in ipairs(names) do
    if n:find("draconic_reactor") then rx=n end
    if n:find("monitor") then mon=n end
    if n:find("speaker") then spk=n end
    if n:find("flow_gate") then gates[#gates+1]=n end
  end
  return rx, mon, gates, spk
end

local function discover()
  local map=loadTbl(CFG.CFG_FILE)
  local rx,mon,gates,spk=detect()
  if not rx then error("No se detecta reactor") end
  if not mon then error("No se detecta monitor") end
  if #gates<2 then error("Necesitas 2 flow_gate") end
  if not map then
    map={reactor=rx, monitor=mon, in_gate=gates[1], out_gate=gates[2], modeOut=S.modeOut}
    saveTbl(CFG.CFG_FILE,map)
  end
  if map.modeOut then S.modeOut=map.modeOut end
  if spk then S.spk=peripheral.wrap(spk) end
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

  -- Historial
  table.insert(S.histSAT, S.satMA); if #S.histSAT>CFG.HIST_SIZE then table.remove(S.histSAT,1) end
  table.insert(S.histField, S.fieldMA); if #S.histField>CFG.HIST_SIZE then table.remove(S.histField,1) end
  table.insert(S.histTemp, S.tempMA); if #S.histTemp>CFG.HIST_SIZE then table.remove(S.histTemp,1) end

  -- Alarma crítica
  if (info.fieldP < 15 or info.temp > 7900) and not S.alarmActive then
    S.alarmActive=true
    for i=1,5 do playNote("snare",3,2); sleep(0.2) end
  elseif info.fieldP >= 20 and info.temp < 7800 then
    S.alarmActive=false
  end
end

-- ========= Animaciones =========
local function animBoot(mon,map)
  f.clear(mon); mon.setTextScale(1)
  mon.setCursorPos(2,3); mon.write("Initializing Reactor Controller...")
  for i=1,20 do
    local pct=i*5
    mon.setCursorPos(2,5)
    mon.write("["..string.rep("#",i)..string.rep(" ",20-i).."] "..pct.."% ")
    sleep(0.05)
  end
  sleep(0.5)

  -- Chequeo periféricos
  f.clear(mon); mon.setCursorPos(2,3)
  local function check(name, ok)
    if ok then
      mon.setTextColor(colors.green); mon.write("> "..name.." .......... OK\n"); play("minecraft:block.note_block.pling")
    else
      mon.setTextColor(colors.red); mon.write("> "..name.." .......... FAIL\n"); playNote("bass",1,1)
    end
    mon.setTextColor(colors.white)
  end
  check("Reactor ("..(map.reactor or "?")..")", map.reactor and peripheral.isPresent(map.reactor))
  check("Monitor ("..(map.monitor or "?")..")", map.monitor and peripheral.isPresent(map.monitor))
  check("FluxGate IN ("..(map.in_gate or "?")..")", map.in_gate and peripheral.isPresent(map.in_gate))
  check("FluxGate OUT("..(map.out_gate or "?")..")", map.out_gate and peripheral.isPresent(map.out_gate))
  check("Mode ["..(S.modeOut or "?").."]", true)
  sleep(2)
end

local function animCharging(mon,fieldPct)
  f.clear(mon); mon.setTextScale(1)
  mon.setCursorPos(2,5); mon.write("Reactor Charging...")
  local barW=30
  local fill=math.floor((fieldPct/100)*barW)
  mon.setCursorPos(2,7)
  mon.write("["..string.rep("=",fill)..string.rep(" ",barW-fill).."] "..math.floor(fieldPct).."%")
  if fieldPct>=50 then
    mon.setCursorPos(2,9); mon.setTextColor(colors.green); mon.write("Ready to Activate"); mon.setTextColor(colors.white)
  end
end

-- ========= HUD =========
-- (aquí mantienes drawGraph, drawDash, drawCtrl y draw igual que antes con gráficas y colores)
-- por brevedad no lo repito, solo añadimos sonidos en boot y alarma en controlTick
-- ========= Loops, MAIN =========
-- (igual que la última versión, solo cambiamos animBoot(S.mon,map) en main)

local function main()
  local map=discover()
  S.rx=peripheral.wrap(map.reactor); S.rxName=map.reactor
  S.mon=peripheral.wrap(map.monitor); S.monName=map.monitor
  S.inp=peripheral.wrap(map.in_gate); S.inName=map.in_gate
  S.out=peripheral.wrap(map.out_gate); S.outName=map.out_gate
  animBoot(S.mon,map)
  parallel.waitForAny(tickLoop,uiLoop)
end

main()
