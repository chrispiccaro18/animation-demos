local PitchRamp = require("assets.audio.pitch_ramp")
local config    = require("lib.config")

local zipRamp  = PitchRamp.new()
local dealRamp = PitchRamp.new()
local impactOutThreatRamp = PitchRamp.new()
local impactOutProgressRamp = PitchRamp.new()

local MIN_CLINK_GAP = 0.02  -- seconds between staggered clinks
local clinkQueue    = {}
local nextClinkTime = 0

local Audio = {}

function Audio.update()
  if not (Audio.sfx and Audio.sfx.clink) then return end
  local now       = love.timer.getTime()
  local remaining = {}
  for _, item in ipairs(clinkQueue) do
    if now >= item.time then
      local clone = Audio.sfx.clink[math.random(#Audio.sfx.clink)]:clone()
      clone:setPitch(item.pitch)
      clone:setVolume(item.volume)
      clone:play()
    else
      remaining[#remaining + 1] = item
    end
  end
  clinkQueue = remaining
end

function Audio.load()
  Audio.sfx = {
    clink = {
      love.audio.newSource("assets/audio/sfx/clink.wav", "static"),
      love.audio.newSource("assets/audio/sfx/clink2.wav", "static"),
      love.audio.newSource("assets/audio/sfx/clink3.wav", "static"),
      love.audio.newSource("assets/audio/sfx/clink4.wav", "static"),
      love.audio.newSource("assets/audio/sfx/clink5.wav", "static"),
    },
    deal = love.audio.newSource("assets/audio/sfx/deal.wav", "static"),
    hover = love.audio.newSource("assets/audio/sfx/hover.wav", "static"),
    drag = love.audio.newSource("assets/audio/sfx/drag.wav", "static"),
    error = love.audio.newSource("assets/audio/sfx/error.wav", "static"),
    ramImpact = love.audio.newSource("assets/audio/sfx/ramImpact.wav", "static"),
    impactIn = love.audio.newSource("assets/audio/sfx/impactIn.wav", "static"),
    impactOut = {
      threat = love.audio.newSource("assets/audio/sfx/impactOutThreat.wav", "static"),
      progress = love.audio.newSource("assets/audio/sfx/impactOutProgress.wav", "static"),
    },
    laserStart = love.audio.newSource("assets/audio/sfx/laserStart.wav", "static"),
    scanner = love.audio.newSource("assets/audio/sfx/scanner2.wav", "stream"),
    press = love.audio.newSource("assets/audio/sfx/press.wav", "static"),
    clickIn = love.audio.newSource("assets/audio/sfx/click-in-w-thump.wav", "static"),
    clickOut = love.audio.newSource("assets/audio/sfx/click-out-w-thump.wav", "static"),
    zip = love.audio.newSource("assets/audio/sfx/zip.wav", "static"),
  }
end

function Audio.playClink()
  if not (Audio.sfx and Audio.sfx.clink) then return end
  local now        = love.timer.getTime()
  local scheduleAt = math.max(now, nextClinkTime)
  nextClinkTime    = scheduleAt + MIN_CLINK_GAP / config.speed
  table.insert(clinkQueue, {
    time   = scheduleAt,
    pitch  = 1 + (math.random() - 0.5) * 0.2,
    volume = 0.8 + (math.random() - 0.5) * 0.2,
  })
end

function Audio.playDeal()
  if Audio.sfx and Audio.sfx.deal then
    local dealClone = Audio.sfx.deal:clone()
    dealClone:setPitch(dealRamp:getPitch())
    dealClone:setVolume(0.8 + (math.random() - 0.5) * 0.2)
    dealClone:play()
  end
end

function Audio.playHover()
  if Audio.sfx and Audio.sfx.hover then
    local hoverClone = Audio.sfx.hover:clone()
    hoverClone:setPitch(1 + (math.random() - 0.2) * 0.2)
    hoverClone:setVolume(0.8 + (math.random() - 0.5) * 0.2)
    hoverClone:play()
  end
end

function Audio.playDrag()
  if Audio.sfx and Audio.sfx.drag then
    local dragClone = Audio.sfx.drag:clone()
    -- dragClone:setPitch(1 + (math.random() - 0.5) * 0.2)
    dragClone:setVolume(0.8 + (math.random() - 0.5) * 0.2)
    dragClone:play()
  end
end

function Audio.playError()
  if Audio.sfx and Audio.sfx.error then
    local errorClone = Audio.sfx.error:clone()
    errorClone:setPitch(1 + (math.random() - 0.5) * 0.2)
    errorClone:setVolume(0.8 + (math.random() - 0.5) * 0.2)
    errorClone:play()
  end
end

function Audio.playRamImpact()
  if Audio.sfx and Audio.sfx.ramImpact then
    local ramImpactClone = Audio.sfx.ramImpact:clone()
    ramImpactClone:setPitch(1 + (math.random() - 0.5) * 0.2)
    ramImpactClone:setVolume(2 + (math.random() - 0.5) * 0.2)
    ramImpactClone:play()
  end
end

function Audio.playImpactIn()
  if Audio.sfx and Audio.sfx.impactIn then
    local impactInClone = Audio.sfx.impactIn:clone()
    impactInClone:setPitch(1 + (math.random() - 0.5) * 0.2)
    impactInClone:setVolume(0.5 + (math.random() - 0.5) * 0.2)
    impactInClone:play()
  end
end

function Audio.playImpactOut(type)
  if Audio.sfx and Audio.sfx.impactOut and Audio.sfx.impactOut[type] then
    local impactOutClone = Audio.sfx.impactOut[type]:clone()
    if type == "threat" then
      impactOutClone:setPitch(impactOutThreatRamp:getPitch())
    elseif type == "progress" then
      impactOutClone:setPitch(impactOutProgressRamp:getPitch())
    else
      impactOutClone:setPitch(1 + (math.random() - 0.5) * 0.2)
    end
    impactOutClone:setVolume(0.8 + (math.random() - 0.5) * 0.2)
    impactOutClone:play()
  end
end

function Audio.playLaserStart()
  if Audio.sfx and Audio.sfx.laserStart then
    local laserStartClone = Audio.sfx.laserStart:clone()
    laserStartClone:setPitch(1 + (math.random() - 0.5) * 0.2)
    laserStartClone:setVolume(0.8 + (math.random() - 0.5) * 0.2)
    laserStartClone:play()
  end
end

function Audio.playScannerLoop()
  if Audio.sfx and Audio.sfx.scanner then
    Audio.sfx.scanner:setLooping(true)
    Audio.sfx.scanner:play()
  end
end

function Audio.stopScanner()
  if Audio.sfx and Audio.sfx.scanner then
    Audio.sfx.scanner:stop()
  end
end

function Audio.playPress()
  if Audio.sfx and Audio.sfx.press then
    local pressClone = Audio.sfx.press:clone()
    pressClone:setPitch(1 + (math.random() - 0.5) * 0.2)
    pressClone:setVolume(0.8 + (math.random() - 0.5) * 0.2)
    pressClone:play()
  end
end

function Audio.playClickIn()
  if Audio.sfx and Audio.sfx.clickIn then
    local clickInClone = Audio.sfx.clickIn:clone()
    clickInClone:setPitch(1 + (math.random() - 0.5) * 0.2)
    clickInClone:setVolume(0.8 + (math.random() - 0.5) * 0.2)
    clickInClone:play()
  end
end

function Audio.playClickOut()
  if Audio.sfx and Audio.sfx.clickOut then
    local clickOutClone = Audio.sfx.clickOut:clone()
    clickOutClone:setPitch(1 + (math.random() - 0.5) * 0.2)
    clickOutClone:setVolume(0.8 + (math.random() - 0.5) * 0.2)
    clickOutClone:play()
  end
end

function Audio.playZip()
  if Audio.sfx and Audio.sfx.zip then
    local zipClone = Audio.sfx.zip:clone()
    zipClone:setPitch(zipRamp:getPitch())
    zipClone:setVolume(0.1)
    zipClone:play()
  end
end

return Audio
