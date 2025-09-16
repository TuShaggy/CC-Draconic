-- ui.lua — HUD & UI System
local f = require("lib/f")

local ui = {}

-- ===== Button registry =====
local function regButton(S,id,x1,y1,x2,y2)
  S.buttons = S.buttons or {}
  S.buttons[id] = {x1=x1,y1=y1,x2=x2,y2=y2}
end

-- ===== Draw button =====
local function drawButton(S,id,x,y,w,label,active)
  local mon = S.mon

  if S.hudTheme == "ascii" then
    f.drawAsciiButton(mon,x,y,w,5,label,active)
    regButton(S,id,x,y,x+w-1,y+4)
  else
    local bg,fg = f.getColors(S,active)
    f.box(mon,x,y,x+w-1,y+2,bg)
    mon.setTextColor(fg)
    mon.setCursorPos(x+math.floor((w-#label)/2),y+1)
    mon.write(label)
    mon.setTextColor(colors.white)
    regButton(S,id,x,y,x+w-1,y+2)
  end
end

-- ===== VIEWS =====
local function drawDash(S,info)
  local mon=S.mon; f.clear(mon,S.hudTheme); S.buttons={}
  local w,h = mon.getSize()
  f.center(mon,1,"REACTOR DASH ("..(S.hudTheme or "minimalist")..")")

  if S.hudTheme == "compact" then
    -- Compact layout
    mon.setCursorPos(2,3)
    mon.write(("SAT %2d%% | FLD %2d%% | GEN %s | TMP %dC")
      :format(math.floor(info.satP or 0),
              math.floor(info.fieldP or 0),
              f.format_int(info.gen or 0),
              info.temp or 0))
  else
    -- Full layout
    mon.setCursorPos(2,3)
    mon.write(("SAT: %2d%%  FLD: %2d%%")
      :format(math.floor(info.satP or 0), math.floor(info.fieldP or 0)))
    mon.setCursorPos(2,4)
    mon.write(("GEN: %s RF/t  TMP: %dC")
      :format(f.format_int(info.gen or 0), info.temp or 0))
  end

  local bw = math.floor(w/4)-2
  drawButton(S,"CTRL",2,h-4,bw,"CTRL",S.view=="CTRL")
  drawButton(S,"HUD",bw+4,h-4,bw,"HUD",S.view=="HUD")
  drawButton(S,"THEMES",2*bw+6,h-4,bw,"THEMES",S.view=="THEMES")
  local lbl = S.power and "POWER OFF" or "POWER ON"
  drawButton(S,"POWER",3*bw+8,h-4,bw,lbl,S.power)
end

local function drawCtrl(S)
  local mon=S.mon; f.clear(mon,S.hudTheme); S.buttons={}
  f.center(mon,1,"MODOS")
  local modes={"SAT","MAXGEN","ECO","TURBO","PROTECT"}
  local x=2
  for _,m in ipairs(modes) do
    drawButton(S,m,x,4,12,m,S.modeOut==m)
    x=x+14
  end
  drawButton(S,"BACK",2,12,10,"BACK",false)
end

local function drawHUD(S)
  local mon=S.mon; f.clear(mon,S.hudTheme); S.buttons={}
  f.center(mon,1,"HUD SETTINGS")
  local styles={"CIRCLE","HEX","RHOMBUS","SQUARE"}
  local cols=2
  local spacingX,spacingY=16,6
  local startX=4
  local startY=4

  local i=0
  for _,s in ipairs(styles) do
    local col=i%cols
    local row=math.floor(i/cols)
    local x=startX+col*spacingX
    local y=startY+row*spacingY
    drawButton(S,"style:"..s,x,y,12,s,S.hudStyle==s)
    i=i+1
  end
  drawButton(S,"BACK",2,14,10,"BACK",false)
end

local function drawThemes(S)
  local mon=S.mon; f.clear(mon,S.hudTheme); S.buttons={}
  f.center(mon,1,"SELECT THEME")
  local themes={"minimalist","retro","neon","compact","ascii"}
  local x=2
  for _,t in ipairs(themes) do
    drawButton(S,"theme:"..t,x,4,14,t:upper(),S.hudTheme==t)
    x=x+16
  end
  drawButton(S,"BACK",2,10,10,"BACK",false)
end

-- Animación simple
local function drawBoot(S)
  local mon=S.mon; f.clear(mon,S.hudTheme)
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
      elseif S.view=="THEMES" then drawThemes(S)
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
            elseif id=="THEMES" then S.view="THEMES"
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
          elseif S.view=="THEMES" then
            if id=="BACK" then S.view="DASH"
            else
              local theme=id:match("^theme:(.+)$")
              if theme then
                S.hudTheme=theme
                local cfg=setup.loadConfig() or {}
                cfg.hud_theme=theme; setup.saveConfig(cfg)
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
