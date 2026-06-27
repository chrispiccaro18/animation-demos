local AssetManifest = require("assets.manifest")
local animation     = require("lib.animation")
local Glow          = require("lib.glow.Glow")
local Palette       = require("lib.palette")

local ThreatBar = {}

local _count    = 0
local _max      = 10
local _popScale = 1.0

local _x, _y, _w, _h, _gapX
local _textArea = {}
local _asset
local _font

function ThreatBar.load()
  _x    = 2320 * SCALE_X
  _y    = 73   * SCALE_Y
  _w    = 38   * SCALE_X
  _h    = 138  * SCALE_Y
  _gapX = 64   * SCALE_X

  _textArea = {
    x = 2997 * SCALE_X,
    y = 110  * SCALE_Y,
    w = 291  * SCALE_X,
    h = 66   * SCALE_Y,
  }

  _asset = AssetManifest.get("ticks", "threat")
  _font  = AssetManifest.getFont(72)
end

function ThreatBar.reset()
  _count    = 0
  _popScale = 1.0
end

function ThreatBar.getCount() return _count end
function ThreatBar.getMax()   return _max   end
function ThreatBar.isFull()   return _count >= _max end

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

function ThreatBar.draw()
  if not _asset then return end
  love.graphics.setColor(1, 1, 1, 1)
  local aw = _w / SCALE_X
  local ah = _h / SCALE_Y
  local glow = Glow.get()
  for i = 0, _count - 1 do
    local s  = (i == _count - 1) and _popScale or 1.0
    local cx = _x + i * _gapX + _w / 2
    local cy = _y + _h / 2
    love.graphics.draw(_asset, cx, cy, 0, SCALE_X * s, SCALE_Y * s, aw / 2, ah / 2)
    if glow then
      glow:request("threat-tick-" .. i, {
        kind  = "image",
        image = _asset,
        x = cx, y = cy,
        sx = SCALE_X * s, sy = SCALE_Y * s,
        ox = aw / 2, oy = ah / 2,
        color = Palette.danger,
        alpha = 0.7,
      })
    end
  end

  if _font then
    love.graphics.setColor(1, 1, 1, 1)
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(_font)
    love.graphics.printf(
      string.format("%02d/%02d", _count, _max),
      _textArea.x, _textArea.y, _textArea.w, "left"
    )
    love.graphics.setFont(prevFont)
  end
end

return ThreatBar
