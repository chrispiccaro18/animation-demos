local AssetManifest = require("assets.manifest")
local animation     = require("lib.animation")
local Glow          = require("lib.glow.Glow")
local Palette       = require("lib.palette")

local ProgressBar = {}

local _count    = 0
local _max      = 10
local _popScale = 1.0

local _x, _y, _w, _h, _gapX
local _textArea = {}
local _asset, _activeIndAsset, _inactiveIndAsset
local _font

function ProgressBar.load()
  _x    = 873 * SCALE_X
  _y    = 73  * SCALE_Y
  _w    = 38  * SCALE_X
  _h    = 138 * SCALE_Y
  _gapX = 64  * SCALE_X

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

function ProgressBar.draw()
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
      glow:request("progress-tick-" .. i, {
        kind  = "image",
        image = _asset,
        x = cx, y = cy,
        sx = SCALE_X * s * 1.2,
        sy = SCALE_Y * s * 1.1,
        ox = aw / 2, oy = ah / 2,
        color = Palette.positive,
        alpha = 0.7,
        light = {
          radius = 100 * SCALE_X,
          alpha = 0.15,
        },
      })
    end
  end

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
