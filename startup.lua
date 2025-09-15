local f = dofile("lib/f.lua")

-- OUT gate manual adjustments
local yBtn = my-1
if inRect(2,yBtn,"<<<") then S.setOut = S.setOut - 100000; S.autoOut = false end
if inRect(6,yBtn,"<<") then S.setOut = S.setOut - 10000; S.autoOut = false end
if inRect(10,yBtn,"<") then S.setOut = S.setOut - 1000; S.autoOut = false end
if inRect(14,yBtn,S.autoOut and "OUT:AU" or "OUT:MA") then S.autoOut = not S.autoOut end
if inRect(mx-13,yBtn,">") then S.setOut = S.setOut + 1000; S.autoOut = false end
if inRect(mx-9,yBtn,">>") then S.setOut = S.setOut + 10000; S.autoOut = false end
if inRect(mx-5,yBtn,">>>") then S.setOut = S.setOut + 100000; S.autoOut = false end


-- IN gate manual adjustments
local y2 = my
if inRect(2,y2,"<<<") then S.setIn = S.setIn - 100000; S.autoIn = false end
if inRect(6,y2,"<<") then S.setIn = S.setIn - 10000; S.autoIn = false end
if inRect(10,y2,"<") then S.setIn = S.setIn - 1000; S.autoIn = false end
if inRect(14,y2,S.autoIn and "IN:AU" or "IN:MA") then S.autoIn = not S.autoIn end
if inRect(mx-13,y2,">") then S.setIn = S.setIn + 1000; S.autoIn = false end
if inRect(mx-9,y2,">>") then S.setIn = S.setIn + 10000; S.autoIn = false end
if inRect(mx-5,y2,">>>") then S.setIn = S.setIn + 100000; S.autoIn = false end
end


-- ========= MAIN =========
local function uiLoop()
while true do
local ev, side, x, y = os.pullEvent()
if ev == "monitor_touch" then handleTouch(x,y) end
end
end


local function tickLoop()
while true do
local now = os.clock(); local dt = now - S.lastT; S.lastT = now
local info = rxInfo();
if not info then S.action = "Reactor info error" else
controlTick(info, dt)
draw(info)
end
sleep(CFG.UI_TICK)
end
end


local function main()
term.clear(); term.setCursorPos(1,1)
print("ATM10 Draconic Reactor Controller — starting...")
discover()
local mx,my = S.mon.getSize(); print("Monitor:", mx, "x", my)
print("Peripherals OK. AutoIn=", S.autoIn, " AutoOut=", S.autoOut)
parallel.waitForAny(tickLoop, uiLoop)
end


local ok, err = pcall(main)
if not ok then
if S.mon then f.clear(S.mon); S.mon.setCursorPos(2,2); S.mon.write("Error:") S.mon.setCursorPos(2,3); S.mon.write(err or "unknown") end
error(err)
end
