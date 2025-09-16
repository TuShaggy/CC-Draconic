-- lib/f.lua — helpers y temas de HUD
local f = {}

-- ===== Themes =====
f.themes = {
  minimalist = {
    bg  = colors.black,
    btn = colors.gray,
    act = colors.orange,
    txt = colors.white,
  },
  retro = {
    bg  = colors.black,
    btn = colors.green,
    act = colors.lime,
    txt = colors.green,
  },
  neon = {
    bg  = colors.black,
    btn = colors.blue,
    act = colors.orange,
    txt = colors.cyan,
  },
  compact = {
    bg  = colors.black,
    btn = colors.gray,
    act = colors.lightBlue,
    txt = colors.white,
  },
  ascii = {
    bg  = colors.black,
    btn = colors.black,
    act = colors.black,
    txt = colors.white,
    border = colors.lightGray,
  },
}

-- Devuelve esquema de color según theme + si está activo
function f.getColors(S, active)
  local theme = f.themes[S.hudTheme or "minimalist"] or f.themes.minimalist
  if active then
    return theme.act,theme.txt
  else
    return theme.btn,theme.txt
  end
end

-- ===== Utils =====
function f.clear(mon, themeName)
  local theme = f.themes[themeName or "minimalist"]
  mon.setBackgroundColor(theme.bg)
  mon.clear()
  mon.setCursorPos(1,1)
end

function f.center(mon,y,text)
  local w,_=mon.getSize()
  mon.setCursorPos(math.floor(w/2-#text/2),y)
  mon.write(text)
end

function f.box(mon,x1,y1,x2,y2,bg)
  mon.setBackgroundColor(bg or colors.gray)
  for y=y1,y2 do
    mon.setCursorPos(x1,y)
    mon.write(string.rep(" ",x2-x1+1))
  end
  mon.setBackgroundColor(colors.black)
end

function f.format_int(n)
  local s=tostring(math.floor(n or 0))
  local out=""
  while #s>3 do
    out=","..string.sub(s,-3)..out
    s=string.sub(s,1,-4)
  end
  return s..out
end

function f.beep(spk,snd)
  if not spk then return end
  pcall(function()
    spk.playSound(snd or "minecraft:block.note_block.pling")
  end)
end

-- ===== ASCII Button =====
function f.drawAsciiButton(mon,x,y,w,h,label,active)
  mon.setTextColor(colors.white)
  mon.setBackgroundColor(colors.black)

  -- Top border
  mon.setCursorPos(x,y); mon.write("+"..string.rep("-",w-2).."+")
  -- Middle
  for j=1,h-2 do
    mon.setCursorPos(x,y+j)
    local pad = math.floor((w-#label)/2)
    local line = "|" .. string.rep(" ",w-2) .. "|"
    if j==math.floor(h/2) then
      line = "|" .. string.rep(" ",pad)..label..string.rep(" ",w-2-#label-pad).."|"
    end
    mon.write(line)
  end
  -- Bottom border
  mon.setCursorPos(x,y+h-1); mon.write("+"..string.rep("-",w-2).."+")
end

return f
