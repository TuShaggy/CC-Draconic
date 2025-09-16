-- ui.lua
local f = dofile("lib/f.lua")
local ui = {}

ui.buttons = {}

function ui.drawMain(S, stats)
  local mon = S.mon or term
  f.clear(mon, S.hudTheme)
  f.center(mon, 1, "DRACONIC REACTOR", S.hudTheme)

  local w,h = mon.getSize()
  mon.setCursorPos(2,3)
  mon.write("SAT: "..math.floor((stats.sat or 0)*100).."%")
  f.bar(mon, 8,3, w-10,1, (stats.sat or 0)*100, 100, nil, S.hudTheme)

  mon.setCursorPos(2,5)
  mon.write("FLD: "..math.floor((stats.field or 0)*100).."%")
  f.bar(mon, 8,5, w-10,1, (stats.field or 0)*100, 100, nil, S.hudTheme)

  mon.setCursorPos(2,7)
  mon.write("TMP: "..math.floor(stats.temp or 0).."C")
  mon.setCursorPos(2,9)
  mon.write("GEN: "..math.floor((stats.generation or 0)/1000).."kRF/t")

  -- botones dinámicos
  ui.buttons = {
    {x1=2,       y1=h-3, x2=8,       y2=h-2, label="CTRL",   action=function() S.mode="SAT" end},
    {x1=10,      y1=h-3, x2=16,      y2=h-2, label="HUD",    action=function() S.hudTheme="minimalist" end},
    {x1=18,      y1=h-3, x2=26,      y2=h-2, label="THEMES", action=function() print("themes") end},
    {x1=28,      y1=h-3, x2=36,      y2=h-2, label="POWER",  action=function() print("power") end},
  }

  for _,b in ipairs(ui.buttons) do
    f.button(mon, b.x1, b.y1, b.x2, b.y2, b.label, nil, S.hudTheme)
  end
end

function ui.handleTouch(x,y)
  for _,b in ipairs(ui.buttons) do
    if x>=b.x1 and x<=b.x2 and y>=b.y1 and y<=b.y2 then
      if b.action then b.action() end
      return true
    end
  end
  return false
end

return ui
