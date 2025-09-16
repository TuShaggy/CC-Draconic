-- lib/f.lua — helpers para barras y texto
local f = {}

function f.hbar(mon, x, y, w, value, max, colFill, colBg)
  value = math.min(math.max(value or 0, 0), max or 1)
  local fill = math.floor((value / (max or 1)) * w)

  colFill = colFill or colors.green
  colBg   = colBg or colors.gray

  mon.setCursorPos(x, y)
  mon.setBackgroundColor(colFill)
  if fill > 0 then mon.write(string.rep(" ", fill)) end
  if fill < w then
    mon.setBackgroundColor(colBg)
    mon.write(string.rep(" ", w - fill))
  end
  mon.setBackgroundColor(colors.black)
end

function f.center(mon, y, text, col)
  local w,_ = mon.getSize()
  mon.setCursorPos(math.floor((w - #text)/2)+1, y)
  mon.setTextColor(col or colors.white)
  mon.write(text)
  mon.setTextColor(colors.white)
end

return f
