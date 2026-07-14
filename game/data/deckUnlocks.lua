-- Meta-progression requirements to unlock a starting deck for selection on
-- "New Run" (see core/deckUnlocks.lua, core/deckSelectScreen.lua). Keyed by
-- the LOCKED deck's id (see data/cards.lua's CardData.startingDecks); a
-- deck with no entry here is unlocked from the start (e.g. "original").
return {
  negative = { requiresDeck = "original", requiresLevel = 11 },
}
