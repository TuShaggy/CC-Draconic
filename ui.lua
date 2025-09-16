-- ui.lua — interfaz de usuario
local f = dofile("lib/f.lua")
local ui = {}

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

  local btnW = math.floor(w/4) - 2
  f.button(mon, 2,       h-3, 2+btnW,       h-2, "CTRL",   nil, S.hudTheme)
  f.button(mon, 4+btnW,  h-3, 4+2*btnW,     h-2, "HUD",    nil, S.hudTheme)
  f.button(mon, 6+2*btnW,h-3, 6+3*btnW,     h-2, "THEMES", nil, S.hudTheme)
  f.button(mon, 8+3*btnW,h-3, 8+4*btnW,     h-2, "POWER",  nil, S.hudTheme)
end

return ui
