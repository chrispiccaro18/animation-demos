-- Touch equivalents of the keyboard speed controls (TAB cycle / hold SPACE
-- for a boost), with no visible on-screen buttons:
--   * Two-finger double-tap: cycles speed. Left half of the screen steps
--     down a preset, right half steps up.
--   * Single-finger tap, release, then tap-and-hold (on the right half,
--     away from cards): boosts speed for as long as the second tap is held.
local speedGestures = {}

local DOUBLE_TAP_WINDOW = 0.4  -- seconds allowed between the two taps of a "double tap"

local _onCycle     = nil  -- function(direction)  -- -1 (left/down) or 1 (right/up)
local _onHoldStart = nil  -- function()
local _onHoldEnd   = nil  -- function()
local _isDeadZone  = nil  -- function(gx, gy) -> boolean (true if safe, i.e. not over a card)

local _pendingTwoFingerTap = nil  -- { time, side }
local _pendingSingleTap    = nil  -- { time, side }
local _holdTouchId         = nil

function speedGestures.load(callbacks)
  _onCycle     = callbacks.onCycle
  _onHoldStart = callbacks.onHoldStart
  _onHoldEnd   = callbacks.onHoldEnd
  _isDeadZone  = callbacks.isDeadZone
end

local function sideOf(x)
  return (x < love.graphics.getWidth() / 2) and "left" or "right"
end

local function deadZoneOk(gx, gy)
  return not _isDeadZone or _isDeadZone(gx, gy)
end

-- Call when an N-finger tap-and-release completes (from the host's existing
-- tap-vs-hold detection). x = the released touch's raw screen x;
-- gx,gy = its position in canvas/design space (for the dead-zone check).
function speedGestures.onTap(arity, x, gx, gy)
  local now = love.timer.getTime()

  if arity == 2 then
    local side = sideOf(x)
    if _pendingTwoFingerTap
       and _pendingTwoFingerTap.side == side
       and (now - _pendingTwoFingerTap.time) <= DOUBLE_TAP_WINDOW then
      _pendingTwoFingerTap = nil
      if _onCycle then _onCycle(side == "left" and -1 or 1) end
    else
      _pendingTwoFingerTap = { time = now, side = side }
    end

  elseif arity == 1 then
    local side = sideOf(x)
    if side == "right" and deadZoneOk(gx, gy) then
      _pendingSingleTap = { time = now, side = side }
    else
      _pendingSingleTap = nil
    end
  end
end

-- Call from the host's touchpressed for every new touch.
function speedGestures.onTouchDown(id, x, y, gx, gy)
  if _holdTouchId or not _pendingSingleTap then return end

  local now = love.timer.getTime()
  if (now - _pendingSingleTap.time) > DOUBLE_TAP_WINDOW then
    _pendingSingleTap = nil
    return
  end

  if sideOf(x) == "right" and deadZoneOk(gx, gy) then
    _holdTouchId = id
    _pendingSingleTap = nil
    if _onHoldStart then _onHoldStart() end
  end
end

-- Call from the host's touchreleased for every lifted touch.
function speedGestures.onTouchUp(id)
  if _holdTouchId == id then
    _holdTouchId = nil
    if _onHoldEnd then _onHoldEnd() end
  end
end

return speedGestures
