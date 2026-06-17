local overlayStats = require("lib.overlayStats")

local particles = {}

local DEFAULT = {
  speed         = 500,
  lifetimeMin   = 0.75,
  lifetimeMax   = 1.5,
  sizeBirth     = 14,
  sizeMid       = 10,
  sizeVariation = 0.35,
  bufferSize    = 512,
  layers = {
    { sizeMult = 4.0, countMult = 0.25 },
    { sizeMult = 1.0, countMult = 1.0  },
    { sizeMult = 0.5, countMult = 2.0  },
  },
}

local _tex     = nil
local _presets = {}

local function ensureTexture()
  if _tex then return end
  local imgData = love.image.newImageData(4, 4)
  for y = 0, 3 do
    for x = 0, 3 do imgData:setPixel(x, y, 1, 1, 1, 1) end
  end
  _tex = love.graphics.newImage(imgData)
end

-- Returns the PS and a table of all computed defaults so they can be stored
-- on the layer entry and restored after per-emit overrides.
local function buildPS(cfg, sizeMult)
  local bufSize   = cfg.bufferSize    or DEFAULT.bufferSize
  local lifMin    = cfg.lifetimeMin   or DEFAULT.lifetimeMin
  local lifMax    = cfg.lifetimeMax   or DEFAULT.lifetimeMax
  local speed     = cfg.speed         or DEFAULT.speed
  local sizeBirth = cfg.sizeBirth     or DEFAULT.sizeBirth
  local sizeMid   = cfg.sizeMid       or DEFAULT.sizeMid
  local sizeVar   = cfg.sizeVariation or DEFAULT.sizeVariation
  local c1        = cfg.color1
  local c2        = cfg.color2
  local baseSpeed = speed * SCALE_X
  local sb        = (sizeBirth * SCALE_X * sizeMult) / 4
  local sm        = (sizeMid   * SCALE_X * sizeMult) / 4

  local ps = love.graphics.newParticleSystem(_tex, bufSize)
  ps:setParticleLifetime(lifMin, lifMax)
  ps:setEmissionRate(0)
  ps:setDirection(0)
  ps:setSpread(2 * math.pi)
  ps:setLinearAcceleration(0, 0, 0, 0)
  ps:setSpeed(baseSpeed * 0.6, baseSpeed * 1.6)
  ps:setSizes(sb, sm, 0)
  ps:setSizeVariation(sizeVar)
  ps:setRotation(0, 2 * math.pi)
  ps:setSpin(-6, 6)
  ps:setSpinVariation(1)
  ps:setColors(c1[1], c1[2], c1[3], 1.0, c2[1], c2[2], c2[3], 0.0)

  return ps, {
    speedMin = baseSpeed * 0.6,
    speedMax = baseSpeed * 1.6,
    lifMin   = lifMin,
    lifMax   = lifMax,
    sb       = sb,
    sm       = sm,
    sizeVar  = sizeVar,
  }
end

-- Temporarily override per-emit properties. opts fields (all in config units):
--   speed, lifetimeMin, lifetimeMax, sizeBirth, sizeMid, sizeVariation
local function applyOverrides(layer, opts)
  if not opts then return end
  if opts.speed then
    local s = opts.speed * SCALE_X
    layer.ps:setSpeed(s * 0.6, s * 1.6)
  end
  if opts.lifetimeMin or opts.lifetimeMax then
    layer.ps:setParticleLifetime(
      opts.lifetimeMin or layer.lifMin,
      opts.lifetimeMax or layer.lifMax
    )
  end
  if opts.sizeBirth or opts.sizeMid then
    local birth = opts.sizeBirth and (opts.sizeBirth * SCALE_X * layer.sizeMult / 4) or layer.sb
    local mid   = opts.sizeMid   and (opts.sizeMid   * SCALE_X * layer.sizeMult / 4) or layer.sm
    layer.ps:setSizes(birth, mid, 0)
  end
  if opts.sizeVariation ~= nil then
    layer.ps:setSizeVariation(opts.sizeVariation)
  end
end

local function restoreDefaults(layer)
  layer.ps:setSpeed(layer.speedMin, layer.speedMax)
  layer.ps:setParticleLifetime(layer.lifMin, layer.lifMax)
  layer.ps:setSizes(layer.sb, layer.sm, 0)
  layer.ps:setSizeVariation(layer.sizeVar)
end

function particles.define(name, config)
  ensureTexture()
  local layerDefs = config.layers or DEFAULT.layers
  local layers = {}
  for _, ld in ipairs(layerDefs) do
    local ps, built = buildPS(config, ld.sizeMult)
    overlayStats.registerParticleSystem(ps)
    table.insert(layers, {
      ps        = ps,
      countMult = ld.countMult,
      sizeMult  = ld.sizeMult,
      speedMin  = built.speedMin,
      speedMax  = built.speedMax,
      lifMin    = built.lifMin,
      lifMax    = built.lifMax,
      sb        = built.sb,
      sm        = built.sm,
      sizeVar   = built.sizeVar,
    })
  end
  _presets[name] = layers
end

function particles.load()
  particles.define("progress", { color1 = {0.4, 1.0, 0.5},  color2 = {0.2, 0.8, 0.3} })
  particles.define("threat",   { color1 = {1.0, 0.45, 0.1}, color2 = {1.0, 0.2, 0.1} })

  local trailLayers = { { sizeMult = 1.0, countMult = 1.0 } }
  local function trail(c1, c2)
    return {
      color1 = c1, color2 = c2,
      lifetimeMin = 0.25, lifetimeMax = 0.5,
      sizeBirth = 10, sizeMid = 5, sizeVariation = 0.4,
      bufferSize = 256, layers = trailLayers,
    }
  end

  particles.define("progress_trail", trail({0.4,  1.0,  0.5},  {0.2,  0.8,  0.3}))
  particles.define("threat_trail",   trail({1.0,  0.45, 0.1},  {1.0,  0.2,  0.1}))
  particles.define("ram_trail",      trail({1.0,  0.85, 0.2},  {0.9,  0.55, 0.05}))
  particles.define("nullify_trail",  trail({0.7,  0.3,  1.0},  {0.5,  0.1,  0.8}))
  particles.define("token_trail",    trail({1.0,  1.0,  0.9},  {0.7,  0.7,  0.6}))
end

-- opts (optional): { speed, lifetimeMin, lifetimeMax, sizeBirth, sizeMid, sizeVariation, layers }
-- layers: number — only emit from the first N layers of the preset (default: all)
function particles.emit(name, x, y, count, opts)
  local layers = _presets[name]
  if not layers then return end
  local maxLayer = (opts and type(opts.layers) == "number") and opts.layers or #layers
  for i, layer in ipairs(layers) do
    if i > maxLayer then break end
    if opts then applyOverrides(layer, opts) end
    layer.ps:setPosition(x, y)
    layer.ps:emit(math.max(1, math.floor(count * layer.countMult)))
    if opts then restoreDefaults(layer) end
  end
end

-- Like emit but fires in a specific direction.
-- speedOverride: screen px/s (same units as token vx/vy); overrides opts.speed and preset speed.
-- opts: same as emit.
function particles.emitDir(name, x, y, count, angle, spread, speedOverride, opts)
  local layers = _presets[name]
  if not layers then return end
  local maxLayer = (opts and type(opts.layers) == "number") and opts.layers or #layers
  for i, layer in ipairs(layers) do
    if i > maxLayer then break end
    if opts then applyOverrides(layer, opts) end
    if speedOverride then
      layer.ps:setSpeed(speedOverride * 0.6, speedOverride * 1.6)
    end
    layer.ps:setPosition(x, y)
    layer.ps:setDirection(angle)
    layer.ps:setSpread(spread)
    layer.ps:emit(math.max(1, math.floor(count * layer.countMult)))
    layer.ps:setDirection(0)
    layer.ps:setSpread(2 * math.pi)
    restoreDefaults(layer)
  end
end

function particles.update(dt)
  for _, layers in pairs(_presets) do
    for _, layer in ipairs(layers) do
      layer.ps:update(dt)
    end
  end
end

function particles.draw()
  love.graphics.setColor(1, 1, 1, 1)
  for _, layers in pairs(_presets) do
    for _, layer in ipairs(layers) do
      love.graphics.draw(layer.ps, 0, 0)
    end
  end
end

return particles
