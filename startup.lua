-- startup.lua

local P = dofile("lib/perutils.lua")
local f = dofile("lib/f.lua")
local ui = dofile("ui.lua")
local reactor = dofile("reactor.lua")

local S = { mode = "SAT", hudTheme = "minimalist" }

if fs.exists("config.lua") then
  local ok, cfg = pcall(dofile, "config.lua")
  if ok and type(cfg) == "table" then
    for k,v in pairs(cfg) do S[k] = v end
  end
end

local function initPeripherals()
  local ok, per = pcall(P.get, S.reactor or "draconic_reactor")
  if ok then S.reactor = per else S.reactor = nil end
  local okm, mon = pcall(P.get, S.monitor or "monitor")
  if okm then S.mon = mon else S.mon = term end
end

initPeripherals()

local function tickLoop()
  while true do
    if S.reactor then
      local stats = reactor.read(S)
      reactor.control(S, stats)
      ui.drawMain(S, stats)
    else
      ui.drawMain(S, {sat=0, field=0, temp=0, generation=0})
    end
    sleep(1)
  end
end

local function uiLoop()
  while true do sleep(0.1) end
end

parallel.waitForAny(tickLoop, uiLoop)
