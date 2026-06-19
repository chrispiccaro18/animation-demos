---@class Event
---@field fn function Called when the event fires
---@field blocking boolean If true, halts the queue until this event is fully done
---@field blockable boolean If false, fires immediately on push, bypassing the queue
---@field delay number Seconds of delay
---@field type "immediate"|"before"|"after" When the delay happens relative to fn
---@field persistent boolean If true, events.clear() cannot cancel this event
---@field realTime boolean? If true, timer uses realDt instead of gameDt (default: false)

---@class Queue
---@field push fun(event: Event)
---@field update fun()
---@field load fun()
---@field clear fun()
---@field isRunning fun(): boolean

---@class EventsModule : Queue
---@field new fun(name: string): Queue
---@field get fun(name: string): Queue|nil
---@field loadAll fun()
---@field updateAll fun()
---@field anyRunning fun(): boolean

local function newQueue()
  local _queue = {}
  local _active = nil
  local _background = {}

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

  local q = {}

  function q.load()
    _queue = {}
    _active = nil
    _background = {}
  end

  ---@param event Event
  function q.push(event)
    if event.blockable == false then
      processAsync(event)
    else
      _queue[#_queue + 1] = event
    end
  end

  function q.update()
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

    if not _active and #_queue > 0 then
      advanceQueue()
    end
  end

  function q.clear()
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

  function q.isRunning()
    return _active ~= nil or #_queue > 0
  end

  return q
end

local _default = newQueue()
local _terminalArrive = newQueue()
local _queues = {
  default = _default,
  terminalArrive = _terminalArrive,
}

local manager = {}

---@param event Event
---@param queueName string?
function manager.push(event, queueName)
  local q = queueName and _queues[queueName] or _default
  assert(q, "queue '" .. tostring(queueName) .. "' does not exist")
  q.push(event)
end

function manager.new(name)
  assert(type(name) == "string", "queue name must be a string")
  assert(not _queues[name], "queue '" .. name .. "' already exists")
  local q = newQueue()
  _queues[name] = q
  return q
end

function manager.get(name)
  return _queues[name]
end

function manager.loadAll()
  for _, q in pairs(_queues) do
    q.load()
  end
end

function manager.updateAll()
  for _, q in pairs(_queues) do
    q.update()
  end
end

function manager.anyRunning()
  for _, q in pairs(_queues) do
    if q.isRunning() then return true end
  end
  return false
end

function manager.isRunning(queueName)
  local q = queueName and _queues[queueName] or _default
  return q and q.isRunning() or false
end

---@type EventsModule
return setmetatable(manager, {
  __index = function(_, k)
    return _default[k]
  end,
})
