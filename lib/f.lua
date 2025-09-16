-- lib/f.lua — utilidades

local f = {}

function f.clear(mon) mon.setBackgroundColor(colors.black); mon.clear(); mon.setCursorPos(1,1) end

function f.center(mon, y, text)
  local w,_ = mon.getSize()
  mon.setCursorPos(math.floor(w/2 - #text/2), y)
  mon.write(text)
end

function f.box(mon,x1,y1,x2,y2,bg)
  mon.setBackgroundColor(bg or colors.gray)
  for y=y1,y2 do mon.setCursorPos(x1,y); mon.write(string.rep(" ", x2-x1+1)) end
  mon.setBackgroundColor(colors.black)
end

function f.format_int(n)
  local s=tostring(math.floor(n or 0))
  local out=""
  while #s>3 do out=","..string.sub(s,-3)..out; s=string.sub(s,1,-4) end
  return s..out
end

function f.beep(spk, snd)
  if not spk then return end
  pcall(function() spk.playSound(snd or "minecraft:block.note_block.pling") end)
end

return f
