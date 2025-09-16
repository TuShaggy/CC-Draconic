-- ui.lua — HUD minimalista estilo drmon (barras + POWER/AU)
for yy = y, y+h-1 do
term.setCursorPos(x, yy)
term.write(string.rep(" ", w))
end
term.redirect(old)
end


local function drawText(x,y,txt,fg,bg)
local old = term.redirect(toMon())
if bg then term.setBackgroundColor(bg) end
if fg then term.setTextColor(fg) end
term.setCursorPos(x,y)
term.write(txt)
term.redirect(old)
end


local function drawBar(label, valuePct, color, row)
local x = L.x0
local y = L.y0 + (row-1) * (L.barH + L.gapY)
-- fondo
drawBox(x, y, L.barW, L.barH, colors.gray)
-- relleno
local fill = math.floor((L.barW-2) * F.clamp(valuePct, 0, 1))
if fill > 0 then
drawBox(x+1, y, fill, L.barH, color)
end
-- texto
local pctTxt = string.format("%s %3d%%", label, math.floor((valuePct or 0)*100+0.5))
drawText(x+1, y, pctTxt, colors.black, colors.white)
end


local function drawButton(btn, label, active)
drawBox(btn.x, btn.y, btn.w, btn.h, active and colors.green or colors.lightGray)
local tx = btn.x + math.floor((btn.w - #label) / 2)
local ty = btn.y + math.floor(btn.h / 2)
drawText(tx, ty, label, colors.black)
end


function M.render(info, state)
clear()


-- Encabezado
local old = term.redirect(toMon())
term.setCursorPos(2,1)
term.setTextColor(colors.cyan)
term.write("DRACONIC REACTOR — HUD")
term.redirect(old)


-- Barras (orden clásico: Saturation, Field, Temperature, Output)
local satPct = info and (info._satPct or 0) or 0
local fieldPct = info and (info._fieldPct or 0) or 0
local temp = info and tonumber(info.temperature or 0) or 0
local outNow = state and state.outFlow or 0


drawBar("Saturation", satPct, colors.orange, 1)
drawBar("Field", fieldPct, colors.lightBlue, 2)


-- Temperatura: normalizamos ~ 10k como 100% visual
local tPct = math.min(1, temp / 10000)
drawBar("Temp", tPct, colors.red, 3)


-- Output: normalizamos visualmente a 50M RF/t (ajústalo si sueles ir más alto)
local outPct = math.min(1, (outNow or 0) / 50000000)
drawBar("Output", outPct, colors.lime, 4)


-- Status línea
local status = info and tostring(info.status or info.state or "?") or "?"
drawText(2, 4 + (L.barH + L.gapY)*3, string.format("Status: %s | In: %s RF/t Out: %s RF/t", status, tostring(state.inFlow or 0), tostring(state.outFlow or 0)), colors.white)


-- Botones
drawButton(L.btn.power, "POWER", (status ~= "offline" and status ~= "idle"))
drawButton(L.btn.auto, "AU", state and state.auto)
end


local function inRect(btn, x, y)
return x >= btn.x and x < (btn.x + btn.w) and y >= btn.y and y < (btn.y + btn.h)
end


function M.handleTouch(x, y)
if inRect(L.btn.power, x, y) then return "toggle_power" end
if inRect(L.btn.auto, x, y) then return "toggle_auto" end
return nil
end


return M
