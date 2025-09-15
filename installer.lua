-- ATM10 Draconic Reactor Controller — HUD rediseñado + botones funcionales

-- Helpers
local function load_f()
  if fs.exists("lib/f.lua") then
    local ok, mod = pcall(dofile, "lib/f.lua")
    if ok and type(mod)=="table" then return mod end
  end
  if fs.exists("lib/f") then
    local ok = pcall(os.loadAPI, "lib/f")
    if ok and type(_G.f)=="table" then return _G.f end
  end
  error("No se pudo cargar lib/f.lua")
end
local f = load_f()

-- CONFIG
local CFG = { UI_TICK=0.25, HIST_SIZE=40 }
local S = {
  mon=nil, rx=nil,
  modeOut="SAT", view="DASH",
  histSAT={}, histField={}, histTemp={},
  buttons={}
}

-- Utils
local function pct(n,d) if not n or d==0 then return 0 end return (n/d)*100 end
local function rxInfo()
  local ok, info = pcall(S.rx.getReactorInfo)
  if not ok or not info then return nil end
  local t={
    status=info.status, gen=info.generationRate,
    temp=info.temperature,
    satP=pct(info.energySaturation, info.maxEnergySaturation),
    fieldP=pct(info.fieldStrength, info.maxFieldStrength)
  }
  return t
end

-- Dibujar barra horizontal
local function drawBar(mon,x,y,w,val)
  local filled=math.floor((val/100)*w)
  mon.setCursorPos(x,y)
  mon.setBackgroundColor(colors.green)
  if val>90 or val<20 then mon.setBackgroundColor(colors.red)
  elseif val>80 or val<30 then mon.setBackgroundColor(colors.yellow) end
  mon.write(string.rep(" ",filled))
  mon.setBackgroundColor(colors.black)
  mon.write(string.rep(" ",w-filled))
end

-- Dibujar botón
local function drawButton(id,x1,y1,x2,y2,label,active)
  local mon=S.mon
  S.buttons[id]={x1=x1,y1=y1,x2=x2,y2=y2}
  for y=y1,y2 do
    mon.setCursorPos(x1,y)
    if active then
      mon.setBackgroundColor(colors.orange); mon.setTextColor(colors.black)
    else
      mon.setBackgroundColor(colors.gray); mon.setTextColor(colors.white)
    end
    local pad=math.max(0,(x2-x1+1-#label)//2)
    if y==(y1+y2)//2 then
      mon.write(string.rep(" ",pad)..label..string.rep(" ",(x2-x1+1-#label-pad)))
    else
      mon.write(string.rep(" ",x2-x1+1))
    end
  end
  mon.setBackgroundColor(colors.black); mon.setTextColor(colors.white)
end

-- DASH view
local function drawDash(info)
  local mon=S.mon; mon.setTextScale(1); f.clear(mon)
  local mx,my=mon.getSize()
  mon.setCursorPos(mx//2-5,1); mon.write("REACTOR DASH")
  mon.setCursorPos(2,3); mon.write("SAT")
  drawBar(mon,6,3,mx-8, info.satP)
  mon.setCursorPos(2,5); mon.write("Field")
  drawBar(mon,8,5,mx-10, info.fieldP)
  mon.setCursorPos(2,7); mon.write(("Gen: %s RF/t"):format(f.format_int(info.gen)))
  mon.setCursorPos(2,8); mon.write(("Temp: %d C"):format(info.temp))
  drawButton("CTRL", mx//2-5, my-2, mx//2+5, my-1, "Controles", false)
end

-- CTRL view
local function drawCtrl(info)
  local mon=S.mon; mon.setTextScale(1); f.clear(mon)
  local mx,my=mon.getSize()
  mon.setCursorPos(mx//2-4,1); mon.write("MODOS")
  local modes={"SAT","MAXGEN","ECO","TURBO","PROTECT"}
  for i,m in ipairs(modes) do
    local x1=2+(i-1)*8
    drawButton(m,x1,3,x1+6,5,m,m==S.modeOut)
  end
  drawButton("BACK", mx//2-4, my-2, mx//2+4, my-1, "Volver", false)
end

-- Dibujo
local function draw(info)
  if S.view=="DASH" then drawDash(info) else drawCtrl(info) end
end

-- UI Loop
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

-- Tick Loop
local function tickLoop()
  while true do
    local info=rxInfo()
    if info then draw(info) end
    sleep(CFG.UI_TICK)
  end
end

-- MAIN
local function main()
  local map={reactor="draconic_reactor_1", monitor="monitor_5"} -- o detect automático
  S.rx=peripheral.wrap(map.reactor)
  S.mon=peripheral.wrap(map.monitor)
  parallel.waitForAny(tickLoop,uiLoop)
end

main()
