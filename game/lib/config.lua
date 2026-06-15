local config = {}

config.speedPresets = {0.5, 1.0, 2.0}
config.speedIndex   = 2
config.speed        = 1.0

function config.cycleSpeed()
  config.speedIndex = (config.speedIndex % #config.speedPresets) + 1
  config.speed = config.speedPresets[config.speedIndex]
end

function config.currentSpeed()
  return config.speed
end

return config
