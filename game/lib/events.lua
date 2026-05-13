---@class Event
---@field fn function Called when the event fires
---@field blocking boolean If true, halts the queue until this event is fully done
---@field blockable boolean If false, fires immediately on push, bypassing the queue
---@field delay number Seconds of delay
---@field type "immediate"|"before"|"after" When the delay happens relative to fn
---@field persistent boolean If true, events.clear() cannot cancel this event
---@field realTime boolean? If true, timer uses realDt instead of gameDt (default: false)

---@class EventsModule
---@field _queue Event[] Pending events waiting their turn
---@field _active Event|nil The currently running blocking event
---@field _background table[] Non-blocking or immediate-fire events still counting their timers
local events = {}

-- Private state
local _queue = {}
local _active = nil
local _background = {}

---Processes a single non-queued event (blockable=false or non-blocking from queue head).
---For "immediate" type, fn is called right away and the event is done.
---For "before"/"after" types, the event is added to _background to be ticked.
---@param event Event
local function processAsync(event)
  if event.type == "immediate" then
    event.fn()
  else
    _background[#_background + 1] = {
      event = event,
      timer = event.delay or 0,
      phase = event.type == "before" and "wait" or "fn_done",
      fnCalled = event.type == "after",
    }
    if event.type == "after" then
      event.fn()
    end
  end
end

---Starts a blocking event as the active event.
---@param event Event
local function startActive(event)
  if event.type == "immediate" then
    event.fn()
    _active = nil
  elseif event.type == "before" then
    _active = { event = event, timer = event.delay or 0, phase = "before_wait" }
  elseif event.type == "after" then
    event.fn()
    _active = { event = event, timer = event.delay or 0, phase = "after_wait" }
  elseif event.type == "poll" then
    _active = { event = event, phase = "poll" }
  end
end

---Drains leading non-blocking events from the queue and starts the next blocking one.
local function advanceQueue()
  while #_queue > 0 do
    local head = _queue[1]
    if not head.blocking then
      table.remove(_queue, 1)
      processAsync(head)
    else
      table.remove(_queue, 1)
      startActive(head)
      break
    end
  end
end

-- Public API

---Resets all event state. Call once from love.load().
function events.load()
  _queue = {}
  _active = nil
  _background = {}
end

---Pushes an event onto the queue, or fires it immediately if blockable=false.
---@param event Event
function events.push(event)
  if event.blockable == false then
    processAsync(event)
  else
    _queue[#_queue + 1] = event
  end
end

---Updates the event system each frame. Call from love.update() before overlayStats.
---Reads globals realDt and gameDt; each event's realTime field selects which timer to use.
function events.update()
  -- Tick background (non-blocking / immediate-fire) events
  local i = 1
  while i <= #_background do
    local entry = _background[i]
    local dt = entry.event.realTime and realDt or gameDt
    local done = false

    if entry.phase == "wait" then
      entry.timer = entry.timer - dt
      if entry.timer <= 0 then
        entry.event.fn()
        done = true
      end
    elseif entry.phase == "fn_done" then
      entry.timer = entry.timer - dt
      if entry.timer <= 0 then
        done = true
      end
    end

    if done then
      table.remove(_background, i)
    else
      i = i + 1
    end
  end

  -- Tick active blocking event
  if _active then
    local dt = _active.event.realTime and realDt or gameDt
    if _active.phase == "before_wait" then
      _active.timer = _active.timer - dt
      if _active.timer <= 0 then
        _active.event.fn()
        _active = nil
      end
    elseif _active.phase == "after_wait" then
      _active.timer = _active.timer - dt
      if _active.timer <= 0 then
        _active = nil
      end
    elseif _active.phase == "poll" then
      if _active.event.fn() then
        _active = nil
      end
    end
  end

  -- Advance queue if nothing is blocking
  if not _active and #_queue > 0 then
    advanceQueue()
  end
end

---Cancels all non-persistent events in the queue, background, and active slot.
function events.clear()
  local filtered = {}
  for _, event in ipairs(_queue) do
    if event.persistent then
      filtered[#filtered + 1] = event
    end
  end
  _queue = filtered

  local filteredBg = {}
  for _, entry in ipairs(_background) do
    if entry.event.persistent then
      filteredBg[#filteredBg + 1] = entry
    end
  end
  _background = filteredBg

  if _active and not _active.event.persistent then
    _active = nil
  end
end

return events
