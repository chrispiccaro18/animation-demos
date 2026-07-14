local UnlockLevels = require("data.unlocks")

-- Meta-progression unlock queries. Everything here is a pure function of a
-- "highest level reached" number (see core/profile.lua) against the
-- thresholds in data/unlocks.lua -- no state of its own.
local Unlocks = {}

function Unlocks.isTokenUnlocked(tokenType, highestLevel)
  local required = UnlockLevels[tokenType]
  if required == nil then return true end -- unregistered type: don't block it
  return (highestLevel or 0) >= required
end

-- Returns { [tokenType] = true, ... } for every currently-unlocked type.
function Unlocks.unlockedSet(highestLevel)
  local set = {}
  for tokenType, required in pairs(UnlockLevels) do
    if (highestLevel or 0) >= required then set[tokenType] = true end
  end
  return set
end

function Unlocks.allTokenTypes()
  local list = {}
  for tokenType in pairs(UnlockLevels) do list[#list + 1] = tokenType end
  table.sort(list)
  return list
end

-- Token types whose unlock threshold falls in (oldHighest, newHighest] --
-- i.e. everything that became newly unlocked by reaching newHighest.
function Unlocks.newlyUnlocked(oldHighest, newHighest)
  local list = {}
  for tokenType, required in pairs(UnlockLevels) do
    if required > (oldHighest or 0) and required <= (newHighest or 0) then
      list[#list + 1] = tokenType
    end
  end
  table.sort(list)
  return list
end

-- A card is unlocked once its optional minUnlockLevel override is met (if
-- present) and every token type it references (play/discard/dtor effects)
-- is unlocked.
function Unlocks.isCardUnlocked(cardData, highestLevel)
  if cardData.minUnlockLevel and (highestLevel or 0) < cardData.minUnlockLevel then
    return false
  end
  for _, zoneKey in ipairs({ "play", "discard", "dtor" }) do
    local effects = cardData[zoneKey]
    if type(effects) == "table" then
      for _, effect in ipairs(effects) do
        if effect.type and not Unlocks.isTokenUnlocked(effect.type, highestLevel) then
          return false
        end
      end
    end
  end
  return true
end

return Unlocks
