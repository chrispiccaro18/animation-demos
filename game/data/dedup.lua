-- Offer-weighting dedup config: token types not listed here have no cap
-- (e.g. progress, threat, progressNegative, threatNegative are unlimited).
-- Each bucket sums deck-card counts across all its tokenTypes and targets
-- one such card per `perCards` cards in the current deck. `decay` controls
-- how hard the weight falls off once you're over that target (lower = harder
-- cap). Types can share a bucket to pool their budget together.
local Dedup = {}

Dedup.buckets = {
  { tokenTypes = { "nullify", "shuffle" },                                          perCards = 5, decay = 0.6 },
  { tokenTypes = { "drawToDtor", "drawToHand" },                                          perCards = 5, decay = 0.6 },
  { tokenTypes = { "multiplyAll", "multiplyProgress", "multiplyThreat" }, perCards = 5, decay = 0.6 },
  { tokenTypes = { "flip" }, perCards = 5, decay = 0.6 },
}

local typeToBucket = {}
for _, bucket in ipairs(Dedup.buckets) do
  for _, tokenType in ipairs(bucket.tokenTypes) do
    typeToBucket[tokenType] = bucket
  end
end

function Dedup.bucketFor(tokenType)
  return typeToBucket[tokenType]
end

return Dedup
