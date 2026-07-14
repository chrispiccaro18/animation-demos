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

return DeckUnlocks
