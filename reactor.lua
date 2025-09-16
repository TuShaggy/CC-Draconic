-- reactor.lua — control automático estable
local reactor = {}

function reactor.read(S)
  local info = S.reactor.getReactorInfo()
  return {
    sat        = info.energySaturation,
    field      = info.fieldStrength,
    temp       = info.temperature,
    generation = info.generationRate,
  }
end

function reactor.control(S, stats)
  if not S.reactor then return end

  local sat   = stats.sat * 100
  local field = stats.field * 100

  -- mantener campo ~50%
  if field < 50 then
    S.reactor.setFieldDrainRate(1000000)
  else
    S.reactor.setFieldDrainRate(500000)
  end

  -- salida según saturación
  if sat > 80 then
    S.reactor.setEnergySaturationTarget(70)
  elseif sat < 50 then
    S.reactor.setEnergySaturationTarget(90)
  end
end

return reactor
