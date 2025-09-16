-- ui.lua — interfaz de usuario (robusta, usa themes.lua vía lib/f)
local f = require("lib/f")
local ui = {}

-- Dibuja el HUD principal con barras y botones
function ui.drawMain(S, stats)
  local mon = S.mon or term
  f.clear(mon, S.hudTheme)
  f.center(mon, 1, "DRACONIC REACTOR", S.hudTheme)

  local w,h = mon.getSize()

  -- Líneas de datos
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

  -- Botones inferiores
  local btnW = math.floor(w/4) - 2
  f.button(mon, 2,       h-3, 2+btnW,       h-2, "CTRL",   nil, S.hudTheme)
  f.button(mon, 4+btnW,  h-3, 4+2*btnW,     h-2, "HUD",    nil, S.hudTheme)
  f.button(mon, 6+2*btnW,h-3, 6+3*btnW,     h-2, "THEMES", nil, S.hudTheme)
  f.button(mon, 8+3*btnW,h-3, 8+4*btnW,     h-2, "POWER",  nil, S.hudTheme)
end

-- (Opcional) Menú de selección de Theme leyendo keys de f.themes
function ui.drawThemes(S)
  local mon = S.mon or term
  f.clear(mon, S.hudTheme)
  f.center(mon, 1, "THEMES", S.hudTheme)

  -- recolectar nombres y ordenarlos
  local names = {}
  for k,_ in pairs(f.themes) do table.insert(names, k) end
  table.sort(names)

  local w,h = mon.getSize()
  local cols = 2
  local colW = math.floor((w-8)/cols)
  local x0, y0, dy = 4, 3, 3

  for i,name in ipairs(names) do
    local col = (i-1) % cols
    local row = math.floor((i-1)/cols)
    local x1 = x0 + col*colW
    local x2 = x1 + colW - 2
    local y1 = y0 + row*dy
    local label = name:upper()
    f.button(mon, x1, y1, x2, y1+1, label, nil, name)
  end

  f.button(mon, 2, h-3, 14, h-2, "BACK", nil, S.hudTheme)
end

-- (Opcional) Menú de modos de control
function ui.drawControl(S, current)
  local mon = S.mon or term
  f.clear(mon, S.hudTheme)
  f.center(mon, 1, "CONTROL MODES", S.hudTheme)
  local modes = {"SAT","MAXGEN","ECO","TURBO","PROTECT"}
  local x1,y = 4,3
  for _,m in ipairs(modes) do
    local label = (m==current) and ("> "..m.." <") or m
    f.button(mon, x1, y, x1+14, y+1, label, nil, S.hudTheme)
    y = y + 3
  end
  local w,h = mon.getSize()
  f.button(mon, 2, h-3, 14, h-2, "BACK", nil, S.hudTheme)
end

-- Handler básico de toques (placeholder): alterna entre SAT/MAXGEN
function ui.handleTouch(S, x, y)
  -- Aquí podrías mapear hitboxes si quieres navegación completa
  if S.mode == "SAT" then S.mode = "MAXGEN" else S.mode = "SAT" end
end

return ui
