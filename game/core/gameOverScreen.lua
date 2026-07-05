local Button = require("core.button")

local M = {}

local DELAY          = 1.0
local BTN_W          = 560
local BTN_H          = 180
local BTN_GAP        = 80
local FONT_SIZE      = 72
local BELOW_CENTER_Y = 400   -- design units below canvas center

local FEEDBACK_URL = "https://forms.gle/sjbzYgS94u2w27iq5"

local _timer        = nil
local _ready        = false
local _prevGameOver = false
local _onReset      = nil
local _btn1         = nil
local _btn2         = nil

function M.load(onReset)
  _onReset = onReset
  local cw  = SCALE_X * 3840
  local ch  = SCALE_Y * 2160
  local bw  = BTN_W * SCALE_X
  local bh  = BTN_H * SCALE_Y
  local gap = BTN_GAP * SCALE_X
  local bx1 = (cw - (bw * 2 + gap)) / 2
  local bx2 = bx1 + bw + gap
  local by  = ch / 2 + BELOW_CENTER_Y * SCALE_Y
  _btn1 = Button.new(bx1, by, bw, bh, "RESET",    FONT_SIZE, function()
    if _onReset then _onReset() end
  end)
  _btn2 = Button.new(bx2, by, bw, bh, "FEEDBACK", FONT_SIZE, function()
    love.system.openURL(FEEDBACK_URL)
  end)
end

function M.reset()
  _timer        = nil
  _ready        = false
  _prevGameOver = false
end

function M.update(dt, mx, my)
  if gameOver == "loss" and not _prevGameOver then
    _prevGameOver = true
    _timer        = 0
    _ready        = false
  end
  if _timer then
    _timer = _timer + dt
    if _timer >= DELAY then
      _ready = true
      _timer = nil
    end
  end
  if _ready then
    _btn1:update(mx, my)
    _btn2:update(mx, my)
  end
end

function M.draw()
  if not _ready then return end
  _btn1:draw()
  _btn2:draw()
end

function M.mousepressed(mx, my, btn)
  if not _ready then return false end
  return _btn1:mousepressed(mx, my, btn) or _btn2:mousepressed(mx, my, btn)
end

function M.touchpressed(tx, ty)
  if not _ready then return false end
  return _btn1:touchpressed(tx, ty) or _btn2:touchpressed(tx, ty)
end

return M
