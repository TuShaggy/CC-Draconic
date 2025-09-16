-- startup.lua — entrypoint del Draconic Reactor Controller
-- Carga módulos y lanza animación + vista inicial

local f = require("lib/f")
local setup = require("setup")
local ui = require("ui")
local reactor = require("reactor")

local S = {
  mon = nil,
  rx = nil,
  inGate = nil,
  outGate = nil,
  spk = nil,
  hudStyle = "CIRCLE",
  modeOut = "SAT",
  power = false,
  view = "BOOT",
}

-- ===== MAIN =====
local function main()
  -- detect speaker si existe
  S.spk = peripheral.find("speaker")

  -- intentar cargar config
  local cfg = setup.loadConfig()
  if cfg then
    S.hudStyle = cfg.hud_style or "CIRCLE"
    if cfg.monitor then S.mon = peripheral.wrap(cfg.monitor) end
    if cfg.reactor then S.rx = peripheral.wrap(cfg.reactor) end
    if cfg.in_gate then S.inGate = peripheral.wrap(cfg.in_gate) end
    if cfg.out_gate then S.outGate = peripheral.wrap(cfg.out_gate) end
    S.view = "DASH"
  else
    local mons = { peripheral.find("monitor") }
    if mons[1] then S.mon = mons[1] end
    S.view = "SETUP"
  end

  if not S.mon then
    print("No se detecta monitor conectado por módem cableado.")
    return
  end

  ui.run(S, reactor, setup)
end

main()
