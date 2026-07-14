local CardData = {}

CardData.runStartingDeck = {
  {
    topEnergy    = 1,
    bottomEnergy = 1,
    play    = { { type = "progress", value = 1 } },
    -- discard = { { type = "threatNegative", value = 1 } },
    dtor = { { type = "threat", value = 1 }, },
  },
  {
    topEnergy    = 1,
    bottomEnergy = 1,
    play    = { { type = "threat", value = 1 } },
    -- discard = { { type = "threatNegative", value = 1 } },
    dtor = { { type = "progress", value = 1 }, },
  },
  {
    topEnergy    = 2,
    bottomEnergy = 2,
    play    = { { type = "progress", value = 1 }, { type = "progress", value = 1 } },
    -- discard = { { type = "threatNegative", value = 1 } },
    dtor = { { type = "threat", value = 1 }, { type = "threat", value = 1 }, },
  },
  {
    topEnergy    = 2,
    bottomEnergy = 2,
    play    = { { type = "threat", value = 1 }, { type = "threat", value = 1 } },
    -- discard = { { type = "threatNegative", value = 1 } },
    dtor = { { type = "progress", value = 1 }, { type = "progress", value = 1 }, },
  },
}

-- CardData.runStartingDeck = {
--   { topEnergy=1, bottomEnergy=1, play={{type="progress",value=1}},                                                   dtor={{type="threat",value=1}} },
--   { topEnergy=1, bottomEnergy=1, play={{type="progress",value=1}},                                                   dtor={{type="threat",value=1}} },
--   { topEnergy=1, bottomEnergy=1, play={{type="threatNegative",value=1}},                                              dtor={{type="threat",value=1}} },
--   { topEnergy=1, bottomEnergy=1, play={{type="threatNegative",value=1}},                                              dtor={{type="threat",value=1}} },
--   { topEnergy=2, bottomEnergy=2, play={{type="progress",value=1},{type="progress",value=1}},                          dtor={{type="threat",value=1},{type="threat",value=1}} },
--   { topEnergy=2, bottomEnergy=2, play={{type="threatNegative",value=1},{type="threatNegative",value=1}},              dtor={{type="threat",value=1},{type="threat",value=1}} },
-- }

-- Flat card offer pool: Run.getOfferCards filters this by which token types
-- are currently unlocked (core/unlocks.lua's Unlocks.isCardUnlocked), then
-- weights the survivors by `rarity` (see data/rarity.lua for the level
-- curve) and by deck token-type saturation (see data/dedup.lua). The
-- "-- tier N" comments are the original grouping this pool was authored in;
-- `rarity` was assigned per-tier (tier 1-2 common, tier 3-4 uncommon, tier 5
-- rare) and can be retuned per-card independently of tier from here on.
-- An optional `minUnlockLevel` field can hold a card back independent of the
-- (already-unlocked) tokens it uses, for curation purposes.
CardData.offerPool = {
  -- tier 1 (was: offered after level 0, preparing for 1 threat/turn)
  {
    rarity = "common",
    topEnergy=3, bottomEnergy=3,
    play={{type="progress",value=1},{type="progress",value=1},{type="progress",value=1}},
    dtor={{type="threat",value=1},{type="threat",value=1},{type="threat",value=1}}
  },
  {
    rarity = "common",
    topEnergy=3, bottomEnergy=3,
    play={{type="threat",value=1},{type="threat",value=1},{type="threat",value=1}},
    dtor={{type="progress",value=1},{type="progress",value=1},{type="progress",value=1}},
  },
  {
    rarity = "common",
    topEnergy    = 2,
    bottomEnergy = 2,
    play    = { { type = "progress", value = 1 }, { type = "progress", value = 1 } },
    -- discard = { { type = "threatNegative", value = 1 } },
    dtor = { { type = "threat", value = 1 }, { type = "threat", value = 1 }, },
  },
  {
    rarity = "common",
    topEnergy    = 2,
    bottomEnergy = 2,
    play    = { { type = "threat", value = 1 }, { type = "threat", value = 1 } },
    -- discard = { { type = "threatNegative", value = 1 } },
    dtor = { { type = "progress", value = 1 }, { type = "progress", value = 1 }, },
  },
  {
    rarity = "common",
    topEnergy=1,bottomEnergy=1,
    play={{type="multiplyAll",value=2},},
    dtor={{type="multiplyThreat",value=2}, { type = "flip", value = 1}}
  },
  {
    rarity = "common",
    topEnergy=1, bottomEnergy=1,
    play={{type="progress",value=1}, {type="threatNegative",value=1}},
    dtor={{type="progressNegative",value=1}, {type="threat",value=1}}
  },
  {
    rarity = "common",
    topEnergy=1, bottomEnergy=1,
    play={{type="flip",value=1},},
    dtor={{type="flip",value=1}}
  },
  {
    rarity = "common",
    topEnergy=2, bottomEnergy=2,
    play={{type="drawToHand",value=1}, {type="drawToHand",value=1},},
    dtor={{type="flip",value=1}, {type="progressNegative",value=1}, {type="progressNegative",value=1},}
  },
  {
    rarity = "common",
    topEnergy=2, bottomEnergy=2,
    play={{type="progress",value=1}, {type="multiplyAll",value=2}},
    dtor={{type="multiplyThreat",value=2}}
  },

  -- tier 2 (was: offered after level 1, preparing for 2 threats/turn)
  {
    rarity = "common",
    topEnergy=1, bottomEnergy=1,
    play={{type="multiplyProgress",value=2}},
    dtor={{type="threat",value=1},{type="threat",value=1}}
  },
  {
    rarity = "common",
    topEnergy=2, bottomEnergy=2,
    play={{type="progress",value=1},{type="progress",value=1},{type="threatNegative",value=1}},
    dtor={{type="progressNegative",value=1},{type="progressNegative",value=1}}
  },
  {
    rarity = "common",
    topEnergy=2, bottomEnergy=2,
    play={{type="progress",value=1},{type="progress",value=1},{type="nullify",value=1}},
    dtor={{type="threatNegative",value=1},{type="threatNegative",value=1}}
  },
  {
    rarity = "common",
    topEnergy=3, bottomEnergy=3,
    play={{type="progress",value=1},{type="progress",value=1},{type="progress",value=1}},
    dtor={{type="threat",value=1},{type="multiplyThreat",value=2}}
  },
  {
    rarity = "common",
    topEnergy=1, bottomEnergy=1,
    play={{type="shuffle",value=1},},
    dtor={{type="flip",value=1},}
  },
  {
    rarity = "common",
    topEnergy=3, bottomEnergy=3,
    play={{type="drawToHand",value=1}, {type="drawToHand",value=1}, {type="drawToHand",value=1},},
    dtor={{type="multiplyThreat",value=2},}
  },

  -- tier 3 (was: offered after level 2, preparing for 3 threats/turn)
  {
    rarity = "uncommon",
    topEnergy=1, bottomEnergy=1,
    play={{type="flip",value=1}},
    dtor={{type="threat",value=1},{type="threat",value=1}} },
  {
    rarity = "uncommon",
    topEnergy=2, bottomEnergy=2,
    play={{type="multiplyAll",value=2}},
    dtor={{type="threat",value=1},{type="threat",value=1},{type="threat",value=1}} },
  {
    rarity = "uncommon",
    topEnergy=3, bottomEnergy=3,
    play={{type="progress",value=1},{type="progress",value=1},{type="threatNegative",value=1}},
    dtor={{type="threat",value=1},{type="threat",value=1},{type="threat",value=1}} },
  {
    rarity = "uncommon",
    topEnergy=2, bottomEnergy=2,
    play={{type="progressNegative",value=1},{type="progressNegative",value=1},{type="nullify",value=1}},
    dtor={{type="progressNegative",value=1},{type="progressNegative",value=1}} },

  -- tier 4 (was: offered after level 3, preparing for 4 threats/turn)
  {
    rarity = "uncommon",
    topEnergy=2, bottomEnergy=2,
    play={{type="multiplyProgress",value=2},{type="progress",value=1}},
    dtor={{type="threat",value=1},{type="threat",value=1},{type="progressNegative",value=1}}
  },
  {
    rarity = "uncommon",
    topEnergy=3, bottomEnergy=3,
    play={{type="nullify",value=1},{type="nullify",value=1}},
    dtor={{type="threat",value=1},{type="threat",value=1},{type="progressNegative",value=1}}
  },
  {
    rarity = "uncommon",
    topEnergy=2, bottomEnergy=2,
    play={{type="flip",value=1},{type="threatNegative",value=1}},
    dtor={{type="threat",value=1},{type="threat",value=1}}
  },
  {
    rarity = "uncommon",
    topEnergy=3, bottomEnergy=3,
    play={{type="progress",value=1},{type="progress",value=1},{type="progress",value=1},},
    dtor={{type="progressNegative",value=1},{type="progressNegative",value=1},{type="progressNegative",value=1},{type="progressNegative",value=1}}
  },
  {
    rarity = "uncommon",
    topEnergy=2, bottomEnergy=2,
    play={{type="progressNegative",value=1},{type="multiplyProgress",value=2},},
    dtor={{type="progressNegative",value=1},{type="multiplyProgress",value=2}}
  },

  -- tier 5 (was: offered after level 4, preparing for 5 threats/turn)
  {
    rarity = "rare",
    topEnergy=2, bottomEnergy=2,
    play={{type="multiplyAll",value=2}},
    dtor={{type="multiplyAll",value=2}}
  },
  {
    rarity = "rare",
    topEnergy=3, bottomEnergy=3,
    play={{type="threatNegative",value=1},{type="threatNegative",value=1},{type="threatNegative",value=1}},
    dtor={{type="progressNegative",value=1},{type="progressNegative",value=1},{type="progressNegative",value=1}}
  },
  {
    rarity = "rare",
    topEnergy=3, bottomEnergy=3,
    play={{type="flip",value=1},{type="progress",value=1},{type="progress",value=1},},
    dtor={{type="flip",value=1},{type="threat",value=1},{type="threat",value=1},}
  },
  {
    rarity = "rare",
    topEnergy=2, bottomEnergy=2,
    play={{type="flip",value=1},{type="multiplyAll",value=2}},
    dtor={{type="flip",value=1},{type="multiplyAll",value=2}}
  },
  {
    rarity = "rare",
    topEnergy=1, bottomEnergy=1,
    minUnlockLevel=8,
    play={{type="multiplyAll",value=2},{type="shuffle",value=1}},
    dtor={{type="multiplyProgress",value=2},{type="multiplyThreat",value=2}}
  },
}

return CardData
