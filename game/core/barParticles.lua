local overlayStats = require("lib.overlayStats")

local barParticles = {}

local COUNT_MIN    = 10   -- base layer particles at empty bar
local COUNT_MAX    = 20  -- base layer particles at full bar
local SPEED        = 200  -- base launch speed (game px/s, scales with resolution)
local LIFETIME_MIN = 0.75
local LIFETIME_MAX = 1.5
-- local LIFETIME_MIN = 0.3
-- local LIFETIME_MAX = 0.75
local SIZE_BIRTH   = 14   -- base layer particle size at birth (game px)
local SIZE_MID     = 10   -- base layer particle size at mid-life (game px)

local LAYER_LARGE_SIZE  = 4.0  -- size multiplier for large layer
local LAYER_LARGE_COUNT = 0.25  -- count multiplier for large layer
local LAYER_SMALL_SIZE  = 0.5  -- size multiplier for small layer
local LAYER_SMALL_COUNT = 2.0  -- count multiplier for small layer

local LAYER_SIZE_MULTS  = { LAYER_LARGE_SIZE, 1.0, LAYER_SMALL_SIZE }
local LAYER_COUNT_MULTS = { LAYER_LARGE_COUNT, 1.0, LAYER_SMALL_COUNT }

local progressLayers = {}
local threatLayers   = {}
local BUFFER_SIZE    = 512

local function makeParticleTexture()
  local imgData = love.image.newImageData(4, 4)
  for y = 0, 3 do
    for x = 0, 3 do
      imgData:setPixel(x, y, 1, 1, 1, 1)
    end
  end
  return love.graphics.newImage(imgData)
end

local function buildPS(texture, r1, g1, b1, r2, g2, b2, sizeMult)
  local ps = love.graphics.newParticleSystem(texture, BUFFER_SIZE)
  ps:setParticleLifetime(LIFETIME_MIN, LIFETIME_MAX)
  ps:setEmissionRate(0)
  ps:setDirection(0)
  ps:setSpread(2 * math.pi)
  ps:setLinearAcceleration(0, 0, 0, 0)
  local baseSpeed = SPEED * SCALE_X
  ps:setSpeed(baseSpeed * 0.6, baseSpeed * 1.6)
  local sizeBirth = (SIZE_BIRTH * SCALE_X * sizeMult) / 4
  local sizeMid   = (SIZE_MID   * SCALE_X * sizeMult) / 4
  ps:setSizes(sizeBirth, sizeMid, 0)
  ps:setSizeVariation(0.35)
  ps:setRotation(0, 2 * math.pi)
  ps:setSpin(-6, 6)
  ps:setSpinVariation(1)
  ps:setColors(r1, g1, b1, 1.0,  r2, g2, b2, 0.0)
  return ps
end

local function makeLayers(tex, r1, g1, b1, r2, g2, b2)
  local layers = {}
  for _, sizeMult in ipairs(LAYER_SIZE_MULTS) do
    table.insert(layers, buildPS(tex, r1, g1, b1, r2, g2, b2, sizeMult))
  end
  return layers
end

function barParticles.load()
  local tex = makeParticleTexture()
  progressLayers = makeLayers(tex, 0.4, 1.0, 0.5,  0.2, 0.8, 0.3)
  threatLayers   = makeLayers(tex, 1.0, 0.45, 0.1, 1.0, 0.2, 0.1)
  for _, ps in ipairs(progressLayers) do overlayStats.registerParticleSystem(ps) end
  for _, ps in ipairs(threatLayers)   do overlayStats.registerParticleSystem(ps) end
end

local function emitLayers(layers, x, y, baseCount)
  for i, ps in ipairs(layers) do
    ps:setPosition(x, y)
    ps:emit(math.max(1, math.floor(baseCount * LAYER_COUNT_MULTS[i])))
  end
end

function barParticles.emit(bar, tokenType)
  local layers = (tokenType == "progress") and progressLayers or threatLayers
  local segIndex = bar.count - 1
  local cx = bar.x + segIndex * bar.gapX + bar.w / 2
  local cy = bar.y + bar.h / 2
  local count = math.floor(COUNT_MIN + (COUNT_MAX - COUNT_MIN) * (bar.count / bar.max))
  emitLayers(layers, cx, cy, count)
end

function barParticles.emitAt(x, y, tokenType, count)
  local layers = (tokenType == "progress") and progressLayers or threatLayers
  emitLayers(layers, x, y, count)
end

function barParticles.update(dt)
  for _, ps in ipairs(progressLayers) do ps:update(dt) end
  for _, ps in ipairs(threatLayers)   do ps:update(dt) end
end

function barParticles.draw()
  love.graphics.setColor(1, 1, 1, 1)
  for _, ps in ipairs(progressLayers) do love.graphics.draw(ps, 0, 0) end
  for _, ps in ipairs(threatLayers)   do love.graphics.draw(ps, 0, 0) end
end

return barParticles
