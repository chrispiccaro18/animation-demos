-- Consolidates speed-control state (persistence, the fade/hold toast, and
-- the touch gestures) behind one module so main.lua only needs a single
-- upvalue for all of it instead of several (main.lua's love.load already
-- sits near Lua's 60-upvalue-per-function ceiling).
local config        = require("lib.config")
local Settings      = require("lib.settings")
local speedToast    = require("core.speedToast")
local speedGestures = require("lib.speedGestures")

local speedManager = {}

-- Temporary speed boost (SPACE key and/or the touch hold gesture). Reference-
-- counted so overlapping boost sources don't clobber each other's restore value.
local _boostSources  = 0
local _preBoostSpeed = nil
local _hand          = nil

local function startBoost()
  if _boostSources == 0 then
    _preBoostSpeed = config.speed
    config.speed   = 3.0
    speedToast.showHeld("3x")
  end
  _boostSources = _boostSources + 1
end

local function endBoost()
  _boostSources = math.max(0, _boostSources - 1)
  if _boostSources == 0 then
    config.speed = _preBoostSpeed or config.speed
    speedToast.hide()
  end
end

local function stepSpeed(direction)
  local newIndex = math.max(1, math.min(#config.speedPresets, config.speedIndex + direction))
  if newIndex == config.speedIndex then return end
  config.speedIndex = newIndex
  config.speed      = config.speedPresets[newIndex]
  Settings.save({ speedIndex = newIndex })
  speedToast.showTimed(config.speed .. "x")
end

-- Dead zone for the touch speed gestures: true when NOT over a hand card.
local function isDeadZone(gx, gy)
  if not _hand then return true end
  for _, card in ipairs(_hand.cards) do
    if not card._excluded and card:containsPoint(gx, gy) then
      return false
    end
  end
  return true
end

function speedManager.load(hand)
  _hand = hand
  speedToast.load()
  speedGestures.load({
    onCycle     = stepSpeed,
    onHoldStart = startBoost,
    onHoldEnd   = endBoost,
    isDeadZone  = isDeadZone,
  })
end

-- TAB: existing wrap-around cycle, now persisted + toasted.
function speedManager.cycleSpeed()
  config.cycleSpeed()
  Settings.save({ speedIndex = config.speedIndex })
  speedToast.showTimed(config.speed .. "x")
end

function speedManager.keyboardBoostStart() startBoost() end
function speedManager.keyboardBoostEnd()   endBoost()   end

function speedManager.update(dt) speedToast.update(dt) end
function speedManager.draw()     speedToast.draw()     end

function speedManager.touchDown(id, x, y, gx, gy) speedGestures.onTouchDown(id, x, y, gx, gy) end
function speedManager.touchUp(id)                 speedGestures.onTouchUp(id)                end
function speedManager.onTap(arity, x, gx, gy)     speedGestures.onTap(arity, x, gx, gy)       end

return speedManager
