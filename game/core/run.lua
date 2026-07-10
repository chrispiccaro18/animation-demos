local Run = {}

local _level         = 0
local _deckData      = {}
local _levelComplete = false
local _savedTurn     = nil

local function prettySerialize(v, indent)
  indent = indent or 0
  local pad  = string.rep("    ", indent)
  local ipad = string.rep("    ", indent + 1)
  local t = type(v)
  if t == "number"  then return tostring(v) end
  if t == "string"  then return string.format("%q", v) end
  if t == "boolean" then return tostring(v) end
  if t ~= "table"   then return "nil" end
  if next(v) == nil then return "{}" end

  -- Pure sequential array (integer keys 1..n, no gaps)?
  local maxN, isArr = 0, true
  for k in pairs(v) do
    if type(k) ~= "number" or k ~= math.floor(k) or k < 1 then
      isArr = false; break
    end
    if k > maxN then maxN = k end
  end
  if isArr then
    local count = 0
    for _ in pairs(v) do count = count + 1 end
    if count ~= maxN then isArr = false end
  end

  if isArr then
    local hasNested = false
    for i = 1, maxN do
      if type(v[i]) == "table" then hasNested = true; break end
    end
    if not hasNested then
      local parts = {}
      for i = 1, maxN do parts[i] = prettySerialize(v[i], 0) end
      return "{ " .. table.concat(parts, ", ") .. " }"
    end
    local lines = {}
    for i = 1, maxN do
      lines[i] = ipad .. prettySerialize(v[i], indent + 1)
    end
    return "{\n" .. table.concat(lines, ",\n") .. ",\n" .. pad .. "}"
  end

  -- Dict-style: sort keys for stable output
  local parts = {}
  for k, val in pairs(v) do
    local key = (type(k) == "string" and k:match("^[%a_][%w_]*$"))
                and k or ("[" .. prettySerialize(k, 0) .. "]")
    parts[#parts + 1] = ipad .. key .. " = " .. prettySerialize(val, indent + 1)
  end
  table.sort(parts)
  return "{\n" .. table.concat(parts, ",\n") .. ",\n" .. pad .. "}"
end

function Run.newRun()
  local CardData = require("data.cards")
  _level         = 0
  _levelComplete = false
  _deckData      = {}
  for _, cd in ipairs(CardData.runStartingDeck) do
    _deckData[#_deckData + 1] = cd
  end
end

function Run.getLevel()             return _level             end
function Run.getCurrentDeckData()   return _deckData          end
function Run.isLevelComplete()      return _levelComplete     end
function Run.clearLevelComplete()   _levelComplete = false    end

function Run.levelComplete()
  _levelComplete = true
end

function Run.addCard(cardData)
  _deckData[#_deckData + 1] = cardData
end

function Run.nextLevel()
  _level         = _level + 1
  _levelComplete = false
end

function Run.getOfferCards()
  local CardData = require("data.cards")
  local pool = CardData.offerPools[_level + 1]
  if not pool or #pool == 0 then
    pool = CardData.offerPools[1] or {}
  end
  local available = {}
  for _, v in ipairs(pool) do available[#available + 1] = v end
  local offers = {}
  while #offers < 3 and #available > 0 do
    local idx = math.random(#available)
    offers[#offers + 1] = available[idx]
    table.remove(available, idx)
  end
  while #offers < 3 do
    offers[#offers + 1] = offers[math.random(#offers)]
  end
  return offers
end

function Run.saveTurn(opts)
  local lines = {
    "return {",
    "    level    = " .. tostring(_level)         .. ",",
    "    progress = " .. tostring(opts.progress)  .. ",",
    "    threat   = " .. tostring(opts.threat)    .. ",",
    "    ram      = " .. tostring(opts.ram)       .. ",",
    "    deck     = " .. prettySerialize(_deckData,    1) .. ",",
    "    drawPile = " .. prettySerialize(opts.drawPile, 1) .. ",",
    "    hand     = " .. prettySerialize(opts.hand,     1) .. ",",
    "    dtor     = " .. prettySerialize(opts.dtor,     1) .. ",",
    "}",
  }
  local ok, err = love.filesystem.write("run_save.lua", table.concat(lines, "\n") .. "\n")
  if not ok then print("[Run] saveTurn failed: " .. tostring(err)) end
end

function Run.load()
  if not love.filesystem.getInfo("run_save.lua") then return false end
  local ok, data = pcall(function() return love.filesystem.load("run_save.lua")() end)
  if not ok or type(data) ~= "table" then
    print("[Run] load failed")
    return false
  end
  _level         = data.level or 0
  _deckData      = data.deck  or {}
  _levelComplete = false
  _savedTurn = {
    progress = data.progress or 0,
    threat   = data.threat   or 0,
    ram      = data.ram      or 0,
    drawPile = data.drawPile or {},
    hand     = data.hand     or {},
    dtor     = data.dtor     or { entries = {}, preNullifiedSlots = {} },
  }
  return true
end

-- Returns the mid-turn state captured by the most recent Run.load(), or nil
-- if no save has been loaded this session.
function Run.getSavedTurn() return _savedTurn end

function Run.deleteSave()  love.filesystem.remove("run_save.lua") end
function Run.hasSave()     return love.filesystem.getInfo("run_save.lua") ~= nil end

return Run
