local events = require("lib.events")

local ActionQueue = {}

local _active   = nil
local _queue    = {}
local _terminal = false

local function underlyingDone()
  return not events.get("default").isRunning()
     and not events.get("terminalArrive").isRunning()
end

local function rejectAll(first)
  if first.onReject then first.onReject(first) end
  for _, item in ipairs(_queue) do
    if item.onReject then item.onReject(item) end
  end
  _queue    = {}
  _terminal = false
end

-- bypassTerminal: lets an item queue even while an end-turn action is
-- terminal (e.g. a card action queuing behind beginTurn's still-resolving
-- escalation/drawToDtor ceremony once dealing itself has finished — see
-- newHand.lua, gated there on areas.endTurn.frozen). Only card actions set
-- this; the end-turn push itself never does, so a second End Turn press
-- while one is already resolving still gets rejected as before.
function ActionQueue.push(item)
  if _terminal and not item.bypassTerminal then return false end
  _queue[#_queue + 1] = item
  if item.terminal then _terminal = true end
  return true
end

function ActionQueue.isRunning()
  return _active ~= nil or #_queue > 0
end

function ActionQueue.isTerminal()
  return _terminal
end

function ActionQueue.activeCard()
  return _active and _active.card or nil
end

function ActionQueue.pendingCards()
  local cards = {}
  for _, item in ipairs(_queue) do
    if item.card then cards[#cards + 1] = item.card end
  end
  return cards
end

function ActionQueue.update()
  if _active and underlyingDone() then
    _active = nil
  end

  if not _active and #_queue > 0 then
    local item   = _queue[1]
    local result = item.check and item.check() or "ok"

    if result == "ok" then
      table.remove(_queue, 1)
      _active = item
      item.fn()
    elseif result == "reject" then
      table.remove(_queue, 1)
      if item.onReject then item.onReject(item) end
    elseif result == "rejectAll" then
      table.remove(_queue, 1)
      rejectAll(item)
    end
  end

  if not _active and #_queue == 0 then
    _terminal = false
  end
end

function ActionQueue.reset()
  _active   = nil
  _queue    = {}
  _terminal = false
end

events.registerRunning(function() return ActionQueue.isRunning() end)

return ActionQueue
