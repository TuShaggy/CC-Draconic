-- reactor.lua — lógica de control del Draconic Reactor
local reactor = {}

-- Valores objetivo (puedes ajustarlos en config si quieres)
local TARGET_FIELD   = 50    -- % objetivo de field strength
local TARGET_SAT     = 80    -- % objetivo de energy saturation
local MIN_SAT        = 50    -- % mínimo seguro de saturación
local MAX_SAT        = 95    -- % máximo antes de recortar
local TEMP_MAX       = 8000  -- temperatura máxima antes de cortar
local CHARGE_FLOW    = 1000000 -- RF/t para recarga inicial

-- Helpers para obtener periféricos
local function getPer(S,name)
  return S.per[name] or peripheral.wrap(name)
end

-- Devuelve info del reactor
function reactor.getInfo(S)
  local rx = getPer(S,S.reactor)
  if not rx then return {} end
  local info = rx.getReactorInfo()
  if not info then return {} end

  local satP   = (info.energySaturation / info.maxEnergySaturation) * 100
  local fieldP = (info.fieldStrength / info.maxFieldStrength) * 100
  return {
    satP = satP,
    fieldP = fieldP,
    gen = info.generationRate,
    temp = info.temperature,
    status = info.status
  }
end

-- Cambia estado ON/OFF del reactor
function reactor.setActive(S,on)
  local rx = getPer(S,S.reactor)
  if not rx then return end
  if on then rx.activateReactor() else rx.stopReactor() end
end

-- ===== LOOP DE CONTROL =====
function reactor.controlLoop(S)
  local rx   = getPer(S,S.reactor)
  local inG  = getPer(S,S.in_gate)
  local outG = getPer(S,S.out_gate)

  if not rx or not inG or not outG then
    print("⚠️ Falta reactor o flux gates.")
    return
  end

  while true do
    local info = rx.getReactorInfo()
    if info then
      local satP   = (info.energySaturation / info.maxEnergySaturation) * 100
      local fieldP = (info.fieldStrength / info.maxFieldStrength) * 100
      local temp   = info.temperature

      -- === CONTROL FIELD ===
      if fieldP < TARGET_FIELD then
        inG.setFlow(CHARGE_FLOW) -- meter mucha energía si falta campo
      else
        inG.setFlow(500000) -- flujo base estable
      end

      -- === CONTROL OUTPUT SEGÚN MODO ===
      local mode = S.modeOut or "SAT"
      local flow = outG.getFlow()

      if mode == "SAT" then
        -- Mantener saturación alrededor del TARGET_SAT
        if satP > MAX_SAT then
          flow = math.max(0, flow - 100000)
        elseif satP < TARGET_SAT then
          flow = flow + 100000
        end

      elseif mode == "MAXGEN" then
        -- Sacar lo máximo posible, pero no bajar de MIN_SAT
        if satP > MIN_SAT then
          flow = flow + 200000
        else
          flow = math.max(0, flow - 200000)
        end

      elseif mode == "ECO" then
        -- Mantener potencia baja, estable
        if satP > TARGET_SAT then
          flow = flow + 50000
        else
          flow = math.max(0, flow - 50000)
        end

      elseif mode == "TURBO" then
        -- Priorizamos potencia fuerte, aunque baje saturación
        flow = flow + 300000
        if satP < MIN_SAT then
          flow = math.max(0, flow - 300000)
        end

      elseif mode == "PROTECT" then
        -- Si hay riesgo, bajamos salida
        if temp > TEMP_MAX or fieldP < 30 then
          flow = 0
        elseif satP > TARGET_SAT then
          flow = flow + 100000
        else
          flow = math.max(0, flow - 100000)
        end
      end

      -- Aplicamos límites
      if satP < MIN_SAT then
        flow = 0 -- parar si se queda sin energía
      end

      -- Establecer flujo en flux gate de salida
      outG.setFlow(math.max(0, flow))
    end
    sleep(0.5)
  end
end

return reactor
