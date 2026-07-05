local Run = {}

local _level         = 0
local _deckData      = {}
local _levelComplete = false

local function serializeValue(v)
  local t = type(v)
  if t == "number"  then return tostring(v) end
  if t == "string"  then return string.format("%q", v) end
  if t == "boolean" then return tostring(v) end
  if t == "table" then
    local parts  = {}
    local isArr  = true
    local maxN   = 0
    for k, _ in pairs(v) do
      if type(k) ~= "number" or k ~= math.floor(k) or k < 1 then
        isArr = false; break
      end
      if k > maxN then maxN = k end
    end
    if isArr then
      for i = 1, maxN do parts[i] = serializeValue(v[i]) end
    else
      for k, val in pairs(v) do
        local key = (type(k) == "string" and k:match("^[%a_][%w_]*$"))
                    and k or ("[" .. serializeValue(k) .. "]")
        parts[#parts + 1] = key .. "=" .. serializeValue(val)
      end
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return "nil"
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

function Run.save()
  local data = { level = _level, deck = {} }
  for _, cd in ipairs(_deckData) do data.deck[#data.deck + 1] = cd end
  local ok, err = love.filesystem.write("run_save.lua", "return " .. serializeValue(data))
  if not ok then print("[Run] save failed: " .. tostring(err)) end
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
  return true
end

function Run.deleteSave()  love.filesystem.remove("run_save.lua") end
function Run.hasSave()     return love.filesystem.getInfo("run_save.lua") ~= nil end

return Run
