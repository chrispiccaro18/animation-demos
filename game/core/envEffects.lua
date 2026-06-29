local AssetManifest = require("assets.manifest")
local Palette       = require("lib.palette")

local EnvEffects = {}

local _positive, _positiveInactive, _negative
local _gapY, _startY, _xOffset, _gap
local _leftLine
local _effects = {}

local ANIM_PEAK = 1.5
local ANIM_IN   = 0.2
local ANIM_OUT  = 0.2

local _anims = {
  negative = { t = 0, active = false, done = false, scale = 1 },
  [1]      = { t = 0, active = false, done = false, scale = 1 },
  [2]      = { t = 0, active = false, done = false, scale = 1 },
}

local THRESH_PEAK = 1.9
local THRESH_IN   = 0.25
local THRESH_OUT  = 0.55

local _thresholdAnims = {
  [1] = { t = 0, active = false, done = false, scale = 1, gained = true },
  [2] = { t = 0, active = false, done = false, scale = 1, gained = true },
}

local _wasActive = { [1] = false, [2] = false }

local function lineXAtY(line, y)
  local t = (y - line.y1) / (line.y2 - line.y1)
  t = math.max(0, math.min(1, t))
  return line.x1 + t * (line.x2 - line.x1)
end

local function smoothstep(p)
  return p * p * (3 - 2 * p)
end

function EnvEffects.load(leftLine)
  _leftLine         = leftLine
  _positive         = AssetManifest.get("envEffects", "positive")
  _positiveInactive = AssetManifest.get("envEffects", "positiveInactive")
  _negative         = AssetManifest.get("envEffects", "negative")
  _gapY    = 25  * SCALE_Y
  _startY  = 408 * SCALE_Y
  _xOffset = -25 * SCALE_X
  _gap     = _gapY + (_negative:getHeight() * SCALE_Y)
end

-- Returns the world-space x, y of an env effect icon.
-- index: "negative" | 1 | 2
function EnvEffects.getPosition(index)
  local y
  if     index == "negative" then y = _startY
  elseif index == 1          then y = _startY + _gap
  elseif index == 2          then y = _startY + _gap * 2
  end
  return lineXAtY(_leftLine, y) + _xOffset, y
end

-- Register a conditional effect at `index`.
-- isActive(index) returns true when sourceFn() >= threshold.
function EnvEffects.register(index, threshold, sourceFn)
  _effects[index] = { threshold = threshold, source = sourceFn }
end

function EnvEffects.isActive(index)
  if index == "negative" then return true end
  local e = _effects[index]
  if not e then return false end
  return e.source() >= e.threshold
end

function EnvEffects.triggerAnim(index)
  local a = _anims[index]
  if not a then return end
  a.t      = 0
  a.active = true
  a.done   = false
  a.scale  = 1
end

function EnvEffects.animDone(index)
  local a = _anims[index]
  return a and a.done
end

-- Sync _wasActive to current state without firing transitions (call after reset).
function EnvEffects.syncState()
  for _, i in ipairs({ 1, 2 }) do
    _wasActive[i] = EnvEffects.isActive(i)
  end
end

-- Returns a list of {index, gained} for effects whose active state changed since last call.
-- Call this after modifying progress/threat counts.
function EnvEffects.checkTransitions()
  local changes = {}
  for _, i in ipairs({ 1, 2 }) do
    local now = EnvEffects.isActive(i)
    if now ~= _wasActive[i] then
      table.insert(changes, { index = i, gained = now })
      _wasActive[i] = now
    end
  end
  return changes
end

function EnvEffects.triggerThresholdAnim(index, gained)
  local a = _thresholdAnims[index]
  if not a then return end
  a.t      = 0
  a.active = true
  a.done   = false
  a.scale  = 1
  a.gained = gained
end

function EnvEffects.thresholdAnimDone(index)
  local a = _thresholdAnims[index]
  return a and a.done
end

function EnvEffects.update(dt)
  local total = ANIM_IN + ANIM_OUT
  for _, a in pairs(_anims) do
    if a.active then
      a.t = a.t + dt
      if a.t >= total then
        a.scale  = 1.0
        a.active = false
        a.done   = true
      elseif a.t <= ANIM_IN then
        a.scale = 1.0 + (ANIM_PEAK - 1.0) * smoothstep(a.t / ANIM_IN)
      else
        a.scale = ANIM_PEAK + (1.0 - ANIM_PEAK) * smoothstep((a.t - ANIM_IN) / ANIM_OUT)
      end
    end
  end

  local tTotal = THRESH_IN + THRESH_OUT
  for _, a in pairs(_thresholdAnims) do
    if a.active then
      a.t = a.t + dt
      if a.t >= tTotal then
        a.scale  = 1.0
        a.active = false
        a.done   = true
      elseif a.t <= THRESH_IN then
        a.scale = 1.0 + (THRESH_PEAK - 1.0) * smoothstep(a.t / THRESH_IN)
      else
        a.scale = THRESH_PEAK + (1.0 - THRESH_PEAK) * smoothstep((a.t - THRESH_IN) / THRESH_OUT)
      end
    end
  end
end

local function drawIcon(img, x, y, scale, glowColor, isActive)
  local iw = img:getWidth()
  local ih = img:getHeight()
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(img, x, y, 0, SCALE_X * scale, SCALE_Y * scale, iw / 2, ih / 2)
end

-- Returns per-icon glow data for all env effect icons.
-- animAlpha is pre-computed so callers don't need to know ANIM_PEAK.
function EnvEffects.getIconGlowData()
  if not (_positive and _positiveInactive and _negative) then return {} end
  local defs = {
    { index = "negative", img = _negative,                                                 glowColor = Palette.danger   },
    { index = 1,          img = EnvEffects.isActive(1) and _positive or _positiveInactive, glowColor = Palette.positive },
    { index = 2,          img = EnvEffects.isActive(2) and _positive or _positiveInactive, glowColor = Palette.positive },
  }
  local result = {}
  for _, def in ipairs(defs) do
    local x, y      = EnvEffects.getPosition(def.index)
    local animScale  = _anims[def.index].scale
    local threshAnim = _thresholdAnims[def.index]
    local scale      = threshAnim and math.max(animScale, threshAnim.scale) or animScale
    local isAnim     = scale > 1.0
    result[#result + 1] = {
      img       = def.img,
      x         = x,
      y         = y,
      scale     = scale,
      glowColor = def.glowColor,
      isActive  = EnvEffects.isActive(def.index),
      isAnim    = isAnim,
      animAlpha = isAnim and math.min(1.0, (scale - 1.0) / (ANIM_PEAK - 1.0)) or 0,
    }
  end
  return result
end

function EnvEffects.draw()
  if not (_positive and _positiveInactive and _negative) then return end

  local items = {
    { index = "negative", img = _negative,                                                 glowColor = Palette.danger   },
    { index = 1,          img = EnvEffects.isActive(1) and _positive or _positiveInactive, glowColor = Palette.positive },
    { index = 2,          img = EnvEffects.isActive(2) and _positive or _positiveInactive, glowColor = Palette.positive },
  }

  table.sort(items, function(a, b)
    return (not _anims[a.index].active) and _anims[b.index].active
  end)

  for _, item in ipairs(items) do
    local x, y        = EnvEffects.getPosition(item.index)
    local animScale   = _anims[item.index].scale
    local threshAnim  = _thresholdAnims[item.index]
    local scale       = threshAnim and math.max(animScale, threshAnim.scale) or animScale
    local isActive    = EnvEffects.isActive(item.index)
    drawIcon(item.img, x, y, scale, item.glowColor, isActive)
  end

  love.graphics.setColor(1, 1, 1, 1)
end

return EnvEffects
