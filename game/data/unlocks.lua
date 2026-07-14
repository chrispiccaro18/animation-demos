-- Meta-progression unlock thresholds: the profile's highest level ever
-- reached WITH A GIVEN STARTING DECK (across all runs of that deck, see
-- core/profile.lua's per-deck highestLevelReachedByDeck) required before a
-- token type is available in card offer pools, end-of-turn escalation
-- flinging, and the sandbox palette.
--
-- Keyed by starting-deck id (see data/cards.lua's CardData.startingDecks)
-- so each deck can have its own unlock pacing. Every deck's sub-table must
-- define the same set of token-type keys -- core/unlocks.lua's
-- allTokenTypes() assumes a canonical key-set (defaults to reading it off
-- "original").
--
return {
  original = {
    ram              = 0,
    progress         = 0,
    threat           = 0,
    progressNegative = 2,
    threatNegative   = 2,
    drawToHand       = 4,
    drawToDtor       = 4,
    nullify          = 6,
    shuffle          = 6,
    multiplyProgress = 8,
    multiplyThreat   = 8,
    multiplyAll      = 10,
    flip             = 10,
  },

  -- Placeholder: verbatim copy of "original"'s thresholds. Retune
  -- independently once Negative-deck pacing is designed.
  negative = {
    ram              = 0,
    progress         = 0,
    threat           = 0,
    progressNegative = 2,
    threatNegative   = 2,
    drawToHand       = 4,
    drawToDtor       = 4,
    nullify          = 6,
    shuffle          = 6,
    multiplyProgress = 8,
    multiplyThreat   = 8,
    multiplyAll      = 10,
    flip             = 10,
  },
}
