local AssetManifest = require("assets.manifest")
local Glow          = require("lib.glow.Glow")
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
end

local function drawIcon(img, x, y, scale, glowColor)
  local iw = img:getWidth()
  local ih = img:getHeight()
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(img, x, y, 0, SCALE_X * scale, SCALE_Y * scale, iw / 2, ih / 2)

  local glow = Glow.get()
  if glow and scale > 1.0 then
    local alpha = (scale - 1.0) / (ANIM_PEAK - 1.0)
    glow:request("env-anim-" .. tostring(img), {
      kind  = "image",
      image = img,
      x = x, y = y,
      sx = SCALE_X * scale,
      sy = SCALE_Y * scale,
      ox = iw / 2, oy = ih / 2,
      color = glowColor,
      alpha = alpha * 1.0,
    })
  end
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
    local x, y = EnvEffects.getPosition(item.index)
    drawIcon(item.img, x, y, _anims[item.index].scale, item.glowColor)
  end

  love.graphics.setColor(1, 1, 1, 1)
end

return EnvEffects
