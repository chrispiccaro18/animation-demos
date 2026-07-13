local AssetManifest = require("assets.manifest")
local Palette  = require("lib.palette")
local animation     = require("lib.animation")
local pulse         = require("lib.pulse")

local ThreatBar = {}

local _count     = 0
local _max       = 10
local _popScale  = 1.0
local _tickPulseCount  = 0
local _negPulseStartT  = nil

function ThreatBar.setTickPulseCount(n)
  if n > 0 and _tickPulseCount == 0 then
    _negPulseStartT = pulse.getTime()
  elseif n == 0 then
    _negPulseStartT = nil
  end
  _tickPulseCount = n
end

local _x, _y, _w, _h, _gapX
local _textArea = {}
local _asset
local _font, _titleFont

function ThreatBar.load()
  _x    = 2378 * SCALE_X
  -- _x    = 2320 * SCALE_X
  _y    = 73   * SCALE_Y
  _w    = 38   * SCALE_X
  _h    = 138  * SCALE_Y
  _gapX = 58   * SCALE_X
  -- _gapX = 64   * SCALE_X

  _textArea = {
    x = 2997 * SCALE_X,
    y = 110  * SCALE_Y,
    w = 291  * SCALE_X,
    h = 66   * SCALE_Y,
  }

  _asset = AssetManifest.get("ticks", "threat")
  _font  = AssetManifest.getFont(72)
  _titleFont = AssetManifest.getFont(38)
end

function ThreatBar.reset()
  _count    = 0
  _popScale = 1.0
end

function ThreatBar.getCount() return _count end
function ThreatBar.getMax()   return _max   end
function ThreatBar.isFull()   return _count >= _max end

-- Set the count directly (used when loading a save), no animation.
function ThreatBar.setCount(n)
  _count    = math.max(0, math.min(n or 0, _max))
  _popScale = 1.0
end

function ThreatBar.increment()
  _count    = math.min(_count + 1, _max)
  _popScale = 1.0 + 0.6 * (_count / _max)
end

function ThreatBar.decrement()
  _count = math.max(_count - 1, 0)
end

function ThreatBar.update(dt)
  _popScale = animation.expDecay(_popScale, 1.0, 10, dt)
end

function ThreatBar.getGhostTickPositions(count)
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

function ThreatBar.getTickData()
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

function ThreatBar.draw(alphaMul)
  alphaMul = alphaMul or 1
  if not _asset then return end
  local pulseA = pulse.valueFrom(2.0, 0.0, 0.8, _negPulseStartT)
  local aw = _w / SCALE_X
  local ah = _h / SCALE_Y
  for i = 0, _count - 1 do
    local s          = (i == _count - 1) and _popScale or 1.0
    local cx         = _x + i * _gapX + _w / 2
    local cy         = _y + _h / 2
    local isAffected = _tickPulseCount > 0 and i >= _count - _tickPulseCount
    love.graphics.setColor(1, 1, 1, (isAffected and pulseA or 1.0) * alphaMul)
    love.graphics.draw(_asset, cx, cy, 0, SCALE_X * s, SCALE_Y * s, aw / 2, ah / 2)
  end
  love.graphics.setColor(1, 1, 1, 1)

  if _font and _titleFont then
    love.graphics.setColor(1, 1, 1, alphaMul)
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(_font)
    love.graphics.printf(
      string.format("%02d/%02d", _count, _max),
      _textArea.x, _textArea.y, _textArea.w, "left"
    )
    love.graphics.setFont(_titleFont)
    local dc = Palette.danger
    love.graphics.setColor(dc[1], dc[2], dc[3], (dc[4] or 1) * alphaMul)
    love.graphics.printf(
      "THREAT LEVEL",
      _textArea.x,
      _textArea.y - 36 * SCALE_Y,
      _textArea.w * 2,
      "left"
    )
    love.graphics.setFont(prevFont)
    love.graphics.setColor(1, 1, 1, 1)
  end
end

return ThreatBar
