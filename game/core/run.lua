local Serialize = require("lib.serialize")
local Unlocks   = require("core.unlocks")
local Rarity    = require("data.rarity")
local Dedup     = require("data.dedup")

local Run = {}

local _level         = 0
local _deckData      = {}
local _deckType      = "original"
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

function Run.newRun(deckId)
  local CardData = require("data.cards")
  _deckType      = deckId or "original"
  _level         = 0
  _levelComplete = false
  _deckData      = {}
  _runSeed       = math.random(1, 2147483647)
  _turn          = 0
  local deckEntry = CardData.startingDecks[_deckType] or CardData.startingDecks.original
  for _, cd in ipairs(deckEntry.deck) do
    _deckData[#_deckData + 1] = cd
  end
end

function Run.getLevel()             return _level             end
function Run.getCurrentDeckData()   return _deckData          end
function Run.getDeckType()          return _deckType          end
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

-- Distinct token types a card's play/dtor effects touch (discard is
-- excluded since that zone is mostly unused in current data).
local function tokenTypesOf(cardData)
  local set = {}
  for _, zoneKey in ipairs({ "play", "dtor" }) do
    local effects = cardData[zoneKey]
    if type(effects) == "table" then
      for _, effect in ipairs(effects) do
        if effect.type then set[effect.type] = true end
      end
    end
  end
  return set
end

-- { [bucket] = count of deck cards touching that bucket }, per data/dedup.lua.
local function deckBucketCounts(deckData)
  local counts = {}
  for _, cardData in ipairs(deckData) do
    local touched = {}
    for tokenType in pairs(tokenTypesOf(cardData)) do
      local bucket = Dedup.bucketFor(tokenType)
      if bucket then touched[bucket] = true end
    end
    for bucket in pairs(touched) do
      counts[bucket] = (counts[bucket] or 0) + 1
    end
  end
  return counts
end

-- 1.0 unless a card touches a saturated dedup bucket, in which case its
-- weight decays the further the deck is over that bucket's target density.
local function saturationMultiplier(cardData, bucketCounts, deckSize)
  local touched = {}
  for tokenType in pairs(tokenTypesOf(cardData)) do
    local bucket = Dedup.bucketFor(tokenType)
    if bucket then touched[bucket] = true end
  end
  local mult = 1
  for bucket in pairs(touched) do
    local count  = bucketCounts[bucket] or 0
    local target = deckSize / bucket.perCards
    if count > target then
      mult = mult * ((bucket.decay or 0.6) ^ (count - target))
    end
  end
  return mult
end

local function cardWeight(cardData, rarityWeights, bucketCounts, deckSize)
  return (rarityWeights[cardData.rarity or "common"] or 1)
       * saturationMultiplier(cardData, bucketCounts, deckSize)
end

-- Roulette-wheel pick of an index into `list`, given a parallel `weights`
-- array. Falls back to a uniform pick if all weights are zero.
local function weightedPick(list, weights)
  local total = 0
  for _, w in ipairs(weights) do total = total + w end
  if total <= 0 then return math.random(#list) end
  local r, cumulative = math.random() * total, 0
  for i, w in ipairs(weights) do
    cumulative = cumulative + w
    if r <= cumulative then return i end
  end
  return #list
end

-- `highestLevel` is the profile's meta-progression high-water mark (see
-- core/profile.lua); pass nil/0 to only offer cards unlocked from the start.
-- Rarity scales with the current run's level (_level); dedup weighting
-- scales with the current run's deck composition (_deckData).
function Run.getOfferCards(highestLevel)
  local CardData = require("data.cards")
  local pool = CardData.offerPool
  local available = {}
  -- deckType isn't used to skew offer-pool weighting yet (see data/cards.lua's
  -- offerPool comment) -- only to gate which cards' token types are unlocked.
  for _, v in ipairs(pool) do
    if Unlocks.isCardUnlocked(_deckType, v, highestLevel) then
      available[#available + 1] = v
    end
  end
  if #available == 0 then
    -- Thresholds locked out the whole pool (likely a tuning mistake) --
    -- fall back to the unfiltered pool instead of leaving nothing to offer.
    for _, v in ipairs(pool) do available[#available + 1] = v end
  end

  local rarityWeights = Rarity.weightsForLevel(_level)
  local deckSize      = #_deckData
  local bucketCounts  = deckBucketCounts(_deckData)

  local offers = {}
  while #offers < 3 and #available > 0 do
    local weights = {}
    for i, v in ipairs(available) do
      weights[i] = cardWeight(v, rarityWeights, bucketCounts, deckSize)
    end
    local idx = weightedPick(available, weights)
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
    "    deckType = " .. Serialize.pretty(_deckType) .. ",",
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
  _deckType      = data.deckType or "original"
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
