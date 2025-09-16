-- lib/f.lua — funciones de UI (no usa require aquí)

local f = {}

-- limpiar pantalla
function f.clear(mon, theme)
  mon.setBackgroundColor(colors.black)
  mon.clear()
end

-- centrar texto
function f.center(mon, y, text, theme)
  local w = mon.getSize()
  local x = math.floor((w - #text) / 2) + 1
  mon.setCursorPos(x, y)
  mon.write(text)
end

-- dibujar barra
function f.bar(mon, x, y, w, h, val, max, col, theme)
  val = math.min(val, max)
  local filled = math.floor((val / max) * w)
  mon.setCursorPos(x, y)
  mon.write(string.rep("█", filled))
  mon.write(string.rep(" ", w - filled))
end

-- dibujar botón
function f.button(mon, x1, y1, x2, y2, label, col, theme)
  for y = y1, y2 do
    mon.setCursorPos(x1, y)
    mon.write(string.rep(" ", x2 - x1 + 1))
  end
  local cx = math.floor((x1 + x2 - #label) / 2)
  local cy = math.floor((y1 + y2) / 2)
  mon.setCursorPos(cx, cy)
  mon.write(label)
end

return f
