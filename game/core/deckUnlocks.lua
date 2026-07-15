local DeckUnlockReqs = require("data.deckUnlocks")

-- Meta-progression queries for whether a *starting deck* is unlocked (as
-- opposed to core/unlocks.lua, which gates individual token/card types).
-- Consumed by core/deckSelectScreen.lua.
local DeckUnlocks = {}

-- `require`d lazily (not at module load) to avoid a circular require with
-- core/profile.lua -- matches the deferred-require convention already used
-- in core/run.lua for data/cards.lua.
function DeckUnlocks.isUnlocked(deckId)
  local req = DeckUnlockReqs[deckId]
  if not req then return true end -- no entry: unlocked from the start
  local Profile = require("core.profile")
  return Profile.getHighestLevelReached(req.requiresDeck) >= req.requiresLevel
end

-- Human-readable requirement text for a locked deck (nil if the deck isn't
-- locked at all).
function DeckUnlocks.requirementText(deckId)
  local req = DeckUnlockReqs[deckId]
  if not req then return nil end
  local CardData = require("data.cards")
  local requiredDeck = CardData.startingDecks[req.requiresDeck]
  local deckName = (requiredDeck and requiredDeck.name) or req.requiresDeck
  return "Reach Level " .. req.requiresLevel .. " with " .. deckName .. " Deck"
end

-- Deck ids whose requirement is satisfied by `sourceDeckId` reaching a level
-- in (oldHighest, newHighest] -- i.e. every deck that became newly unlocked
-- by playing sourceDeckId up to newHighest. Mirrors core/unlocks.lua's
-- Unlocks.newlyUnlocked; consumed by main.lua's level-complete flow to
-- trigger core/deckUnlockCeremony.lua.
function DeckUnlocks.newlyUnlocked(sourceDeckId, oldHighest, newHighest)
  local list = {}
  for lockedDeckId, req in pairs(DeckUnlockReqs) do
    if req.requiresDeck == sourceDeckId
       and req.requiresLevel > (oldHighest or 0)
       and req.requiresLevel <= (newHighest or 0) then
      list[#list + 1] = lockedDeckId
    end
  end
  table.sort(list)
  return list
end

return DeckUnlocks
