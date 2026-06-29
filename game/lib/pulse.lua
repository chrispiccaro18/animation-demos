-- Shared pulse clock. Both drawn sprites and glow requests read from this
-- so they stay in phase rather than running independent timers.
local animation = require("lib.animation")
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
  return minV + (maxV - minV) * animation.pulseValue(_t * speed)
end

-- Like value() but starts at minV when t == startT and rises from there.
-- phase offset of -pi/2 puts pulseValue at 0 when elapsed == 0.
function M.valueFrom(speed, minV, maxV, startT)
  local elapsed = _t - (startT or 0)
  return minV + (maxV - minV) * animation.pulseValue(elapsed * speed - math.pi * 0.5)
end

return M
