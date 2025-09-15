---------------------------
-- FILE: lib/f.lua
---------------------------

local f = {}

local function drawPad(mon, x, y, label, fg, bg)
  fg = fg or colors.white; bg = bg or colors.gray
  mon.setCursorPos(x,y); mon.setBackgroundColor(bg); mon.setTextColor(fg); mon.write(label)
  mon.setBackgroundColor(colors.black); mon.setTextColor(colors.white)
end

function f.clear(mon)
  local mx,my = mon.getSize()
  mon.setBackgroundColor(colors.black); mon.clear(); mon.setCursorPos(1,1)
end

function f.textLR(mon, x, y, left, right, lcol, rcol)
  local mx = select(1, mon.getSize())
  mon.setCursorPos(x,y); mon.setTextColor(lcol or colors.white); mon.write(left)
  local rx = mx - #right - 1; if rx < x+#left+1 then rx = x+#left+1 end
  mon.setCursorPos(rx,y); mon.setTextColor(rcol or colors.white); mon.write(right)
  mon.setTextColor(colors.white)
end

function f.bar(mon, x, y, w, val, maxVal, col)
  val = math.max(0, math.min(val, maxVal))
  local fill = math.floor((w-2) * (val/maxVal))
  mon.setCursorPos(x,y); mon.setTextColor(colors.white); mon.write("[")
  for i=1,w-2 do
    mon.setBackgroundColor(i<=fill and (col or colors.green) or colors.gray); mon.write(" ")
  end
  mon.setBackgroundColor(colors.black); mon.write("]")
end

function f.button(mon, x, y, label, col)
  drawPad(mon, x, y, label, colors.white, col or colors.gray)
end

function f.format_int(n)
  if type(n) ~= 'number' then return tostring(n) end
  local s = string.format("%0.0f", n)
  local left, num, right = string.match(s,'^([^%d]*%d)(%d*)(.-)$')
  return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end

function f.si(n)
  if n >= 1e12 then return string.format("%.1fT", n/1e12)
  elseif n >= 1e9 then return string.format("%.1fG", n/1e9)
  elseif n >= 1e6 then return string.format("%.1fM", n/1e6)
  elseif n >= 1e3 then return string.format("%.1fk", n/1e3)
  else return string.format("%d", n) end
end

return f
