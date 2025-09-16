-- lib/f.lua — helpers de UI y temas
local f = {}

-- 🎨 Temas (tuyos + añadidos ASCII y Hologram)
f.themes = {
  minimalist = { bg = colors.black, fg = colors.white, accent = colors.orange },
  retro      = { bg = colors.black, fg = colors.green, accent = colors.lime },
  neon       = { bg = colors.black, fg = colors.cyan,  accent = colors.magenta },
  compact    = { bg = colors.gray,  fg = colors.white, accent = colors.blue },
  ascii      = { bg = colors.black, fg = colors.white, accent = colors.lightGray },
  hologram   = { bg = colors.black, fg = colors.cyan,  accent = colors.purple },
  -- aquí puedes añadir todos los demás que tenías (future, draconic, etc.)
}

-- 🧹 Limpia pantalla
function f.clear(mon, theme)
  mon = mon or term
  local t = f.themes[theme] or f.themes.minimalist
  mon.setBackgroundColor(t.bg)
  mon.setTextColor(t.fg)
  mon.clear()
  mon.setCursorPos(1,1)
end

-- 📍 Centrar texto
function f.center(mon, y, text, theme)
  mon = mon or term
  local w,_ = mon.getSize()
  local t = f.themes[theme] or f.themes.minimalist
  mon.setCursorPos(math.floor((w - #text) / 2) + 1, y)
  mon.setTextColor(t.fg)
  mon.write(text)
end

-- 🔘 Botón estándar
function f.button(mon, x1, y1, x2, y2, label, color, theme)
  mon = mon or term
  local t = f.themes[theme] or f.themes.minimalist
  mon.setBackgroundColor(color or t.accent)
  mon.setTextColor(t.fg)
  for y = y1, y2 do
    mon.setCursorPos(x1, y)
    mon.write(string.rep(" ", x2 - x1 + 1))
  end
  mon.setCursorPos(x1 + math.floor((x2 - x1 - #label) / 2), y1 + math.floor((y2 - y1) / 2))
  mon.write(label)
  mon.setBackgroundColor(t.bg)
end

-- 🔘 Botón ASCII
function f.asciiButton(mon, x, y, label, theme)
  mon = mon or term
  local t = f.themes[theme] or f.themes.ascii
  mon.setTextColor(t.accent)
  mon.setCursorPos(x, y)
  mon.write("+" .. string.rep("-", #label + 2) .. "+")
  mon.setCursorPos(x, y+1)
  mon.write("| " .. label .. " |")
  mon.setCursorPos(x, y+2)
  mon.write("+" .. string.rep("-", #label + 2) .. "+")
end

-- 🎛️ Dibujo de barra
function f.bar(mon, x, y, w, h, value, max, color, theme)
  mon = mon or term
  local t = f.themes[theme] or f.themes.minimalist
  local ratio = math.min(1, math.max(0, value / max))
  local fill = math.floor(ratio * w)
  mon.setBackgroundColor(color or t.accent)
  for i = 0, h-1 do
    mon.setCursorPos(x, y+i)
    mon.write(string.rep(" ", fill))
    if fill < w then
      mon.setBackgroundColor(t.bg)
      mon.write(string.rep(" ", w - fill))
    end
  end
  mon.setBackgroundColor(t.bg)
end

-- 🖼️ Cuadro
function f.box(mon, x1, y1, x2, y2, color, theme)
  mon = mon or term
  local t = f.themes[theme] or f.themes.minimalist
  mon.setBackgroundColor(color or t.accent)
  for y = y1, y2 do
    mon.setCursorPos(x1, y)
    mon.write(string.rep(" ", x2 - x1 + 1))
  end
  mon.setBackgroundColor(t.bg)
end

return f
