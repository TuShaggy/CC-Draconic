-- lib/f.lua — funciones auxiliares de UI
local f = {}

f.themes = {
  minimalist = { bg = colors.black, fg = colors.white, accent = colors.orange },
  retro      = { bg = colors.black, fg = colors.green, accent = colors.lime },
  neon       = { bg = colors.black, fg = colors.cyan,  accent = colors.magenta },
  compact    = { bg = colors.gray,  fg = colors.white, accent = colors.blue },
  ascii      = { bg = colors.black, fg = colors.white, accent = colors.lightGray },
  hologram   = { bg = colors.black, fg = colors.cyan,  accent = colors.purple },
}

function f.clear(mon, theme)
  if type(mon) == "string" and theme == nil then theme, mon = mon, nil end
  mon = mon or term
  local t = f.themes[theme] or f.themes.minimalist
  mon.setBackgroundColor(t.bg)
  mon.setTextColor(t.fg)
  mon.clear()
  mon.setCursorPos(1,1)
end

function f.center(mon, y, text, theme)
  mon = mon or term
  local w,_ = mon.getSize()
  local t = f.themes[theme] or f.themes.minimalist
  mon.setCursorPos(math.floor((w - #text) / 2) + 1, y)
  mon.setTextColor(t.fg)
  mon.write(text)
end

function f.button(mon, x1, y1, x2, y2, label, color, theme)
  mon = mon or term
  local t = f.themes[theme] or f.themes.minimalist
  mon.setBackgroundColor(color or t.accent)
  mon.setTextColor(t.fg)
  for y = y1, y2 do
    mon.setCursorPos(x1, y)
    mon.write(string.rep(" ", x2 - x1 + 1))
  end
  mon.setCursorPos(x1 + math.floor((x2 - x1 - #label) / 2), y1)
  mon.write(label)
  mon.setBackgroundColor(t.bg)
end

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

return f
