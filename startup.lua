-- startup.lua — Loop principal + eventos (HUD estilo drmon con AU funcional)
local F = dofile("lib/f.lua")


local cfg = nil
if not fs.exists("config.lua") then
print("[CC-Draconic] No hay config.lua — ejecuta setup.lua para detectar periféricos.")
else
local ok, res = pcall(dofile, "config.lua")
if ok then cfg = res else print("Error cargando config.lua:", res) end
end


if not cfg then
print("Intentando ejecutar setup.lua...")
if fs.exists("setup.lua") then shell.run("setup.lua") end
local ok, res = pcall(dofile, "config.lua")
if ok then cfg = res else error("No se pudo cargar config.lua. Configura primero.") end
end


local Reactor = dofile("reactor.lua")
local UI = dofile("ui.lua")


-- Inicializa periféricos
local ok, err = Reactor.init(cfg)
if not ok then error(err or "No se pudo inicializar reactor/flux gates/monitor") end
UI.init(cfg.monitor)


-- Estado del programa
local state = {
auto = false, -- AU (Auto)
inFlow = 0, -- RF/t hacia el reactor (campo)
outFlow = 0, -- RF/t desde el reactor (salida)
lastInfo = nil,
}


-- Render & control loop
local function updateLoop()
while true do
local info = Reactor.getInfo()
state.lastInfo = info


if state.auto and info then
local newIn, newOut = Reactor.autotune(info, state.inFlow, state.outFlow)
if newIn then state.inFlow = newIn end
if newOut then state.outFlow = newOut end
end


UI.render(info, { auto = state.auto, inFlow = state.inFlow, outFlow = state.outFlow })
sleep(0.2)
end
end


-- Eventos de pantalla táctil (monitor)
local function eventLoop()
while true do
local e, side, x, y = os.pullEvent()
if e == "monitor_touch" then
local action = UI.handleTouch(x, y)
if action == "toggle_power" then
Reactor.togglePower()
elseif action == "toggle_auto" then
state.auto = not state.auto
end
elseif e == "term_resize" then
UI.refreshGeometry()
end
end
end


parallel.waitForAny(updateLoop, eventLoop)
