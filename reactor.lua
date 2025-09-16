-- reactor.lua — lógica de reactor y flux gates usando perutils
local P = require("lib/perutils")
local reactor = {}

-- leer estado del reactor
function reactor.read(S)
  local ok, r = pcall(function() return S.reactor.getReactorInfo() end)
  if not ok or not r then
    return { sat = 0, field = 0, temp = 0, generation = 0 }
  end
  return {
    sat = r.energySaturation / r.maxEnergySaturation,
    field = r.fieldStrength / r.maxFieldStrength,
    temp = r.temperature,
    generation = r.generationRate,
  }
end

-- control automático
function reactor.control(S, stats)
  local mode = S.mode
  local out = 0
  local inFlow = 2000000

  if mode == "SAT" then
    if stats.sat > 0.82 then out = 10000000
    elseif stats.sat < 0.78 then out = 1000000 end

  elseif mode == "MAXGEN" then
    if stats.sat > 0.55 then out = 20000000 else out = 0 end

  elseif mode == "ECO" then
    if stats.sat > 0.85 then out = 4000000 else out = 1000000 end

  elseif mode == "TURBO" then
    out = 30000000

  elseif mode == "PROTECT" then
    if stats.temp > 8000 or stats.field < 0.3 then out = 0 else out = 10000000 end
  end

  -- failsafes
  if stats.sat < 0.5 then out = 0 end
  if stats.field < 0.3 then inFlow = 6000000 end

  -- flux gates seguros usando perutils
  local okIn, inGate = pcall(P.get, S.in_gate or "flow_gate")
  local okOut, outGate = pcall(P.get, S.out_gate or "flow_gate")

  if okIn and inGate and inGate.setSignalLowFlow then
    inGate.setSignalLowFlow(inFlow)
  end
  if okOut and outGate and outGate.setSignalLowFlow then
    outGate.setSignalLowFlow(out)
  end
end

return reactor
