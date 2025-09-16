-- reactor.lua — lógica de reactor y flux gates
local reactor = {}

-- leer estado del reactor
function reactor.read(S)
  local r = S.reactor.getReactorInfo()
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

  if S.in_gate then S.in_gate.setSignalLowFlow(inFlow) end
  if S.out_gate then S.out_gate.setSignalLowFlow(out) end
end

return reactor
