-- ATM10 Draconic Reactor Controller — Setup gráfico + Animación + HUD + POWER
-- Actualiza con installer.lua; este archivo no se auto-borra.

-- ===== STATE =====
local CFG = { UI_TICK = 0.2 }
local S = {
  mon=nil, rx=nil, inGate=nil, outGate=nil, spk=nil,
  view="BOOT", step=1, modeOut="SAT", hudStyle="CIRCLE",
  buttons={}, power=false, lastInfo=nil,
}

-- ===== LIB MIN (fallback si falta lib/f.lua) =====
local f
do
  if fs.exists("lib/f.lua") then
    local ok, mod = pcall(dofile, "lib/f.lua")
    if ok and type(mod)=="table" then f=mod end
  end
  if not f then
    f = {
      clear=function(m) m.setBackgroundColor(colors.black); m.clear(); m.setCursorPos(1,1) end,
      center=function(m,y,t) local w,_=m.getSize(); m.setCursorPos(math.floor(w/2-#t/2),y); m.write(t) end,
      box=function(m,x1,y1,x2,y2,bg) m.setBackgroundColor(bg or colors.gray); for y=y1,y2 do m.setCursorPos(x1,y); m.write(string.rep(" ",x2-x1+1)) end; m.setBackgroundColor(colors.black) end,
      format_int=function(n) local s=tostring(math.floor(n or 0)); local out=""; while #s>3 do out=","..s:sub(-3)..out; s=s:sub(1,-4) end; return s..out end,
      beep=function(s, snd) if s then pcall(function() s.playSound(snd or "minecraft:block.note_block.pling") end) end end,
    }
  end
end

-- ===== CONFIG =====
local function saveConfig(cfg) local h=fs.open("config.lua","w"); h.write("return "..textutils.serialize(cfg)); h.close() end
local function loadConfig() if fs.exists("config.lua") then local ok,c=pcall(dofile,"config.lua"); if ok and type(c)=="table" then return c end end end

-- ===== DETECCIÓN =====
local function detectPeripherals()
  local reactors,mons,gates,speakers={}, {}, {}, {}
  for _,n in ipairs(peripheral.getNames()) do
    if n:find("draconic_reactor") then reactors[#reactors+1]=n end
    if n:find("monitor") then mons[#mons+1]=n end
    if n:find("flow_gate") then gates[#gates+1]=n end
    if n:find("speaker") then speakers[#speakers+1]=n end
  end
  return reactors, mons, gates, speakers
end

-- ===== BOTONES =====
local function resetButtons() S.buttons={} end
local function regButton(id,x1,y1,x2,y2) S.buttons[id]={x1=x1,y1=y1,x2=x2,y2=y2} end

-- Botón compacto “redondito” 7x3 (estilos: CIRCLE/HEX/RHOMBUS/SQUARE)
local function drawShapeButton(id, cx, cy, label, active, style)
  local mon=S.mon
  local bg = active and colors.orange or colors.gray
  local fg = active and colors.black or colors.white
  mon.setTextColor(fg)
  local patterns = {
    CIRCLE  = { "  ###  ", " ## ## ", "  ###  " },
    HEX     = { "  ###  ", " ##### ", "  ###  " },
    RHOMBUS = { "   #   ", "  ###  ", "   #   " },
    SQUARE  = { " ##### ", " ##### ", " ##### " },
  }
  local pat = patterns[style or S.hudStyle] or patterns.CIRCLE
  local h, w = #pat, #pat[1]
  for dy=1,h do
    mon.setCursorPos(cx-math.floor(w/2), cy+dy-1)
    for i=1,w do
      mon.setBackgroundColor((pat[dy]:sub(i,i)=="#") and bg or colors.black)
      mon.write(" ")
    end
  end
  local lx = cx - math.floor(#label/2)
  mon.setCursorPos(lx, cy+h)
  mon.setTextColor(colors.white); mon.setBackgroundColor(colors.black); mon.write(label)
  regButton(id, cx-math.floor(w/2), cy, cx+math.floor(w/2), cy+h)
end

local function drawRectButton(id, x1, y1, w, label, active)
  local mon=S.mon; local x2=x1+w-1
  f.box(mon,x1,y1,x2,y1+2, active and colors.orange or colors.gray)
  mon.setTextColor(active and colors.black or colors.white)
  mon.setCursorPos(x1+1,y1+1); mon.write(label)
  mon.setTextColor(colors.white); regButton(id,x1,y1,x2,y1+2)
end

-- ===== ANIMACIÓN BOOT =====
local function drawBoot()
  local mon=S.mon; f.clear(mon); resetButtons()
  f.center(mon, 2, "DRACONIC REACTOR CONTROLLER")
  f.center(mon, 4, "Initializing...")
  local w,_=mon.getSize(); local barW=w-10
  for i=0,20 do
    local fill=math.floor((i/20)*barW)
    mon.setCursorPos(6,6); mon.setBackgroundColor(colors.gray); mon.write(string.rep(" ", barW))
    mon.setCursorPos(6,6); mon.setBackgroundColor(colors.orange); mon.write(string.rep(" ", fill))
    mon.setBackgroundColor(colors.black); sleep(0.05); f.beep(S.spk)
  end
end

-- ===== UI: SETUP =====
local function drawSetup()
  local mon=S.mon; f.clear(mon); resetButtons()
  local w,h=mon.getSize()
  f.center(mon, 1, "SETUP (elige por click)")
  local reactors, mons, gates = detectPeripherals()

  if S.step==1 then
    f.center(mon,3,"1) Reactor")
    for i,n in ipairs(reactors) do drawRectButton("rx:"..n, 4, 4+i*3, w-8, n, S.rx and peripheral.getName(S.rx)==n) end
  elseif S.step==2 then
    f.center(mon,3,"2) Monitor")
    for i,n in ipairs(mons) do drawRectButton("mn:"..n, 4, 4+i*3, w-8, n, S.mon and peripheral.getName(S.mon)==n) end
  elseif S.step==3 then
    f.center(mon,3,"3) Flux Gate IN (Field)")
    for i,n in ipairs(gates) do drawRectButton("in:"..n, 4, 4+i*3, w-8, n, S.inGate and peripheral.getName(S.inGate)==n) end
  elseif S.step==4 then
    f.center(mon,3,"4) Flux Gate OUT (Export)")
    for i,n in ipairs(gates) do drawRectButton("out:"..n, 4, 4+i*3, w-8, n, S.outGate and peripheral.getName(S.outGate)==n) end
  end

  drawRectButton("next", 4, h-4, 14, "Continuar ▶", false)
  drawRectButton("cancel", w-18, h-4, 14, "Cancelar", false)
end

-- ===== INFO REACTOR =====
local function getInfo()
  if not S.rx then return nil end
  local ok,info = pcall(S.rx.getReactorInfo); if not ok or not info then return nil end
  local function pct(n,d) if not n or not d or d==0 then return 0 end return (n/d)*100 end
  return {
    status=info.status or "unknown",
    gen=info.generationRate or 0,
    temp=info.temperature or 0,
    satP=pct(info.energySaturation, info.maxEnergySaturation),
    fieldP=pct(info.fieldStrength, info.maxFieldStrength),
  }
end

-- ===== UI: DASH / CTRL / HUD =====
local function drawDash(info)
  local mon=S.mon; f.clear(mon); resetButtons()
  local w,_=mon.getSize()
  f.center(mon,1,"DASH")
  mon.setCursorPos(3,3); mon.write(("SAT: %2d%%  FLD: %2d%%"):format(math.floor(info.satP or 0), math.floor(info.fieldP or 0)))
  mon.setCursorPos(3,4); mon.write(("GEN: %s RF/t   TMP: %d C"):format(f.format_int(info.gen or 0), info.temp or 0))
  drawShapeButton("CTRL",  math.floor(w/2)-10, 8, "CTRL",  false, S.hudStyle)
  drawShapeButton("HUD",   math.floor(w/2),     8, "HUD",   false, S.hudStyle)
  local pLbl = S.power and "OFF" or "ON"
  drawShapeButton("POWER", math.floor(w/2)+10,  8, pLbl,    S.power, S.hudStyle)
end

local function drawCtrl()
  local mon=S.mon; f.clear(mon); resetButtons()
  local w,_=mon.getSize(); f.center(mon,1,"MODOS")
  local modes={"SAT","MAXGEN","ECO","TURBO","PROTECT"}
  for i,m in ipairs(modes) do drawShapeButton(m, 6+(i-1)*12, 6, m, S.modeOut==m, S.hudStyle) end
  drawShapeButton("BACK", math.floor(w/2), 11, "BACK", false, S.hudStyle)
end

local function drawHUD()
  local mon=S.mon; f.clear(mon); resetButtons()
  local w,_=mon.getSize(); f.center(mon,1,"HUD SETTINGS")
  local styles={"CIRCLE","HEX","RHOMBUS","SQUARE"}
  for i,s in ipairs(styles) do drawShapeButton("style:"..s, 6+(i-1)*12, 6, s, S.hudStyle==s, s) end
  drawShapeButton("BACK", math.floor(w/2), 11, "BACK", false, S.hudStyle)
end

local function draw(info)
  if S.view=="BOOT" then
    drawBoot(); S.view = fs.exists("config.lua") and "DASH" or "SETUP"
  elseif S.view=="SETUP" then drawSetup()
  elseif S.view=="DASH" then drawDash(info or {})
  elseif S.view=="CTRL" then drawCtrl()
  elseif S.view=="HUD" then drawHUD()
  end
end

-- ===== POWER =====
local function reactor_set(active)
  if not S.rx then return end
  if active then
    if S.rx.chargeReactor then pcall(S.rx.chargeReactor) end
    if S.rx.activateReactor then pcall(S.rx.activateReactor) end
    if S.rx.setActive then pcall(S.rx.setActive, true) end
  else
    if S.rx.stopReactor then pcall(S.rx.stopReactor) end
    if S.rx.deactivateReactor then pcall(S.rx.deactivateReactor) end
    if S.rx.setActive then pcall(S.rx.setActive, false) end
  end
end

-- ===== LOOPS =====
local function uiLoop()
  while true do
    local _,_,x,y = os.pullEvent("monitor_touch")
    for id,b in pairs(S.buttons) do
      if x>=b.x1 and x<=b.x2 and y>=b.y1 and y<=b.y2 then
        if S.view=="SETUP" then
          if id=="next" then
            if S.step<4 then S.step=S.step+1
            else
              local cfg = {
                reactor=S.rx and peripheral.getName(S.rx) or nil,
                monitor=S.mon and peripheral.getName(S.mon) or nil,
                in_gate=S.inGate and peripheral.getName(S.inGate) or nil,
                out_gate=S.outGate and peripheral.getName(S.outGate) or nil,
                hud_style=S.hudStyle
              }
              saveConfig(cfg); S.view="DASH"
            end
          elseif id=="cancel" then S.step=1; S.rx=nil; S.mon=nil; S.inGate=nil; S.outGate=nil
          else
            local pfx,name = id:match("^(%a+):(.*)$")
            if pfx=="rx" then S.rx=peripheral.wrap(name); f.beep(S.spk)
            elseif pfx=="mn" then S.mon=peripheral.wrap(name); f.beep(S.spk)
            elseif pfx=="in" then S.inGate=peripheral.wrap(name); f.beep(S.spk)
            elseif pfx=="out" then S.outGate=peripheral.wrap(name); f.beep(S.spk)
            end
          end
        elseif S.view=="DASH" then
          if id=="CTRL" then S.view="CTRL"; f.beep(S.spk)
          elseif id=="HUD" then S.view="HUD"; f.beep(S.spk)
          elseif id=="POWER" then S.power=not S.power; reactor_set(S.power); f.beep(S.spk,"minecraft:block.note_block.basedrum")
          end
        elseif S.view=="CTRL" then
          if id=="BACK" then S.view="DASH"; f.beep(S.spk)
          elseif id=="SAT" or id=="MAXGEN" or id=="ECO" or id=="TURBO" or id=="PROTECT" then S.modeOut=id; f.beep(S.spk) end
        elseif S.view=="HUD" then
          if id=="BACK" then S.view="DASH"; f.beep(S.spk)
          else
            local st = id:match("^style:(.+)$")
            if st then
              S.hudStyle=st
              local cfg=loadConfig() or {}
              cfg.hud_style=st; saveConfig(cfg); f.beep(S.spk)
            end
          end
        end
      end
    end
  end
end

local function tickLoop()
  while true do
    if not S.spk then S.spk = peripheral.find("speaker") end
    if not S.mon then
      local cfg=loadConfig()
      if cfg and cfg.monitor then S.mon=peripheral.wrap(cfg.monitor) end
    end
    if S.mon then
      local info=getInfo(); S.lastInfo=info; draw(info)
    end
    sleep(CFG.UI_TICK)
  end
end

-- ===== MAIN =====
local function main()
  local cfg=loadConfig()
  if cfg then
    S.hudStyle=cfg.hud_style or S.hudStyle
    if cfg.monitor then S.mon=peripheral.wrap(cfg.monitor) end
    if cfg.reactor then S.rx=peripheral.wrap(cfg.reactor) end
    if cfg.in_gate then S.inGate=peripheral.wrap(cfg.in_gate) end
    if cfg.out_gate then S.outGate=peripheral.wrap(cfg.out_gate) end
  else
    local _,mons=detectPeripherals(); if mons[1] then S.mon=peripheral.wrap(mons[1]) end
  end
  if not S.mon then print("Conecta un monitor por modem cableado."); return end
  parallel.waitForAny(tickLoop, uiLoop)
end

main()
