-- reactor.lua — Wrapper periféricos + lógica AU (Auto)


-- Normaliza campos comunes
local maxField = info.maxFieldStrength or info.maxField or 0
local field = info.fieldStrength or info.field or 0
local maxSat = info.maxEnergySaturation or info.maxSaturation or 0
local sat = info.energySaturation or info.saturation or 0


info._fieldPct = maxField > 0 and (field / maxField) or 0
info._satPct = maxSat > 0 and (sat / maxSat) or 0
info._inFlow = getGateFlow(per.GI)
info._outFlow = getGateFlow(per.GO)


return info
end


function M.setInFlow(v)
v = math.floor(F.clamp(v or 0, 0, 2_000_000_000))
setGateFlow(per.GI, v)
return v
end


function M.setOutFlow(v)
v = math.floor(F.clamp(v or 0, 0, 2_000_000_000))
setGateFlow(per.GO, v)
return v
end


-- Activa/desactiva el reactor de forma sencilla
function M.togglePower()
if not per.R then return end
local ok, info = pcall(per.R.getReactorInfo)
if not ok or not info then return end


local status = tostring(info.status or info.state or "")
status = string.lower(status)


if status == "offline" or status == "idle" or status == "stopping" then
-- Secuencia de arranque simple
if hasMethod(per.R, "chargeReactor") then per.R.chargeReactor() end
if hasMethod(per.R, "activateReactor") then per.R.activateReactor() end
else
-- Apagar
if hasMethod(per.R, "stopReactor") then per.R.stopReactor() end
-- Bajar flujos para seguridad
M.setInFlow(0)
M.setOutFlow(0)
end
end


-- Lógica del botón AU (Auto): PID simplificado por umbrales
-- Objetivos conservadores (parecido a drmon clásico)
local TARGET = {
fieldPct = 0.35, -- mantener ~35% de campo
tempHi = 8000, -- si sube de esto, extrae más energía
tempLo = 6500, -- si baja de esto, relaja extracción
satMin = 0.20, -- si la saturación cae de 20%, baja extracción
}


local STEP = { inFlow = 50_000, outFlow = 100_000 }


function M.autotune(info, inNow, outNow)
if not info then return inNow, outNow end


local fieldPct = info._fieldPct or 0
local temp = tonumber(info.temperature or 0) or 0
local satPct = info._satPct or 0


-- Control del IN (campo): sube si el campo cae, baja si sobra
if fieldPct < (TARGET.fieldPct - 0.03) then
inNow = inNow + STEP.inFlow
elseif fieldPct > (TARGET.fieldPct + 0.03) then
inNow = math.max(0, inNow - STEP.inFlow)
end


-- Control del OUT (extracción): depende de temp y saturación
if temp > TARGET.tempHi then
outNow = outNow + STEP.outFlow
elseif temp < TARGET.tempLo then
outNow = math.max(0, outNow - STEP.outFlow)
end
if satPct < TARGET.satMin then
outNow = math.max(0, math.floor(outNow * 0.7))
end


inNow = M.setInFlow(inNow)
outNow = M.setOutFlow(outNow)


return inNow, outNow
end


return M
