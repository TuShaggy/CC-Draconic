-- reactor.lua — lógica de control del Draconic Reactor
local reactor = {}

local TARGET_FIELD   = 50
local TARGET_SAT     = 80
local MIN_SAT        = 50
local MAX_SAT        = 95
local TEMP_MAX       = 8000
local CHARGE_FLOW    = 1000000

-- ===== Helpers =====
local function getPer(S,name)
  if not name then
    print("⚠️ getPer: nombre nil")
    return nil
  end
  if S.per and S.per[name] then return S.per[name] end
  if peripheral.isPresent(name) then
    local ok,per = pcall(peripheral.wrap,name)
    if ok then return per end
  end
  print("⚠️ Periférico no encontrado: "..tostring(name))
  return nil
end

-- ===== Info =====
function reactor.getInfo(S)
  local rx = getPer(S,S.reactor)
  if not rx then return {} end
  local ok,info = pcall(rx.getReactorInfo)
  if not ok or not info then return {} end

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

-- ===== ON/OFF =====
function reactor.setActive(S,on)
  local rx = getPer(S,S.reactor)
  if not rx then
    print("⚠️ No se pudo activar reactor, periférico no encontrado.")
    return
  end
  if on then
    rx.activateReactor()
  else
    rx.stopReactor()
  end
end

-- ===== LOOP DE CONTROL =====
function reactor.controlLoop(S)
  local rx   = getPer(S,S.reactor)
  local inG  = getPer(S,S.in_gate)
  local outG = getPer(S,S.out_gate)

  if not rx or not inG or not outG then
    print("⚠️ Reactor o flux gates no detectados. Ejecuta SETUP.")
    return
  end

  while true do
    local ok,info = pcall(rx.getReactorInfo)
    if ok and info then
      local satP   = (info.energySaturation / info.maxEnergySaturation) * 100
      local fieldP = (info.fieldStrength / info.maxFieldStrength) * 100
      local temp   = info.temperature

      -- === FIELD ===
      if fieldP < TARGET_FIELD then
        inG.setFlow(CHARGE_FLOW)
      else
        inG.setFlow(500000)
      end

      -- === SALIDA ===
      local mode = S.modeOut or "SAT"
      local flow = outG.getFlow()

      if mode == "SAT" then
        if satP > MAX_SAT then
          flow = math.max(0, flow - 100000)
        elseif satP < TARGET_SAT then
          flow = flow + 100000
        end
      elseif mode == "MAXGEN" then
        if satP > MIN_SAT then
          flow = flow + 200000
        else
          flow = math.max(0, flow - 200000)
        end
      elseif mode == "ECO" then
        if satP > TARGET_SAT then
          flow = flow + 50000
        else
          flow = math.max(0, flow - 50000)
        end
      elseif mode == "TURBO" then
        flow = flow + 300000
        if satP < MIN_SAT then
          flow = math.max(0, flow - 300000)
        end
      elseif mode == "PROTECT" then
        if temp > TEMP_MAX or fieldP < 30 then
          flow = 0
        elseif satP > TARGET_SAT then
          flow = flow + 100000
        else
          flow = math.max(0, flow - 100000)
        end
      end

      if satP < MIN_SAT then
        flow = 0
        print("⚠️ Saturación crítica, salida cortada.")
      end

      outG.setFlow(math.max(0, flow))
    else
      print("⚠️ No se pudo leer reactor info.")
    end
    sleep(0.5)
  end
end

return reactor
