-- reactor.lua — control reactor start/stop + info
local reactor = {}

function reactor.getInfo(S)
  if not S.rx then return nil end
  local ok,info=pcall(S.rx.getReactorInfo)
  if not ok or not info then return nil end
  local function pct(n,d) if not n or not d or d==0 then return 0 end return (n/d)*100 end
  return {
    status=info.status or "unknown",
    gen=info.generationRate or 0,
    temp=info.temperature or 0,
    satP=pct(info.energySaturation,info.maxEnergySaturation),
    fieldP=pct(info.fieldStrength,info.maxFieldStrength),
  }
end

function reactor.setActive(S,active)
  if not S.rx then return end
  if active then
    if S.rx.chargeReactor then pcall(S.rx.chargeReactor) end
    if S.rx.activateReactor then pcall(S.rx.activateReactor) end
    if S.rx.setActive then pcall(S.rx.setActive,true) end
  else
    if S.rx.stopReactor then pcall(S.rx.stopReactor) end
    if S.rx.deactivateReactor then pcall(S.rx.deactivateReactor) end
    if S.rx.setActive then pcall(S.rx.setActive,false) end
  end
end

return reactor
