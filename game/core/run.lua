local Serialize = require("lib.serialize")
local Unlocks   = require("core.unlocks")

local Run = {}

local _level         = 0
local _deckData      = {}
local _levelComplete = false
local _savedTurn     = nil
local _saveDir       = ""
local _runSeed       = 0
local _turn          = 0

local function savePath()
  return (_saveDir ~= "" and (_saveDir .. "/") or "") .. "run.lua"
end

-- Sets the directory this run's save file lives in (e.g. "profiles/1").
-- Must be called (typically by Profile.setActive) before any load/save call.
function Run.setSaveDir(dir)
  _saveDir = dir or ""
  if _saveDir ~= "" then love.filesystem.createDirectory(_saveDir) end
end

function Run.newRun()
  local CardData = require("data.cards")
  _level         = 0
  _levelComplete = false
  _deckData      = {}
  _runSeed       = math.random(1, 2147483647)
  _turn          = 0
  for _, cd in ipairs(CardData.runStartingDeck) do
    _deckData[#_deckData + 1] = cd
  end
end

function Run.getLevel()             return _level             end
function Run.getCurrentDeckData()   return _deckData          end
function Run.isLevelComplete()      return _levelComplete     end
function Run.clearLevelComplete()   _levelComplete = false    end
function Run.getRunSeed()           return _runSeed           end
function Run.getTurn()              return _turn              end

-- Advances the within-level turn counter; call once per sequences.beginTurn().
function Run.nextTurn()
  _turn = _turn + 1
  return _turn
end

function Run.levelComplete()
  _levelComplete = true
end

function Run.addCard(cardData)
  _deckData[#_deckData + 1] = cardData
end

function Run.nextLevel()
  _level         = _level + 1
  _levelComplete = false
  _turn          = 0
end

-- `highestLevel` is the profile's meta-progression high-water mark (see
-- core/profile.lua); pass nil/0 to only offer cards unlocked from the start.
function Run.getOfferCards(highestLevel)
  local CardData = require("data.cards")
  local pool = CardData.offerPool
  local available = {}
  for _, v in ipairs(pool) do
    if Unlocks.isCardUnlocked(v, highestLevel) then
      available[#available + 1] = v
    end
  end
  if #available == 0 then
    -- Thresholds locked out the whole pool (likely a tuning mistake) --
    -- fall back to the unfiltered pool instead of leaving nothing to offer.
    for _, v in ipairs(pool) do available[#available + 1] = v end
  end
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
    "    turn     = " .. tostring(_turn)          .. ",",
    "    runSeed  = " .. tostring(_runSeed)        .. ",",
    "    progress = " .. tostring(opts.progress)  .. ",",
    "    threat   = " .. tostring(opts.threat)    .. ",",
    "    ram      = " .. tostring(opts.ram)       .. ",",
    "    deck     = " .. Serialize.pretty(_deckData,    1) .. ",",
    "    drawPile = " .. Serialize.pretty(opts.drawPile, 1) .. ",",
    "    hand     = " .. Serialize.pretty(opts.hand,     1) .. ",",
    "    dtor     = " .. Serialize.pretty(opts.dtor,     1) .. ",",
    "}",
  }
  local ok, err = love.filesystem.write(savePath(), table.concat(lines, "\n") .. "\n")
  if not ok then print("[Run] saveTurn failed: " .. tostring(err)) end
end

function Run.load()
  local data, err = Serialize.loadFile(savePath())
  if not data then
    if err ~= "not found" then print("[Run] load failed") end
    return false
  end
  _level         = data.level or 0
  _deckData      = data.deck  or {}
  _levelComplete = false
  _turn          = data.turn or 0
  _runSeed       = data.runSeed or math.random(1, 2147483647)
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

function Run.deleteSave()  love.filesystem.remove(savePath()) end
function Run.hasSave()     return love.filesystem.getInfo(savePath()) ~= nil end

return Run
