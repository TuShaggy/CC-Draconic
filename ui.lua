-- ui.lua — HUD principal
local f = dofile("lib/f.lua")
local ui = {}

ui.buttons = {}

local function layoutButtons(mon, theme)
  local w,h = mon.getSize()
  local pad = 2
  local lanes = 4
  local laneW = math.floor((w - (pad*(lanes+1))) / lanes)
  local y1, y2 = h-3, h-2

  local labels = { "CTRL", "HUD", "THEMES", "POWER" }
  ui.buttons = {}
  for i=1,lanes do
    local x1 = pad + (i-1)*(laneW + pad)
    local x2 = x1 + laneW - 1
    table.insert(ui.buttons, {x1=x1,y1=y1,x2=x2,y2=y2,label=labels[i],key=labels[i]})
  end
end

function ui.drawMain(S, stats)
  local mon = S.mon or term
  f.clear(mon, S.hudTheme)
  f.center(mon, 1, "DRACONIC REACTOR", S.hudTheme)

  local w,h = mon.getSize()

  -- SAT
  mon.setCursorPos(2,3)
  mon.write("SAT: "..math.floor((stats.sat or 0)*100).."%")
  f.hbar(mon, 8,3, w-10, 1, (stats.sat or 0)*100, 100, colors.orange, nil, S.hudTheme)

  -- FIELD
  mon.setCursorPos(2,5)
  mon.write("FLD: "..math.floor((stats.field or 0)*100).."%")
  f.hbar(mon, 8,5, w-10, 1, (stats.field or 0)*100, 100, colors.cyan, nil, S.hudTheme)

  -- TEMP y GEN
  mon.setCursorPos(2,7)
  mon.write(("TMP: %dC"):format(math.floor(stats.temp or 0)))
  mon.setCursorPos(2,9)
  mon.write(("GEN: %dkRF/t"):format(math.floor((stats.generation or 0)/1000)))

  -- Botones
  layoutButtons(mon, S.hudTheme)
  for _,b in ipairs(ui.buttons) do
    f.button(mon, b.x1, b.y1, b.x2, b.y2, b.label, S.hudTheme)
  end
end

-- Manejo de toques (pásame S, x, y desde startup)
function ui.handleTouch(S, x, y)
  if not ui.buttons then return end
  for _,b in ipairs(ui.buttons) do
    if x>=b.x1 and x<=b.x2 and y>=b.y1 and y<=b.y2 then
      if b.key == "CTRL" then
        S.mode = (S.mode == "SAT") and "MAXGEN" or "SAT"
      elseif b.key == "HUD" then
        S.hudTheme = (S.hudTheme == "minimalist") and "retro" or "minimalist"
      elseif b.key == "THEMES" then
        -- Aquí podríamos abrir un selector avanzado de temas
      elseif b.key == "POWER" then
        -- Aquí podrías encender/apagar reactor
      end
      return true
    end
  end
  return false
end

return ui
