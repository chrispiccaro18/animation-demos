local AssetManifest = require("assets.manifest")
local animation     = require("lib.animation")
local pulse         = require("lib.pulse")

local ProgressBar = {}

local _count     = 0
local _max       = 10
local _popScale  = 1.0
local _tickPulseCount  = 0
local _negPulseStartT  = nil

function ProgressBar.setTickPulseCount(n)
  if n > 0 and _tickPulseCount == 0 then
    _negPulseStartT = pulse.getTime()
  elseif n == 0 then
    _negPulseStartT = nil
  end
  _tickPulseCount = n
end

local _x, _y, _w, _h, _gapX
local _textArea = {}
local _asset, _activeIndAsset, _inactiveIndAsset
local _font

function ProgressBar.load()
  _x    = 873 * SCALE_X
  _y    = 73  * SCALE_Y
  _w    = 38  * SCALE_X
  _h    = 138 * SCALE_Y
  _gapX = 62  * SCALE_X
  -- _gapX = 64  * SCALE_X

  _textArea = {
    x = 522 * SCALE_X,
    y = 120 * SCALE_Y,
    w = 291 * SCALE_X,
    h = 66  * SCALE_Y,
  }

  _asset           = AssetManifest.get("ticks", "progress")
  _activeIndAsset  = AssetManifest.get("envEffects", "indicatorActive")
  _inactiveIndAsset = AssetManifest.get("envEffects", "indicatorInactive")
  _font            = AssetManifest.getFont(72)
end

function ProgressBar.reset()
  _count    = 0
  _popScale = 1.0
end

function ProgressBar.getCount() return _count end
function ProgressBar.getMax()   return _max   end
function ProgressBar.isFull()   return _count >= _max end

function ProgressBar.increment()
  _count    = math.min(_count + 1, _max)
  _popScale = 1.0 + 0.6 * (_count / _max)
end

function ProgressBar.decrement()
  _count = math.max(_count - 1, 0)
end

function ProgressBar.update(dt)
  _popScale = animation.expDecay(_popScale, 1.0, 10, dt)
end

function ProgressBar.getGhostTickPositions(count)
  if not _asset or count <= 0 then return {} end
  local aw     = _w / SCALE_X
  local ah     = _h / SCALE_Y
  local ghosts = {}
  for i = 0, count - 1 do
    local idx = _count + i
    if idx >= _max then break end
    local cx = _x + idx * _gapX + _w / 2
    local cy = _y + _h / 2
    ghosts[#ghosts + 1] = { index = idx, cx = cx, cy = cy, asset = _asset, aw = aw, ah = ah }
  end
  return ghosts
end

function ProgressBar.getTickData()
  if not _asset then return {} end
  local aw    = _w / SCALE_X
  local ah    = _h / SCALE_Y
  local ticks = {}
  for i = 0, _count - 1 do
    local s  = (i == _count - 1) and _popScale or 1.0
    local cx = _x + i * _gapX + _w / 2
    local cy = _y + _h / 2
    ticks[#ticks + 1] = { index = i, cx = cx, cy = cy, s = s, asset = _asset, aw = aw, ah = ah }
  end
  return ticks
end

function ProgressBar.draw()
  if not _asset then return end
  local pulseA = pulse.valueFrom(2.0, 0.0, 0.8, _negPulseStartT)
  local aw = _w / SCALE_X
  local ah = _h / SCALE_Y
  for i = 0, _count - 1 do
    local s           = (i == _count - 1) and _popScale or 1.0
    local cx          = _x + i * _gapX + _w / 2
    local cy          = _y + _h / 2
    local isAffected  = _tickPulseCount > 0 and i >= _count - _tickPulseCount
    love.graphics.setColor(1, 1, 1, isAffected and pulseA or 1.0)
    love.graphics.draw(_asset, cx, cy, 0, SCALE_X * s, SCALE_Y * s, aw / 2, ah / 2)
  end
  love.graphics.setColor(1, 1, 1, 1)

  if _activeIndAsset and _inactiveIndAsset then
    local x1 = _x + 1 * _gapX + _w / 2 - 5 * SCALE_X
    local a1 = _count >= 2 and _activeIndAsset or _inactiveIndAsset
    love.graphics.draw(a1, x1, _y, 0, SCALE_X, SCALE_Y, aw / 2, ah / 2)
    local x2 = _x + 5 * _gapX + _w / 2 - 4 * SCALE_X
    local a2 = _count >= 6 and _activeIndAsset or _inactiveIndAsset
    love.graphics.draw(a2, x2, _y, 0, SCALE_X, SCALE_Y, aw / 2, ah / 2)
  end

  if _font then
    love.graphics.setColor(1, 1, 1, 1)
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(_font)
    love.graphics.printf(
      string.format("%02d/%02d", _count, _max),
      _textArea.x, _textArea.y, _textArea.w, "right"
    )
    love.graphics.setFont(prevFont)
  end
end

return ProgressBar
