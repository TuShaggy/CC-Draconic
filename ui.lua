-- ui.lua — interfaz de usuario
local f = require("lib/f")
local ui = {}

function ui.drawMain(S, reactor)
  f.clear(S.mon, S.hudTheme)
  f.center(S.mon, 1, "DRACONIC REACTOR", S.hudTheme)

  local w,h = S.mon.getSize()
  S.mon.setCursorPos(2,3)
  S.mon.write("SAT: "..math.floor(reactor.sat*100).."%")
  f.bar(S.mon, 8,3, w-10,1, reactor.sat*100, 100, nil, S.hudTheme)

  S.mon.setCursorPos(2,5)
  S.mon.write("FLD: "..math.floor(reactor.field*100).."%")
  f.bar(S.mon, 8,5, w-10,1, reactor.field*100, 100, nil, S.hudTheme)

  S.mon.setCursorPos(2,7)
  S.mon.write("TMP: "..math.floor(reactor.temp).."C")
  S.mon.setCursorPos(2,9)
  S.mon.write("GEN: "..math.floor(reactor.generation/1000).."kRF/t")

  f.button(S.mon, 2,h-3, 12,h-2, "CTRL", nil, S.hudTheme)
  f.button(S.mon, 14,h-3, 24,h-2, "HUD", nil, S.hudTheme)
  f.button(S.mon, 26,h-3, 38,h-2, "THEMES", nil, S.hudTheme)
  f.button(S.mon, 40,h-3, 54,h-2, "POWER", nil, S.hudTheme)
end

function ui.handleTouch(S, x, y)
  -- placeholder: aquí iría el control de menús
  S.mode = (S.mode == "SAT") and "MAXGEN" or "SAT"
end

return ui
