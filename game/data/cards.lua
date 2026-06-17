local CardData = {}

CardData.cards = {
  card1 = {
    topEnergy    = 1,
    bottomEnergy = 1,
    play    = { { type = "progress", value = 1 } },
    discard = { { type = "threat", value = 1 } },
    dtor = { { type = "threat", value = 1 } },
  },
  card2 = {
    topEnergy    = 2,
    bottomEnergy = 2,
    play    = { { type = "progress", value = 1 }, { type = "nullify", value = 1 } },
    discard = { { type = "threat", value = 1 }, { type = "threat",   value = 1 } },
    dtor = { { type = "threat", value = 1 }, { type = "threat",   value = 1 }, { type = "threat",   value = 1 } },
  },
  card3 = {
    topEnergy    = 1,
    bottomEnergy = 1,
    play    = { { type = "progress", value = 1 } },
    -- discard = { { type = "threat", value = 1 }, { type = "threat",   value = 1 }, { type = "nullify",   value = 1 } },
    dtor = { { type = "threat", value = 1 }, { type = "threat",   value = 1 } },
  },
  card4 = {
    topEnergy    = 2,
    bottomEnergy = 2,
    play    = { { type = "threat", value = 1 }, { type = "progress", value = 1 }, { type = "progress", value = 1 } },
    discard = { { type = "threat", value = 1 } },
    dtor = { { type = "threat", value = 1 } },
  },
  card5 = {
    topEnergy    = 3,
    bottomEnergy = 3,
    play    = { { type = "progress", value = 1 }, { type = "progress", value = 1 }, { type = "progress", value = 1 } },
    discard = { { type = "nullify",   value = 1 } },
    dtor = { { type = "threat", value = 1 }, { type = "threat",   value = 1 }, { type = "threat", value = 1 } },
  },
  card6 = {
    topEnergy    = 1,
    bottomEnergy = 1,
    play    = { { type = "progress", value = 1 } },
    -- discard = { { type = "threat", value = 1 }, { type = "threat",   value = 1 }, { type = "nullify",   value = 1 } },
    dtor = { { type = "threat", value = 1 }, { type = "threat",   value = 1 } },
  },
  card7 = {
    topEnergy    = 1,
    bottomEnergy = 1,
    play    = { { type = "progress", value = 1 }, { type = "progress", value = 1 } },
    discard = { { type = "threat", value = 1 }, { type = "threat",   value = 1 } },
    dtor = { { type = "threat", value = 1 }, { type = "threat",   value = 1 } },
  },
  card8 = {
    topEnergy    = 2,
    bottomEnergy = 2,
    play    = { { type = "progress", value = 1 }, { type = "progress", value = 1 } },
    discard = { { type = "threat", value = 1 }, { type = "threat",   value = 1 } },
    dtor = { { type = "threat", value = 1 }, { type = "threat",   value = 1 }, { type = "threat",   value = 1 } },
  },
  card9 = {
    topEnergy    = 4,
    bottomEnergy = 4,
    play    = { { type = "progress", value = 1 }, { type = "progress", value = 1 }, { type = "nullify", value = 1 } },
    discard = { { type = "threat", value = 1 }, { type = "threat",   value = 1 }, { type = "threat",   value = 1 } },
    dtor = { { type = "threat", value = 1 }, { type = "threat",   value = 1 }, { type = "threat", value = 1 } },
  },
  card10 = {
    topEnergy    = 1,
    bottomEnergy = 1,
    play    = { { type = "progress", value = 1 }, { type = "threat", value = 1 } },
    -- discard = { { type = "threat", value = 1 }, { type = "threat",   value = 1 }, { type = "nullify",   value = 1 } },
    dtor = { { type = "threat", value = 1 }, { type = "threat",   value = 1 } },
  },
}

return CardData
