local UnlockLevels = require("data.unlocks")

-- Meta-progression unlock queries. Everything here is a pure function of a
-- starting-deck id (see data/cards.lua's CardData.startingDecks) plus a
-- "highest level reached with that deck" number (see core/profile.lua)
-- against the thresholds in data/unlocks.lua -- no state of its own.
local Unlocks = {}

-- Every deck's threshold table (falls back to "original" for an unknown
-- deckId, matching the fallback convention used elsewhere -- e.g.
-- core/run.lua's Run.newRun).
local function levelsFor(deckId)
  return UnlockLevels[deckId] or UnlockLevels.original or {}
end

function Unlocks.isTokenUnlocked(deckId, tokenType, highestLevel)
  local required = levelsFor(deckId)[tokenType]
  if required == nil then return true end -- unregistered type: don't block it
  return (highestLevel or 0) >= required
end

-- Returns { [tokenType] = true, ... } for every currently-unlocked type.
function Unlocks.unlockedSet(deckId, highestLevel)
  local set = {}
  for tokenType, required in pairs(levelsFor(deckId)) do
    if (highestLevel or 0) >= required then set[tokenType] = true end
  end
  return set
end

-- `deckId` is optional; every deck's table must define the same universe of
-- token types (see data/unlocks.lua's header comment), so this defaults to
-- reading the key-set off "original" as the canonical set.
function Unlocks.allTokenTypes(deckId)
  local list = {}
  for tokenType in pairs(levelsFor(deckId or "original")) do list[#list + 1] = tokenType end
  table.sort(list)
  return list
end

-- Token types whose unlock threshold (for the given deck) falls in
-- (oldHighest, newHighest] -- i.e. everything that became newly unlocked by
-- reaching newHighest with that deck.
function Unlocks.newlyUnlocked(deckId, oldHighest, newHighest)
  local list = {}
  for tokenType, required in pairs(levelsFor(deckId)) do
    if required > (oldHighest or 0) and required <= (newHighest or 0) then
      list[#list + 1] = tokenType
    end
  end
  table.sort(list)
  return list
end

-- A card is unlocked once its optional minUnlockLevel override is met (if
-- present) and every token type it references (play/discard/dtor effects)
-- is unlocked, for the given starting deck.
function Unlocks.isCardUnlocked(deckId, cardData, highestLevel)
  if cardData.minUnlockLevel and (highestLevel or 0) < cardData.minUnlockLevel then
    return false
  end
  for _, zoneKey in ipairs({ "play", "discard", "dtor" }) do
    local effects = cardData[zoneKey]
    if type(effects) == "table" then
      for _, effect in ipairs(effects) do
        if effect.type and not Unlocks.isTokenUnlocked(deckId, effect.type, highestLevel) then
          return false
        end
      end
    end
  end
  return true
end

return Unlocks
