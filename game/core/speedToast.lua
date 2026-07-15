-- Small transient toast for speed changes (TAB cycle / hold-for-boost),
-- separate from core/message.lua's big centered announcement style.
local Manifest = require("assets.manifest")
local Palette  = require("lib.palette")

local speedToast = {}

local FADE_IN  = 0.15
local HOLD     = 0.6
local FADE_OUT = 0.4

local Y_DESIGN = 220  -- design units from the top

local _text  = ""
local _alpha = 0
local _mode  = "idle"  -- "idle" | "timed" | "held" | "fading_out"
local _timer = 0
local _font  = nil

function speedToast.load()
  _font = Manifest.getFont(120)
end

-- Fades in, holds briefly, fades out automatically.
function speedToast.showTimed(text)
  _text  = text
  _mode  = "timed"
  _timer = 0
end

-- Fades in and stays fully visible until speedToast.hide() is called.
function speedToast.showHeld(text)
  _text  = text
  _mode  = "held"
  _timer = 0
end

-- Ends a "held" toast, fading it out.
function speedToast.hide()
  if _mode == "held" then
    _mode  = "fading_out"
    _timer = 0
  end
end

function speedToast.update(dt)
  if _mode == "idle" then return end
  _timer = _timer + dt

  if _mode == "timed" then
    if _timer < FADE_IN then
      _alpha = _timer / FADE_IN
    elseif _timer < FADE_IN + HOLD then
      _alpha = 1
    elseif _timer < FADE_IN + HOLD + FADE_OUT then
      _alpha = 1 - (_timer - FADE_IN - HOLD) / FADE_OUT
    else
      _mode  = "idle"
      _alpha = 0
    end
  elseif _mode == "held" then
    _alpha = math.min(1, _timer / FADE_IN)
  elseif _mode == "fading_out" then
    _alpha = math.max(0, 1 - _timer / FADE_OUT)
    if _alpha <= 0 then _mode = "idle" end
  end
end

function speedToast.draw()
  if _mode == "idle" or _alpha <= 0 or not _font then return end

  local canvasW = 3840 * SCALE_X
  local prevFont = love.graphics.getFont()
  love.graphics.setFont(_font)

  local tw = _font:getWidth(_text)
  local th = _font:getHeight()
  local x  = (canvasW - tw) / 2
  local y  = Y_DESIGN * SCALE_Y

  local pad = 24 * SCALE_X
  love.graphics.setColor(0, 0, 0, 0.55 * _alpha)
  love.graphics.rectangle("fill", x - pad, y - pad * 0.5, tw + pad * 2, th + pad,
    10 * SCALE_X, 10 * SCALE_Y)

  local c = Palette.accent
  love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * _alpha)
  love.graphics.print(_text, math.floor(x), math.floor(y))

  love.graphics.setFont(prevFont)
  love.graphics.setColor(1, 1, 1, 1)
end

return speedToast
