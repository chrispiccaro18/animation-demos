local Audio = {}

function Audio.load()
  Audio.sfx = {
    clink = {
      -- love.audio.newSource("assets/audio/sfx/clink.wav", "static"),
      love.audio.newSource("assets/audio/sfx/clink2.wav", "static"),
      love.audio.newSource("assets/audio/sfx/clink3.wav", "static"),
      love.audio.newSource("assets/audio/sfx/clink4.wav", "static"),
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
    scanner = love.audio.newSource("assets/audio/sfx/scanner.wav", "stream")
  }
end

function Audio.playClink()
  if Audio.sfx and Audio.sfx.clink then
    local clinkClone = Audio.sfx.clink[math.random(#Audio.sfx.clink)]:clone()
    -- Audio.sfx.clink:stop()
    -- add some variation to the pitch to make it sound less repetitive
    clinkClone:setPitch(1 + (math.random() - 0.5) * 0.2)
    -- and volume
    clinkClone:setVolume(0.8 + (math.random() - 0.5) * 0.2)
    clinkClone:play()
  end
end

function Audio.playDeal()
  if Audio.sfx and Audio.sfx.deal then
    local dealClone = Audio.sfx.deal:clone()
    dealClone:setPitch(1 + (math.random() - 0.2) * 0.2)
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
    impactInClone:setVolume(0.8 + (math.random() - 0.5) * 0.2)
    impactInClone:play()
  end
end

function Audio.playImpactOut(type)
  if Audio.sfx and Audio.sfx.impactOut and Audio.sfx.impactOut[type] then
    local impactOutClone = Audio.sfx.impactOut[type]:clone()
    impactOutClone:setPitch(1 + (math.random() - 0.5) * 0.2)
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

return Audio
