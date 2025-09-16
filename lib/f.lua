-- lib/f.lua — utilidades varias (compat ampliada, corregida)
local ok, list = pcall(peripheral.getMethods, peripheral.getName(p))
if not ok or not list then return false end
for _, mm in ipairs(list) do
if mm == m then return true end
end
return false
end


-- Formatos
local function _fmtInt(n)
local s = tostring(math.floor(math.abs(n)))
local out, c = "", 0
for i = #s, 1, -1 do
out = s:sub(i,i) .. out
c = c + 1
if c == 3 and i > 1 then
out = "," .. out
c = 0
end
end
if n < 0 then out = "-" .. out end
return out
end


function F.formatNum(n)
if n == nil then return "0" end
local abs = math.abs(n)
if abs >= 1000000000000 then return F.round(n/1000000000000,2).."T" end
if abs >= 1000000000 then return F.round(n/1000000000,2).."G" end
if abs >= 1000000 then return F.round(n/1000000,2).."M" end
if abs >= 1000 then return F.round(n/1000,2).."k" end
return _fmtInt(n)
end
function F.formatRF(n)
return F.formatNum(n) .. " RF/t"
end
function F.formatPct(x)
return tostring(math.floor((x or 0)*100+0.5)) .. "%"
end
function F.formatTemp(c)
return _fmtInt(math.floor(c or 0)) .. "°C"
end


-- Pantalla/Monitor
local function _redir(to)
if not to then return term, function() end end
local old = term.redirect(to)
return old, function() term.redirect(old) end
end
function F.clear(mon, bg)
local old, restore = _redir(mon)
term.setBackgroundColor(bg or colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1,1)
restore()
end
function F.centerText(mon, y, txt, fg, bg)
local old, restore = _redir(mon)
local w = ({term.getSize()})[1]
if bg then term.setBackgroundColor(bg) end
if fg then term.setTextColor(fg) end
local x = math.max(1, math.floor((w - #txt)/2) + 1)
term.setCursorPos(x, y)
term.write(txt)
restore()
end
function F.drawBox(mon, x,y,w,h,bg)
local old, restore = _redir(mon)
term.setBackgroundColor(bg or colors.gray)
for yy = y, y+h-1 do
term.setCursorPos(x, yy)
term.write(string.rep(" ", w))
end
restore()
end
function F.drawProgress(mon, x,y,w,h, pct, fg, bg)
pct = F.clamp(pct or 0, 0, 1)
F.drawBox(mon, x,y,w,h, bg or colors.gray)
local fill = math.floor(w * pct)
if fill > 0 then F.drawBox(mon, x, y, fill, h, fg or colors.lime) end
end


-- Sonido
function F.beep(spk, freq, dur)
if type(spk) == 'string' then spk = F.safeWrap(spk) end
if not spk or not F.hasMethod(spk, 'playNote') then return end
local note = 12 -- nota media
local vol = 1
pcall(spk.playNote, 'bell', vol, note)
end


return F
