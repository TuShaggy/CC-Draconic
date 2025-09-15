-- ========= HUD con barras =========
local function drawBar(mon, x, y, w, pct, color)
  pct = math.max(0, math.min(100, pct))
  local fill = math.floor((pct/100) * w)
  for i=0,w-1 do
    mon.setCursorPos(x+i,y)
    if i < fill then
      mon.setBackgroundColor(color or colors.green)
    else
      mon.setBackgroundColor(colors.gray)
    end
    mon.write(" ")
  end
  mon.setBackgroundColor(colors.black)
end

    -- Fallback ASCII para monitores no avanzados (B/W)
    mon.setCursorPos(x,y)
    local bar = string.rep("#", fill)..string.rep("-", w-fill)
    mon.setTextColor(colors.white)
    mon.write(bar)
    mon.setTextColor(colors.white)
  end
end

local function draw(info)
  local mon=S.mon
  mon.setTextScale(0.5)
  f.clear(mon)
  f.textLR(mon,2,2,"Reactor ("..(S.rxName or "?")..")",string.upper(info.status),colors.white,colors.lime)
  f.textLR(mon,2,4,"Gen",f.format_int(info.gen).." RF/t",colors.white,colors.white)
  f.textLR(mon,2,6,"Temp",f.format_int(info.temp).." C",colors.white,colors.red)

  mon.setCursorPos(2,8); mon.write("SAT: "..string.format("%.1f%%",info.satP))
  drawBar(mon, 10, 8, 30, info.satP, colors.blue)

  mon.setCursorPos(2,10); mon.write("Field: "..string.format("%.1f%%",info.fieldP))
  drawBar(mon, 10, 10, 30, info.fieldP, colors.cyan)

  f.textLR(mon,2,12,"Action",S.action,colors.gray,colors.gray)
end
