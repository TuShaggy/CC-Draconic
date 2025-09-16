-- startup.lua — entrypoint
local reactor = require("reactor")
local ui      = require("ui")
local setup   = require("setup")

local S = {
  reactor   = nil,
  monitor   = nil,
  in_gate   = nil,
  out_gate  = nil,
  spk       = nil,
  hudStyle  = "CIRCLE",
  hudTheme  = "minimalist",
  modeOut   = "SAT",
  power     = false,
  view      = "BOOT",
  step      = 1,
  per       = {}
}

-- Cargar config guardada si existe
local function loadConfig()
  if fs.exists("config.lua") then
    local ok,cfg = pcall(dofile,"config.lua")
    if ok and cfg then
      for k,v in pairs(cfg) do S[k]=v end
    end
  end
end

loadConfig()

-- Arranque en paralelo: UI + reactor control
parallel.waitForAny(
  function() ui.run(S, reactor, setup) end,
  function() reactor.controlLoop(S) end
)
