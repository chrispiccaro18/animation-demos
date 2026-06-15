local screenshake = {}

local trauma    = 0
local elapsed   = 0
local _intensity = 0
local _duration  = 0
local _yScale = 1.0

-- intensity: max pixel offset (default 10)
-- duration:  seconds to decay over (default 0.4)
function screenshake.trigger(intensity, duration)
  _intensity = intensity or 10
  _duration  = duration  or 0.4
  _yScale = 1.5
  trauma     = 1
  elapsed    = 0
end

function screenshake.triggerH(intensity, duration)
  _intensity = intensity or 10
  _duration  = duration  or 0.4
  _yScale = 0.15
  trauma     = 1
  elapsed    = 0
end

function screenshake.update(dt)
  if trauma <= 0 then return end
  elapsed = elapsed + dt
  trauma  = math.max(0, 1 - elapsed / _duration)
end

function screenshake.getOffset()
  if trauma <= 0 then return 0, 0 end
  local ox = _intensity * trauma * math.sin(elapsed * 50) * (SCALE_X or 1)
  local oy = _intensity * trauma * math.sin(elapsed * 50 * 1.6180339887) * _yScale * (SCALE_Y or 1)
  return ox, oy
end

return screenshake
