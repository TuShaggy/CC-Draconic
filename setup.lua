-- setup.lua — graphical setup wizard
local f = require("lib/f")

local setup = {}

function setup.saveConfig(cfg)
  local h=fs.open("config.lua","w")
  h.write("return "..textutils.serialize(cfg))
  h.close()
end

function setup.loadConfig()
  if fs.exists("config.lua") then
    local ok,cfg=pcall(dofile,"config.lua")
    if ok then return cfg end
  end
end

local function detect()
  local reactors,mons,gates={}, {}, {}
  for _,n in ipairs(peripheral.getNames()) do
    if n:find("draconic_reactor") then table.insert(reactors,n) end
    if n:find("monitor") then table.insert(mons,n) end
    if n:find("flow_gate") then table.insert(gates,n) end
  end
  return reactors,mons,gates
end

function setup.drawSetup(S)
  local mon=S.mon; f.clear(mon); S.buttons={}
  local w,h=mon.getSize()
  f.center(mon,1,"SETUP - Paso "..S.step)
  local reactors,mons,gates=detect()

  local function drawList(prefix,list,y)
    local x=4
    for i,n in ipairs(list) do
      local id=prefix..":"..n
      f.box(mon,x,y,x+20,y+2,colors.gray)
      mon.setCursorPos(x+1,y+1); mon.write(n)
      S.buttons[id]={x1=x,y1=y,x2=x+20,y2=y+2}
      y=y+3
    end
  end

  if S.step==1 then f.center(mon,3,"Selecciona reactor"); drawList("rx",reactors,5)
  elseif S.step==2 then f.center(mon,3,"Selecciona monitor"); drawList("mn",mons,5)
  elseif S.step==3 then f.center(mon,3,"Flux Gate IN"); drawList("in",gates,5)
  elseif S.step==4 then f.center(mon,3,"Flux Gate OUT"); drawList("out",gates,5) end

  f.box(mon,4,h-3,14,h-1,colors.orange); mon.setCursorPos(6,h-2); mon.write("NEXT")
  S.buttons["next"]={x1=4,y1=h-3,x2=14,y2=h-1}
end

function setup.handleClick(S,id)
  local pfx,name = id:match("^(%a+):(.*)$")
  if pfx=="rx" then S.rx=peripheral.wrap(name)
  elseif pfx=="mn" then S.mon=peripheral.wrap(name)
  elseif pfx=="in" then S.inGate=peripheral.wrap(name)
  elseif pfx=="out" then S.outGate=peripheral.wrap(name) end

  if id=="next" then
    if S.step<4 then S.step=S.step+1
    else
      local cfg={reactor=peripheral.getName(S.rx),monitor=peripheral.getName(S.mon),
        in_gate=peripheral.getName(S.inGate),out_gate=peripheral.getName(S.outGate),
        hud_style=S.hudStyle}
      setup.saveConfig(cfg)
      S.view="DASH"
    end
  end
end

return setup
