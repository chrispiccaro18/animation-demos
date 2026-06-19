local config = {}

config.speedPresets = {0.7, 1.0, 2.0}
config.speedIndex   = 1
config.speed        = 0.7

function config.cycleSpeed()
  config.speedIndex = (config.speedIndex % #config.speedPresets) + 1
  config.speed = config.speedPresets[config.speedIndex]
end

function config.currentSpeed()
  return config.speed
end

return config
