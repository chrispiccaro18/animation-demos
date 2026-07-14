-- Per-level beginning-of-turn escalation config, consumed by
-- core/escalation.lua. Levels not listed fall back to `default`. This is
-- pure design data -- nothing here needs to be duplicated into the run
-- save file; core/escalation.lua regenerates a level/turn's sequence from
-- this table plus Run's saved `runSeed` + `turn` (core/run.lua).
--
-- mode = "random"        -- uniform draw over every currently-unlocked type
-- mode = "pool"          -- uniform draw over `pool`, intersected with unlocks
-- mode = "predetermined" -- fixed `order` list, cycling if level > #order
--
-- Placeholder tuning below -- adjust freely, no code changes needed.
return {
  default = { mode = "random" },
  -- Level 1 always throws this exact 4-token pattern, every turn, so the
  -- level plays as a fixed puzzle rather than a random draw. If level 4
  -- ever throws more than 4 tokens the list cycles: token 5 repeats
  -- order[1], token 6 repeats order[2], etc.
  [1] = { mode = "predetermined", order = { "threat" } },
  [2] = { mode = "predetermined", order = { "threat", "threat", "progressNegative" } },
  [3] = { mode = "predetermined", order = { "threat", "threat", "progressNegative" } },
  [4] = { mode = "predetermined", order = { "threat", "threat", "progressNegative", "drawToDtor" } },
  [5] = { mode = "predetermined", order = { "threat", "threat", "progressNegative", "drawToDtor" } },
  [6] = { mode = "predetermined", order = { "threat", "threat", "progressNegative", "drawToDtor", "shuffle"  } },
  [7] = { mode = "predetermined", order = { "threat", "threat", "progressNegative", "drawToDtor", "shuffle" } },
  [8] = { mode = "predetermined", order = { "threat", "threat", "progressNegative", "drawToDtor", "shuffle", "multiplyThreat" } },
  [9] = { mode = "predetermined", order = { "threat", "threat", "progressNegative", "drawToDtor", "shuffle", "multiplyThreat" } },
  [10] = { mode = "predetermined", order = { "threat", "threat", "progressNegative", "drawToDtor", "shuffle", "multiplyThreat" } },

  -- Level 2 only ever throws threat or progressNegative, never the wider
  -- unlocked set -- eases the player into escalation before it opens up.
  -- [2] = { mode = "pool", pool = { "threat", "progressNegative" } },
  -- [3] = { mode = "pool", pool = { "threat", "progressNegative" } },
  -- [4] = { mode = "pool", pool = { "threat", "progressNegative" } },
  -- [5] = { mode = "pool", pool = { "threat", "progressNegative" } },
  -- [6] = { mode = "pool", pool = { "threat", "progressNegative" } },
  -- [7] = { mode = "pool", pool = { "threat", "progressNegative" } },

  -- [8] = { mode = "pool", pool = { "threat", "progressNegative" } },
  -- [9] = { mode = "pool", pool = { "threat", "progressNegative" } },
  -- [10] = { mode = "pool", pool = { "threat", "progressNegative" } },

  -- Per-turn caps on how many tokens of a type (or group of types sharing
  -- one shared budget) may appear in a single turn's sequence. Applies to
  -- every mode -- predetermined, pool, and random alike (core/escalation.lua).
  -- Once a type/group's budget is spent, later picks that would've been
  -- that type/group are skipped in favor of another eligible option; if
  -- every option available to a pick is capped out, it falls back to
  -- "threat" (never itself capped here).
  maxPerTurn = {
    { types = { "nullify" }, max = 1 },
    { types = { "shuffle" }, max = 1 },
    { types = { "ram" }, max = 2 },
    { types = { "multiplyAll", "multiplyProgress", "multiplyThreat" }, max = 2 },
    { types = { "drawToHand", "drawToDtor" }, max = 1 },
  },
}
