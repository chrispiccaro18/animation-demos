local Button   = require("core.button")
local Palette  = require("lib.palette")
local Manifest = require("assets.manifest")

local menuScreen = {}

local _active   = false
local _buttons  = {}
local _onContinue = nil
local _onNewRun   = nil
local _onSandbox  = nil
local _onOptions  = nil
local _onQuit     = nil

local BW  = 700
local BH  = 130
local GAP = 40
local CX  = 1920
local CY  = 1080

local function makeButtons(hasSave)
  local items = {}
  if hasSave then
    items[#items + 1] = { label = "Continue", fn = _onContinue }
  end
  items[#items + 1] = { label = "New Run",  fn = _onNewRun  }
  items[#items + 1] = { label = "Sandbox",  fn = _onSandbox }
  items[#items + 1] = { label = "Options",  fn = _onOptions }
  if _onQuit then
    items[#items + 1] = { label = "Quit",   fn = _onQuit   }
  end

  local n      = #items
  local totalH = n * BH + (n - 1) * GAP
  local startY = CY - totalH / 2

  _buttons = {}
  for i, item in ipairs(items) do
    local x = (CX - BW / 2) * SCALE_X
    local y = (startY + (i - 1) * (BH + GAP)) * SCALE_Y
    _buttons[#_buttons + 1] = Button.new(
      x, y, BW * SCALE_X, BH * SCALE_Y,
      item.label, 72, item.fn
    )
  end
end

function menuScreen.load(onContinue, onNewRun, onSandbox, onOptions, onQuit)
  _onContinue = onContinue
  _onNewRun   = onNewRun
  _onSandbox  = onSandbox
  _onOptions  = onOptions
  _onQuit     = onQuit
end

function menuScreen.show()
  local Run = require("core.run")
  makeButtons(Run.hasSave())
  _active = true
end

function menuScreen.hide()
  _active = false
end

function menuScreen.isActive()
  return _active
end

function menuScreen.update(mx, my)
  if not _active then return end
  for _, btn in ipairs(_buttons) do btn:update(mx, my) end
end

function menuScreen.draw()
  if not _active then return end
  local w, h = love.graphics.getDimensions()
  love.graphics.setColor(Palette.void)
  love.graphics.rectangle("fill", 0, 0, w, h)
  love.graphics.setColor(1, 1, 1, 1)
  for _, btn in ipairs(_buttons) do btn:draw() end
end

function menuScreen.mousepressed(x, y, btn)
  if not _active then return false end
  for _, button in ipairs(_buttons) do
    if button:mousepressed(x, y, btn) then return true end
  end
  return false
end

function menuScreen.touchpressed(x, y)
  if not _active then return false end
  for _, button in ipairs(_buttons) do
    if button:touchpressed(x, y) then return true end
  end
  return false
end

return menuScreen
