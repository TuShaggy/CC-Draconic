-- ATM10 Draconic Reactor Controller — Auto-update + HUD nuevo + Setup

-- ===== AUTO-UPDATE =====
local REPO = "https://raw.githubusercontent.com/TuShaggy/CC-Draconic/main/"
local FILES = {"startup.lua"}

local function updateFromGit()
  for _,file in ipairs(FILES) do
    local url = REPO..file
    local h = http.get(url)
    if h then
      local f = fs.open(file,"w")
      f.write(h.readAll())
      f.close()
      h.close()
      print("Actualizado "..file.." desde GitHub.")
    else
      print("No se pudo actualizar "..file.." (sin internet?)")
    end
  end
end

updateFromGit()

-- ===== HELPERS =====
local function load_f()
  if fs.exists("lib/f.lua") then
    local ok, mod = pcall(dofile, "lib/f.lua")
    if ok and type(mod)=="table" then return mod end
  end
  if fs.exists("lib/f") then
    local ok = pcall(os.loadAPI, "lib/f")
    if ok and type(_G.f)=="table" then return _G.f end
  end
  -- fallback mínimo
  return {
    clear = function(mon)
      mon.setBackgroundColor(colors.black)
      mon.clear()
      mon.setCursorPos(1,1)
    end,
    format_int = function(n)
      local s=tostring(math.floor(n))
      local out=""
      while #s>3 do
        out=","..string.sub(s,-3)..out
        s=string.sub(s,1,-4)
      end
      return s..out
    end
  }
end
local f = load_f()

-- ===== STATE =====
local CFG = { UI_TICK=0.25 }
local S = { mon=nil, rx=nil, inp=nil, out=nil, modeOut="SAT", view="DASH", buttons={} }

-- ===== SETUP =====
local function setup()
  local names=peripheral.getNames()
  local reactors,mons,gates={}, {}, {}
  for _,n in ipairs(names) do
    if n:find("draconic_reactor") then reactors[#reactors+1]=n end
    if n:find("monitor") then mons[#mons+1]=n end
    if n:find("flow_gate") then gates[#gates+1]=n end
  end

  local function choose(list,label)
    print("Selecciona "..label..":")
    for i,n in ipairs(list) do print(i..") "..n) end
    local c
    repeat write("> "); c=tonumber(read()) until c and c>=1 and c<=#list
    return list[c]
  end

  local rx=choose(reactors,"reactor")
  local mon=choose(mons,"monitor")
  local in_gate=choose(gates,"flux gate IN")
  local out_gate=choose(gates,"flux gate OUT")

  local cfg={reactor=rx, monitor=mon, in_gate=in_gate, out_gate=out_gate}
  local f=fs.open("config.lua","w")
  f.write("return "..textutils.serialize(cfg))
  f.close()
  return cfg
end

local function loadConfig()
  if fs.exists("config.lua") then return dofile("config.lua") else return setup() end
end

-- ===== UTILS =====
local function pct(n,d) if not n or d==0 then return 0 end return (n/d)*100 end
local function rxInfo()
  local ok, info = pcall(S.rx.getReactorInfo)
  if not ok or not info then return nil end
  return {
    status=info.status or "unknown",
    gen=info.generationRate or 0,
    temp=info.temperature or 0,
    satP=pct(info.energySaturation, info.maxEnergySaturation),
    fieldP=pct(info.fieldStrength, info.maxFieldStrength),
  }
end

-- ===== UI ELEMENTS =====
local function drawBar(mon,x,y,w,val)
  local filled=math.floor((val/100)*w)
  mon.setCursorPos(x,y)
  local color=colors.green
  if val>95 or val<20 then color=colors.red elseif val>85 or val<30 then color=colors.yellow end
  mon.setBackgroundColor(color); mon.write(string.rep(" ",filled))
  mon.setBackgroundColor(colors.black); mon.write(string.rep(" ",w-filled))
end

local function drawButton(id,x1,y1,x2,y2,label,active)
  local mon=S.mon
  S.buttons[id]={x1=x1,y1=y1,x2=x2,y2=y2}
  for y=y1,y2 do
    mon.setCursorPos(x1,y)
    if active then mon.setBackgroundColor(colors.orange); mon.setTextColor(colors.black)
    else mon.setBackgroundColor(colors.gray); mon.setTextColor(colors.white) end
    local pad = math.max(0, math.floor((x2-x1+1-#label)/2))
    if y==math.floor((y1+y2)/2) then
      mon.write(string.rep(" ",pad)..label..string.rep(" ",(x2-x1+1-#label-pad)))
    else
      mon.write(string.rep(" ",x2-x1+1))
    end
  end
  mon.setBackgroundColor(colors.black); mon.setTextColor(colors.white)
end

-- DASH
local function drawDash(info)
  local mon=S.mon; mon.setTextScale(1); f.clear(mon)
  local mx,my=mon.getSize()
  mon.setCursorPos(math.floor(mx/2)-5,1); mon.write("REACTOR DASH")
  mon.setCursorPos(2,3); mon.write("SAT")
  drawBar(mon,6,3,mx-8, info.satP)
  mon.setCursorPos(2,5); mon.write("Field")
  drawBar(mon,8,5,mx-10, info.fieldP)
  mon.setCursorPos(2,7); mon.write(("Gen: %s RF/t"):format(f.format_int(info.gen)))
  mon.setCursorPos(2,8); mon.write(("Temp: %d C"):format(info.temp))
  drawButton("CTRL", math.floor(mx/2)-5, my-2, math.floor(mx/2)+5, my-1, "Controles", false)
end

-- CTRL
local function drawCtrl(info)
  local mon=S.mon; mon.setTextScale(1); f.clear(mon)
  local mx,my=mon.getSize()
  mon.setCursorPos(math.floor(mx/2)-4,1); mon.write("MODOS")
  local modes={"SAT","MAXGEN","ECO","TURBO","PROTECT"}
  for i,m in ipairs(modes) do
    local x1=2+(i-1)*8
    drawButton(m,x1,3,x1+6,5,m,m==S.modeOut)
  end
  drawButton("BACK", math.floor(mx/2)-4, my-2, math.floor(mx/2)+4, my-1, "Volver", false)
end

local function draw(info)
  if S.view=="DASH" then drawDash(info) else drawCtrl(info) end
end

-- ===== LOOPS =====
local function uiLoop()
  while true do
    local _,_,x,y=os.pullEvent("monitor_touch")
    for id,btn in pairs(S.buttons) do
      if x>=btn.x1 and x<=btn.x2 and y>=btn.y1 and y<=btn.y2 then
        if id=="CTRL" then S.view="CTRL"
        elseif id=="BACK" then S.view="DASH"
        else S.modeOut=id end
      end
    end
  end
end

local function tickLoop()
  while true do
    local info=rxInfo()
    if info then draw(info) end
    sleep(CFG.UI_TICK)
  end
end

-- ===== MAIN =====
local function main()
  local cfg=loadConfig()
  S.rx=peripheral.wrap(cfg.reactor)
  S.mon=peripheral.wrap(cfg.monitor)
  S.inp=peripheral.wrap(cfg.in_gate)
  S.out=peripheral.wrap(cfg.out_gate)
  parallel.waitForAny(tickLoop,uiLoop)
end

main()
