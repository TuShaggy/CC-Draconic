# CC-Draconic

--[[
ATM10 Draconic Reactor Controller (CC:Tweaked)
Author: Fabian + ChatGPT
Repo layout (drop these files into your ComputerCraft computer):


startup.lua
lib/f.lua
installer.lua (optional; to self-update from your GitHub)


Requirements
- CC:Tweaked
- Draconic Evolution (reactor + 2 flux gates)
- (Recommended) Advanced Peripherals (for charge/activate/stop via API if present)
- 3x3 Advanced Monitor, wired modems (not wireless)


Wiring (default, configurable below)
- Place computer touching the OUTPUT flux gate on the RIGHT side and a REACTOR STABILIZER on the BACK.
- Attach wired modems to: the INPUT flux gate (injector), the monitor (any side except front), and the computer itself.


Notes
- Works on ATM10 (1.20.x) by using defensive API calls and fallbacks.
- No 'goto' anywhere; clean coroutines.
- Auto-regulates BOTH gates (input = field strength; output = saturation) with PI controllers.
- Failsafes: low field => emergency charge; over-temp => stop until cool; sat 0% => panic (close output).
]]
