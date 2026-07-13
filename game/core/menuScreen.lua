local Button    = require("core.button")
local Palette   = require("lib.palette")
local Manifest  = require("assets.manifest")
local animation = require("lib.animation")

local menuScreen = {}

local _active   = false
local _buttons  = {}
local _onContinue = nil
local _onNewRun   = nil
local _onOptions  = nil
local _onQuit     = nil

local BW  = 700
local BH  = 130
local GAP = 40
local CX  = 1920
local CY  = 1080

local TOGGLE_SIZE     = 160
local TOGGLE_MARGIN   = 40
local TOGGLE_BREATHING_ROOM_X = 40
local TOGGLE_BREATHING_ROOM_Y = 180
local MINIMIZE_RATE   = 12
local HIT_TEST_T_MAX  = 0.5  -- buttons stop accepting input once more than half-minimized

local _minimized = false
local _t         = 0  -- 0 = fully expanded, 1 = fully minimized
local _toggle    = nil
local _toggleFirstLayout = true

local function toggleCenter()
  local tx = (3840 - TOGGLE_MARGIN - TOGGLE_SIZE) * SCALE_X
  local ty = TOGGLE_MARGIN * SCALE_Y
  local ts = TOGGLE_SIZE * SCALE_X
  return tx, ty, ts
end

local function newToggleButton()
  local tx, ty, ts = toggleCenter()
  return {
    x = tx, y = ty, w = ts, h = ts,
    expandedX  = tx, expandedY  = ty,
    minimizedX = tx, minimizedY = ty,
    hovered = false,
    update = function(self, mx, my)
      self.hovered = mx >= self.x and mx <= self.x + self.w
                 and my >= self.y and my <= self.y + self.h
    end,
    draw = function(self)
      local icon = _minimized and Manifest.get("ui", "arrowDownLeft")
                               or  Manifest.get("ui", "arrowUpRight")
      local col = self.hovered and Palette.accent or Palette.primary
      local alpha = self.hovered and 0.2 or 0
      love.graphics.setColor(col[1], col[2], col[3], alpha)
      love.graphics.rectangle("fill", self.x, self.y, self.w, self.h, 12 * SCALE_X, 12 * SCALE_Y)
      love.graphics.setColor(1, 1, 1, 1)
      local iw, ih = icon:getDimensions()
      local s = math.min(self.w * 0.6 / iw, self.h * 0.6 / ih)
      love.graphics.draw(icon, self.x + self.w / 2, self.y + self.h / 2, 0, s, s, iw / 2, ih / 2)
    end,
    mousepressed = function(self, px, py, btn)
      if btn == 1 and px >= self.x and px <= self.x + self.w and py >= self.y and py <= self.y + self.h then
        _minimized = not _minimized
        return true
      end
      return false
    end,
    touchpressed = function(self, px, py)
      if px >= self.x and px <= self.x + self.w and py >= self.y and py <= self.y + self.h then
        _minimized = not _minimized
        return true
      end
      return false
    end,
  }
end

local function makeButtons(hasSave)
  local items = {}
  if hasSave then
    items[#items + 1] = { label = "Continue", fn = _onContinue }
  end
  items[#items + 1] = { label = "New Run",  fn = _onNewRun  }
  items[#items + 1] = { label = "Options",  fn = _onOptions }
  if _onQuit then
    items[#items + 1] = { label = "Quit",   fn = _onQuit   }
  end

  local n      = #items
  local totalH = n * BH + (n - 1) * GAP
  local startY = CY - totalH / 2

  local tx, ty, ts = toggleCenter()

  _buttons = {}
  for i, item in ipairs(items) do
    local x = (CX - BW / 2) * SCALE_X
    local y = (startY + (i - 1) * (BH + GAP)) * SCALE_Y
    local w = BW * SCALE_X
    local h = BH * SCALE_Y
    local btn = Button.new(x, y, w, h, item.label, 72, item.fn)
    btn.expandedX  = x
    btn.expandedY  = y
    btn.minimizedX = tx + ts / 2 - w / 2
    btn.minimizedY = ty + ts / 2 - h / 2
    _buttons[#_buttons + 1] = btn
  end

  -- Toggle starts at the top-right of the button stack (with breathing room)
  -- and tweens, alongside the buttons, to the canvas corner when minimized.
  if _toggle then
    _toggle.expandedX = (CX + BW / 2 + TOGGLE_BREATHING_ROOM_X) * SCALE_X
    _toggle.expandedY = (startY - TOGGLE_BREATHING_ROOM_Y) * SCALE_Y
    _toggle.minimizedX = tx
    _toggle.minimizedY = ty

    -- First-ever layout: snap straight to the correct spot instead of
    -- tweening in from the toggleCenter() placeholder set in load().
    if _toggleFirstLayout then
      _toggle.x = _minimized and _toggle.minimizedX or _toggle.expandedX
      _toggle.y = _minimized and _toggle.minimizedY or _toggle.expandedY
      _toggleFirstLayout = false
    end
  end
end

function menuScreen.load(onContinue, onNewRun, onOptions, onQuit)
  _onContinue = onContinue
  _onNewRun   = onNewRun
  _onOptions  = onOptions
  _onQuit     = onQuit
  _toggle     = newToggleButton()
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

-- Called externally (sandbox, on first token fling) to auto-minimize the
-- button stack. Idempotent; manual restore is via the toggle arrow only.
function menuScreen.minimize()
  _minimized = true
end

function menuScreen.isMinimized()
  return _minimized
end

function menuScreen.update(mx, my)
  if not _active then return end

  local targetT = _minimized and 1 or 0
  _t = animation.expDecay(_t, targetT, MINIMIZE_RATE, realDt or 0)
  if math.abs(_t - targetT) < 0.001 then _t = targetT end

  for _, btn in ipairs(_buttons) do
    btn.x = animation.lerp(btn.expandedX, btn.minimizedX, _t)
    btn.y = animation.lerp(btn.expandedY, btn.minimizedY, _t)
    if _t < HIT_TEST_T_MAX then
      btn:update(mx, my)
    else
      btn.hovered = false
    end
  end

  local toggleTargetX = _minimized and _toggle.minimizedX or _toggle.expandedX
  local toggleTargetY = _minimized and _toggle.minimizedY or _toggle.expandedY
  _toggle.x = animation.expDecay(_toggle.x, toggleTargetX, MINIMIZE_RATE, realDt or 0)
  _toggle.y = animation.expDecay(_toggle.y, toggleTargetY, MINIMIZE_RATE, realDt or 0)
  _toggle:update(mx, my)
end

function menuScreen.draw()
  if not _active then return end

  local alphaMul = 1 - _t
  if alphaMul > 0.01 then
    for _, btn in ipairs(_buttons) do btn:draw(alphaMul) end
  end
  _toggle:draw()
end

function menuScreen.mousepressed(x, y, btn)
  if not _active then return false end
  if _toggle:mousepressed(x, y, btn) then return true end
  if _t >= HIT_TEST_T_MAX then return false end
  for _, button in ipairs(_buttons) do
    if button:mousepressed(x, y, btn) then return true end
  end
  return false
end

function menuScreen.touchpressed(x, y)
  if not _active then return false end
  if _toggle:touchpressed(x, y) then return true end
  if _t >= HIT_TEST_T_MAX then return false end
  for _, button in ipairs(_buttons) do
    if button:touchpressed(x, y) then return true end
  end
  return false
end

return menuScreen
