-- Level-scaled rarity weights for Run.getOfferCards. Weight per rarity is
-- linearly interpolated between the breakpoints below (clamped outside the
-- range), so a card's odds shift smoothly as the run's current level rises.
local Rarity = {}

Rarity.curve = {
  { level = 1, weights = { common = 100, uncommon = 8,  rare = 1  } },
  { level = 9, weights = { common = 100, uncommon = 60, rare = 25 } },
}

function Rarity.weightsForLevel(level)
  local lo, hi = Rarity.curve[1], Rarity.curve[#Rarity.curve]
  if level <= lo.level then return lo.weights end
  if level >= hi.level then return hi.weights end
  local t = (level - lo.level) / (hi.level - lo.level)
  local out = {}
  for rarity, w in pairs(lo.weights) do
    out[rarity] = w + (hi.weights[rarity] - w) * t
  end
  return out
end

return Rarity
