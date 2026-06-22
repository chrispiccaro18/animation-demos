local config    = require("lib.config")
local PitchRamp = {}
PitchRamp.__index = PitchRamp

-- windowSeconds: gap of silence that resets the ramp
-- basePitch:     pitch on first (or reset) play
-- pitchStep:     added to pitch for each play within the window
-- ignoreSpeed:   if true, window is not divided by config.speed
function PitchRamp.new(windowSeconds, basePitch, pitchStep, ignoreSpeed)
  return setmetatable({
    windowSeconds = windowSeconds or 0.75,
    basePitch     = basePitch     or 1.0,
    pitchStep     = pitchStep     or 0.08,
    ignoreSpeed   = ignoreSpeed   or false,
    count         = 0,
    lastPlayTime  = -math.huge,
  }, PitchRamp)
end

function PitchRamp:getPitch()
  local now           = love.timer.getTime()
  local speed         = self.ignoreSpeed and 1.0 or config.speed
  local effectiveWindow = self.windowSeconds / speed
  if now - self.lastPlayTime > effectiveWindow then
    self.count = 0
  end
  self.count        = self.count + 1
  self.lastPlayTime = now
  return self.basePitch + (self.count - 1) * self.pitchStep
end

-- Manually reset the ramp (e.g. when a sequence ends).
function PitchRamp:reset()
  self.count        = 0
  self.lastPlayTime = -math.huge
end

return PitchRamp
