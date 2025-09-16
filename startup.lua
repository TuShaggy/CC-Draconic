-- setup.lua — Autodetección de periféricos y creación de config.lua
local function firstOfType(ptype)
for _, name in ipairs(peripheral.getNames()) do
if peripheral.getType(name) == ptype then return name end
end
end


local function choose(msg, candidates)
print(msg)
for i, n in ipairs(candidates) do print(string.format(" [%d] %s (%s)", i, n, peripheral.getType(n))) end
write("Selecciona número (o Enter para [1]): ")
local s = read()
local idx = tonumber(s) or 1
return candidates[idx]
end


local names = peripheral.getNames()
if #names == 0 then error("No hay periféricos conectados (necesitas módem cableado)") end


local monitors, reactors, gates = {}, {}, {}
for _, n in ipairs(names) do
local t = peripheral.getType(n)
if t == "monitor" then table.insert(monitors, n)
elseif t == "draconic_reactor" or t == "reactor" or t == "draconic_reactor_core" then table.insert(reactors, n)
elseif t == "flow_gate" or t == "flux_gate" or t == "draconic_flux_gate" then table.insert(gates, n)
end
end


if #monitors == 0 then error("No se encontró monitor") end
if #reactors == 0 then error("No se encontró draconic_reactor") end
if #gates < 2 then error("Se necesitan 2 flow/flux gates (IN/OUT)") end


local monitor = #monitors == 1 and monitors[1] or choose("Elige monitor:", monitors)
local reactor = #reactors == 1 and reactors[1] or choose("Elige reactor:", reactors)


print("Elige GATE **IN** (hacia REACTOR):")
local gateIn = choose("Gate IN:", gates)


-- quita el elegido y usa otro para OUT
local rest = {}
for _, n in ipairs(gates) do if n ~= gateIn then table.insert(rest, n) end end
local gateOut = #rest == 1 and rest[1] or choose("Gate OUT:", rest)


local cfg = string.format([[return {
reactor = %q,
in_gate = %q,
out_gate = %q,
monitor = %q,
}]], reactor, gateIn, gateOut, monitor)


local fh = fs.open("config.lua", "w")
fh.write(cfg)
fh.close()


print("✔ config.lua creado. Puedes ejecutar 'startup.lua'.")
