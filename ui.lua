-- ui.lua — minimal futuristic HUD
local f = require("lib/f")

local ui = {}

-- guardar área de botones
local function regButton(S,id,x1,y1,x2,y2)
  S.buttons = S.buttons or {}
  S.buttons[id] = {x1=x1,y1=y1,x2=x2,y2=y2}
end

-- botón rectangular minimalista
local function drawButton(S,id,x,y,w,label,active)
  local mon = S.mon
  local bg = active and colors.orange or colors.gray
  local fg = active and colors.black or colors.white
  f.box(mon,x,y,x+w-1,y+2,bg)
  mon.setTextColor(fg)
  mon.setCursorPos(x+math.floor((w-#label)/2),y+1)
  mon.write(label)
  mon.setTextColor(colors.white)
  regButton(S,id,x,y,x+w-1,y+2)
end

-- ===== VISTAS =====
local function drawDash(S,info)
  local mon=S.mon; f.clear(mon); S.buttons={}
  local w,h = mon.getSize()
  f.center(mon,1,"REACTOR DASH")
  mon.setCursorPos(2,3); mon.write(("SAT: %2d%%  FLD: %2d%%"):format(math.floor(info.satP or 0), math.floor(info.fieldP or 0)))
  mon.setCursorPos(2,4); mon.write(("GEN: %s RF/t  TMP: %dC"):format(f.format_int(info.gen or 0), info.temp or 0))
  local bw = math.floor(w/3)-2
  drawButton(S,"CTRL",2,h-4,bw,"CTRL",S.view=="CTRL")
  drawButton(S,"HUD",bw+4,h-4,bw,"HUD",S.view=="HUD")
  local lbl = S.power and "POWER OFF" or "POWER ON"
  drawButton(S,"POWER",2*bw+6,h-4,bw,lbl,S.power)
end

local function drawCtrl(S)
  local mon=S.mon; f.clear(mon); S.buttons={}
  f.center(mon,1,"MODOS")
  local modes={"SAT","MAXGEN","ECO","TURBO","PROTECT"}
  local x=2
  for _,m in ipairs(modes) do
    drawButton(S,m,x,4,12,m,S.modeOut==m)
    x=x+14
  end
  drawButton(S,"BACK",2,10,10,"BACK",false)
end

local function drawHUD(S)
  local mon=S.mon; f.clear(mon); S.buttons={}
  f.center(mon,1,"HUD SETTINGS")
  local styles={"CIRCLE","HEX","RHOMBUS","SQUARE"}
  local x=2
  for _,s in ipairs(styles) do
    drawButton(S,"style:"..s,x,4,12,s,S.hudStyle==s)
    x=x+14
  end
  drawButton(S,"BACK",2,10,10,"BACK",false)
end

-- animación simple
local function drawBoot(S)
  local mon=S.mon; f.clear(mon)
  f.center(mon,2,"DRACONIC CONTROLLER")
  f.center(mon,4,"Loading...")
  local w,_=mon.getSize()
  for i=0,20 do
    local fill=math.floor((i/20)*(w-10))
    mon.setCursorPos(6,6)
    f.box(mon,6,6,6+(w-10),6,colors.gray)
    f.box(mon,6,6,6+fill,6,colors.orange)
    sleep(0.05)
    f.beep(S.spk)
  end
end

-- ===== CONTROL LOOP =====
function ui.run(S, reactor, setup)
  local function tick()
    while true do
      local info = reactor.getInfo(S)
      if S.view=="BOOT" then drawBoot(S); S.view="DASH"
      elseif S.view=="DASH" then drawDash(S,info or {})
      elseif S.view=="CTRL" then drawCtrl(S)
      elseif S.view=="HUD" then drawHUD(S)
      elseif S.view=="SETUP" then setup.drawSetup(S) end
      sleep(0.2)
    end
  end

  local function input()
    while true do
      local _,_,x,y = os.pullEvent("monitor_touch")
      for id,b in pairs(S.buttons or {}) do
        if x>=b.x1 and x<=b.x2 and y>=b.y1 and y<=b.y2 then
          if S.view=="DASH" then
            if id=="CTRL" then S.view="CTRL"
            elseif id=="HUD" then S.view="HUD"
            elseif id=="POWER" then
              S.power=not S.power; reactor.setActive(S,S.power)
            end
          elseif S.view=="CTRL" then
            if id=="BACK" then S.view="DASH"
            else S.modeOut=id end
          elseif S.view=="HUD" then
            if id=="BACK" then S.view="DASH"
            else
              local style=id:match("^style:(.+)$")
              if style then
                S.hudStyle=style
                local cfg=setup.loadConfig() or {}
                cfg.hud_style=style; setup.saveConfig(cfg)
              end
            end
          elseif S.view=="SETUP" then
            setup.handleClick(S,id)
          end
        end
      end
    end
  end

  parallel.waitForAny(tick,input)
end

return ui

