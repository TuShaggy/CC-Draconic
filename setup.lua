-- setup.lua — asistente gráfico de periféricos
local f = require("lib/f")

local setup = {}

function setup.loadConfig()
  if fs.exists("config.lua") then
    local ok,cfg = pcall(dofile,"config.lua")
    if ok then return cfg end
  end
end

function setup.saveConfig(cfg)
  local h=fs.open("config.lua","w")
  h.write("return "..textutils.serialize(cfg))
  h.close()
end

function setup.drawSetup(S)
  local mon=S.mon; f.clear(mon,S.hudTheme); S.buttons={}
  f.center(mon,1,"SETUP REACTOR")
  local opts = {
    {id="reactor",label="REACTOR"},
    {id="monitor",label="MONITOR"},
    {id="in_gate",label="FLUX IN"},
    {id="out_gate",label="FLUX OUT"},
    {id="save",label="SAVE & EXIT"}
  }
  local y=4
  for _,o in ipairs(opts) do
    f.center(mon,y,o.label..": "..(S[o.id] or "???"))
    S.buttons[o.id]={x1=2,y1=y,x2=20,y2=y}
    y=y+2
  end
end

function setup.handleClick(S,id)
  if id=="save" then
    setup.saveConfig(S)
    S.view="DASH"
  elseif S.buttons[id] then
    term.write("Introduce nombre de "..id..": ")
    local v=read()
    S[id]=v
  end
end

return setup
