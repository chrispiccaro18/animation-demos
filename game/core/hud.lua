local Button = require("core.button")

local M = {}

local BTN_W     = 280
local BTN_H     = 110
local BTN_GAP   = 30
-- local BTN_GAP   = 10
local BTN_PAD   = 44
local FONT_SIZE = 48

local _btnMenu  = nil
local _btnReset = nil
local _btnFeedback = nil

function M.load(onMenu, onReset, onFeedback)
  local cw = SCALE_X * 3860
  local x  = cw - (BTN_W + BTN_PAD) * SCALE_X
  local y1 = 2 * SCALE_Y
  local y2 = y1 + (BTN_H + BTN_GAP) * SCALE_Y
  local y3 = y2 + (BTN_H + BTN_GAP) * SCALE_Y
  _btnMenu  = Button.new(x, y1, BTN_W * SCALE_X, BTN_H * SCALE_Y, "MENU",  FONT_SIZE, onMenu)
  _btnReset = Button.new(x, y2, BTN_W * SCALE_X, BTN_H * SCALE_Y, "RESET", FONT_SIZE, onReset)
  _btnFeedback = Button.new(x, y3, BTN_W * SCALE_X, BTN_H * SCALE_Y, "FEEDBACK", FONT_SIZE, onFeedback)
end

function M.update(mx, my)
  _btnMenu:update(mx, my)
  _btnReset:update(mx, my)
  _btnFeedback:update(mx, my)
end

function M.draw()
  _btnMenu:draw()
  _btnReset:draw()
  _btnFeedback:draw()
end

function M.mousepressed(mx, my, btn)
  return _btnMenu:mousepressed(mx, my, btn) or _btnReset:mousepressed(mx, my, btn) or _btnFeedback:mousepressed(mx, my, btn)
end

function M.touchpressed(tx, ty)
  return _btnMenu:touchpressed(tx, ty) or _btnReset:touchpressed(tx, ty) or _btnFeedback:touchpressed(tx, ty)
end

return M
