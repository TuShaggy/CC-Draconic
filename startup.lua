-- ATM10 Draconic Reactor Controller — HUD + CTRL + HUD Settings

-- ===== HELPERS =====
local function load_f()
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
local S = { mon=nil, rx=nil, inp=nil, out=nil, modeOut="SAT", view="DASH", buttons={}, hudStyle="CIRCLE" }

-- ===== CONFIG =====
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

  local cfg={reactor=rx, monitor=mon, in_gate=in_gate, out_gate=out_gate, hud_style="CIRCLE"}
  local f=fs.open("config.lua","w")
  f.write("return "..textutils.serialize(cfg))
  f.close()
  return cfg
end

local function loadConfig()
  if fs.exists("config.lua") then
    local cfg = dofile("config.lua")
    S.hudStyle = cfg.hud_style or "CIRCLE"
    return cfg
  else
    return setup()
  end
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

-- ===== DRAW SHAPES =====
local function drawShapeButton(id, cx, cy, label, active, shape)
  local mon=S.mon
  local color = active and colors.orange or colors.gray
  local text = active and colors.black or colors.white
  mon.setTextColor(text)

  local pattern
  if shape=="CIRCLE" then
    pattern = {
      "  ###  ",
      " ##### ",
      "##"..label.."##",
      " ##### ",
      "  ###  ",
    }
  elseif shape=="HEX" then
    pattern = {
      "  ###  ",
      " ##### ",
      "##"..label.."##",
      " ##### ",
      "  ###  ",
    }
  elseif shape=="OCTAGON" then
    pattern = {
      " ##### ",
      "#######",
      "##"..label.."##",
      "#######",
      " ##### ",
    }
  elseif shape=="RHOMBUS" then
    pattern = {
      "  ###  ",
      " ##"..label.."##",
      "  ###  ",
    }
  elseif shape=="SQUARE" then
    pattern = {
      "#######",
      "#" .. label .. "#",
      "#######",
    }
  end

  -- pintar el patrón
  local h = #pattern
  local w = #pattern[1]
  for dy,line in ipairs(pattern) do
    mon.setCursorPos(cx - math.floor(w/2), cy+dy-1)
    for i=1,#line do
      local ch = string.sub(line,i,i)
      if ch=="#" then mon.setBackgroundColor(color) else mon.setBackgroundColor(colors.black) end
      mon.write(" ")
    end
  end

  -- registrar área
  S.buttons[id] = {x1=cx-math.floor(w/2), y1=cy, x2=cx+math.floor(w/2), y2=cy+h-1}
  mon.setBackgroundColor(colors.black)
end

-- ===== UI VIEWS =====
local function drawDash(info)
  local mon=S.mon; mon.setTextScale(1); f.clear(mon)
  local mx,my=mon.getSize()
  mon.setCursorPos(math.floor(mx/2)-5,1); mon.write("REACTOR DASH")
  mon.setCursorPos(2,3); mon.write("SAT: "..math.floor(info.satP).."%")
  mon.setCursorPos(2,4); mon.write("Field: "..math.floor(info.fieldP).."%")
  mon.setCursorPos(2,5); mon.write(("Gen: %s RF/t"):format(f.format_int(info.gen)))
  mon.setCursorPos(2,6); mon.write(("Temp: %d C"):format(info.temp))
  drawShapeButton("CTRL", math.floor(mx/2)-10, my-6, "CTRL", false, S.hudStyle)
  drawShapeButton("HUD", math.floor(mx/2)+10, my-6, "HUD", false, S.hudStyle)
end

local function drawCtrl(info)
  local mon=S.mon; mon.setTextScale(1); f.clear(mon)
  local mx,my=mon.getSize()
  mon.setCursorPos(math.floor(mx/2)-4,1); mon.write("MODOS")
  local modes={"SAT","MAXGEN","ECO","TURBO","PROTECT"}
  for i,m in ipairs(modes) do
    drawShapeButton(m, 6+(i-1)*12, 5, m, m==S.modeOut, S.hudStyle)
  end
  drawShapeButton("BACK", math.floor(mx/2), my-6, "BACK", false, S.hudStyle)
end

local function drawHUD()
  local mon=S.mon; mon.setTextScale(1); f.clear(mon)
  local mx,my=mon.getSize()
  mon.setCursorPos(math.floor(mx/2)-5,1); mon.write("HUD SETTINGS")
  local styles={"CIRCLE","HEX","OCTAGON","RHOMBUS","SQUARE"}
  for i,s in ipairs(styles) do
    drawShapeButton(s, 6+(i-1)*12, 5, s, S.hudStyle==s, s)
  end
  drawShapeButton("BACK", math.floor(mx/2), my-6, "BACK", false, S.hudStyle)
end

local function draw(info)
  if S.view=="DASH" then drawDash(info)
  elseif S.view=="CTRL" then drawCtrl(info)
  elseif S.view=="HUD" then drawHUD()
  end
end

-- ===== LOOPS =====
local function uiLoop()
  while true do
    local _,_,x,y=os.pullEvent("monitor_touch")
    for id,btn in pairs(S.buttons) do
      if x>=btn.x1 and x<=btn.x2 and y>=btn.y1 and y<=btn.y2 then
        if id=="CTRL" then S.view="CTRL"
        elseif id=="HUD" then S.view="HUD"
        elseif id=="BACK" then S.view="DASH"
        elseif id=="SAT" or id=="MAXGEN" or id=="ECO" or id=="TURBO" or id=="PROTECT" then
          S.modeOut=id
        elseif id=="CIRCLE" or id=="HEX" or id=="OCTAGON" or id=="RHOMBUS" or id=="SQUARE" then
          S.hudStyle=id
          -- guardar en config
          local cfg = dofile("config.lua")
          cfg.hud_style = id
          local f = fs.open("config.lua","w")
          f.write("return "..textutils.serialize(cfg))
          f.close()
        end
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
