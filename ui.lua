-- ui.lua — HUD estilo drmon con botón POWER funcional
local f = dofile("lib/f.lua")
local ui = {}
ui.buttons = {}

local function layoutButtons(mon)
  local w,h = mon.getSize()
  local labels = {"CTRL","HUD","THEMES","POWER"}
  ui.buttons = {}
  local laneW = math.floor(w / #labels)
  local y1, y2 = h-2, h-1

  for i,l in ipairs(labels) do
    local x1 = (i-1)*laneW + 2
    local x2 = i*laneW - 2
    table.insert(ui.buttons, {x1=x1,y1=y1,x2=x2,y2=y2,label=l,key=l})
  end
end

function ui.drawMain(S, stats)
  local mon = S.mon or term
  mon.setBackgroundColor(colors.black)
  mon.clear()

  f.center(mon, 1, "DRACONIC REACTOR", colors.white)

  local w,_ = mon.getSize()

  -- SAT
  mon.setCursorPos(2,3)
  mon.setTextColor(colors.white)
  mon.write(("SAT: %3d%%"):format(math.floor((stats.sat or 0)*100)))
  f.hbar(mon, 12, 3, w-14, (stats.sat or 0)*100, 100, colors.orange, colors.gray)

  -- FIELD
  mon.setCursorPos(2,5)
  mon.write(("FLD: %3d%%"):format(math.floor((stats.field or 0)*100)))
  f.hbar(mon, 12, 5, w-14, (stats.field or 0)*100, 100, colors.cyan, colors.gray)

  -- TEMP
  mon.setCursorPos(2,7)
  mon.write(("TMP: %dC"):format(math.floor(stats.temp or 0)))

  -- GEN
  mon.setCursorPos(2,9)
  mon.write(("GEN: %dkRF/t"):format(math.floor((stats.generation or 0)/1000)))

  -- botones
  layoutButtons(mon)
  for _,b in ipairs(ui.buttons) do
    f.button(mon, b.x1, b.y1, b.x2, b.y2, b.label, colors.orange, colors.white)
  end
end

function ui.handleTouch(S, x, y)
  for _,b in ipairs(ui.buttons) do
    if x>=b.x1 and x<=b.x2 and y>=b.y1 and y<=b.y2 then
      if b.key=="CTRL" then
        S.mode = (S.mode=="SAT") and "MAXGEN" or "SAT"

      elseif b.key=="HUD" then
        S.hudTheme = "minimalist"

      elseif b.key=="THEMES" then
        print("themes selector")

      elseif b.key=="POWER" and S.reactor then
        if S.reactor.getReactorInfo then
          local info = S.reactor.getReactorInfo()
          if info.status == "online" then
            S.reactor.stopReactor()
            print("⚠️ Reactor apagado")
          else
            S.reactor.activateReactor()
            print("✅ Reactor encendido")
          end
        end
      end
      return true
    end
  end
  return false
end

return ui
