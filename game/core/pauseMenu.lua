local Button   = require("core.button")
local Manifest = require("assets.manifest")
local Palette  = require("lib.palette")

-- Mid-game pause overlay opened from hud.lua's "MENU" button. Modeled on
-- core/menuScreen.lua's vertical button stack + core/optionsMenu.lua's dim
-- scrim, without menuScreen's minimize-toggle (not needed here -- this
-- overlay isn't meant to reveal a scene behind it).
local pauseMenu = {}

local _active     = false
local _confirming = false
local _buttons        = {}
local _confirmButtons = {}
local _onResetRun = nil

local BW  = 700
local BH  = 130
local GAP = 40
local CX  = 1920
local CY  = 1080

local CONFIRM_MSG           = "Reset this run? Progress will be lost."
local CONFIRM_MSG_FONT_SIZE = 48
local CONFIRM_MSG_GAP       = 60

local function layoutButtons(items)
  local n      = #items
  local totalH = n * BH + (n - 1) * GAP
  local startY = CY - totalH / 2

  local buttons = {}
  for i, item in ipairs(items) do
    local x = (CX - BW / 2) * SCALE_X
    local y = (startY + (i - 1) * (BH + GAP)) * SCALE_Y
    local w = BW * SCALE_X
    local h = BH * SCALE_Y
    buttons[#buttons + 1] = Button.new(x, y, w, h, item.label, 72, item.fn)
  end
  return buttons
end

function pauseMenu.load(onContinue, onOptions, onMainMenu, onQuit, onResetRun)
  _onResetRun = onResetRun

  local items = {
    { label = "Continue",  fn = onContinue },
    { label = "Options",   fn = onOptions },
    { label = "Main Menu", fn = onMainMenu },
  }
  if onQuit then
    items[#items + 1] = { label = "Quit", fn = onQuit }
  end
  -- Reset Run doesn't fire onResetRun directly -- it flips into a confirm
  -- sub-view first, since it discards the current run's progress.
  items[#items + 1] = { label = "Reset Run", fn = function() _confirming = true end }
  _buttons = layoutButtons(items)

  _confirmButtons = layoutButtons({
    { label = "Yes, Reset", fn = function()
        _confirming = false
        if _onResetRun then _onResetRun() end
      end },
    { label = "Cancel", fn = function() _confirming = false end },
  })
end

function pauseMenu.show()
  _active     = true
  _confirming = false
end

function pauseMenu.hide() _active = false end
function pauseMenu.isActive() return _active end

local function activeButtons()
  return _confirming and _confirmButtons or _buttons
end

function pauseMenu.update(mx, my)
  if not _active then return end
  for _, btn in ipairs(activeButtons()) do btn:update(mx, my) end
end

local function drawConfirmMessage()
  local font = Manifest.getFont(CONFIRM_MSG_FONT_SIZE)
  love.graphics.setFont(font)
  love.graphics.setColor(Palette.default)
  local totalH = #_confirmButtons * BH + (#_confirmButtons - 1) * GAP
  local startY = CY - totalH / 2
  local msgY   = startY - CONFIRM_MSG_GAP - font:getHeight()
  love.graphics.printf(CONFIRM_MSG, (CX - BW) * SCALE_X, msgY * SCALE_Y, BW * 2 * SCALE_X, "center")
end

function pauseMenu.draw()
  if not _active then return end
  love.graphics.setColor(0, 0, 0, 0.75)
  love.graphics.rectangle("fill", 0, 0, 3840 * SCALE_X, 2160 * SCALE_Y)

  if _confirming then drawConfirmMessage() end

  for _, btn in ipairs(activeButtons()) do btn:draw() end
  love.graphics.setColor(1, 1, 1, 1)
end

function pauseMenu.mousepressed(x, y, btn)
  if not _active then return false end
  for _, button in ipairs(activeButtons()) do
    if button:mousepressed(x, y, btn) then return true end
  end
  return true -- consume all clicks when open to prevent click-through
end

function pauseMenu.touchpressed(x, y)
  return pauseMenu.mousepressed(x, y, 1)
end

return pauseMenu
