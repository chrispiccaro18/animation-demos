-- Shared pulse clock. Both drawn sprites and glow requests read from this
-- so they stay in phase rather than running independent timers.
local _t = 0
local M  = {}

function M.update(dt)
  _t = _t + dt
end

function M.getTime()
  return _t
end

-- Returns a value in [minV, maxV] oscillating at `speed` Hz.
function M.value(speed, minV, maxV)
  return minV + (maxV - minV) * (math.sin(_t * speed) * 0.5 + 0.5)
end

-- Like value() but starts at minV when t == startT and rises from there.
-- sin(-pi/2) == -1, so factor == 0 at elapsed == 0.
function M.valueFrom(speed, minV, maxV, startT)
  local elapsed = _t - (startT or 0)
  return minV + (maxV - minV) * (math.sin(elapsed * speed - math.pi * 0.5) * 0.5 + 0.5)
end

return M
