local EscalationLevels = require("data.escalation")
local Unlocks          = require("core.unlocks")

-- Picks the beginning-of-turn escalation token sequence per level, per
-- data/escalation.lua's mode config (nested per starting-deck id). Random/
-- pool draws are seeded off the run's seed + level + turn (see core/run.lua)
-- so the same run replaying the same level/turn -- e.g. main.lua's
-- post-reload cascade replay -- reproduces the same sequence without
-- persisting it.
local Escalation = {}

local function levelsFor(deckId)
  return EscalationLevels[deckId] or EscalationLevels.original or {}
end

local function configFor(deckId, level)
  local levels = levelsFor(deckId)
  return levels[level] or levels.default or { mode = "random" }
end

local function unlockedList(deckId, highestLevel)
  local eligible = {}
  for _, tokenType in ipairs(Unlocks.allTokenTypes(deckId)) do
    if Unlocks.isTokenUnlocked(deckId, tokenType, highestLevel) then
      eligible[#eligible + 1] = tokenType
    end
  end
  if #eligible == 0 then eligible = { "threat" } end
  return eligible
end

local function makeGenerator(runSeed, level, turn)
  return love.math.newRandomGenerator((runSeed or 0) * 1000003 + level * 1009 + turn)
end

-- Maps each capped token type to the index of its cap group in a deck's
-- maxPerTurn list. Built lazily per deckId (each deck's data/escalation.lua
-- sub-table has its own maxPerTurn) and cached since the data is static.
local _capDataCache = {}
local function capDataFor(deckId)
  local cached = _capDataCache[deckId]
  if cached then return cached end

  local maxPerTurn = levelsFor(deckId).maxPerTurn or {}
  local groupIndexByType = {}
  for i, group in ipairs(maxPerTurn) do
    for _, tokenType in ipairs(group.types) do
      groupIndexByType[tokenType] = i
    end
  end

  local data = { maxPerTurn = maxPerTurn, groupIndexByType = groupIndexByType }
  _capDataCache[deckId] = data
  return data
end

-- Tracks per-group pick counts for a single sequence generation, so caps
-- reset every call (i.e. every turn).
local function newCapTracker(deckId)
  local capData = capDataFor(deckId)
  local maxPerTurn = capData.maxPerTurn
  local groupIndexByType = capData.groupIndexByType
  local counts = {}
  for i in ipairs(maxPerTurn) do counts[i] = 0 end
  return {
    isEligible = function(tokenType)
      local gi = groupIndexByType[tokenType]
      if not gi then return true end
      return counts[gi] < maxPerTurn[gi].max
    end,
    record = function(tokenType)
      local gi = groupIndexByType[tokenType]
      if gi then counts[gi] = counts[gi] + 1 end
    end,
  }
end

-- Starting at order[startIdx], scans forward (cycling once through the
-- whole list) for the first entry not yet capped out. Falls back to
-- "threat" if every entry in `order` is capped.
local function pickEligibleInOrder(order, startIdx, tracker)
  local n = #order
  for offset = 0, n - 1 do
    local idx = ((startIdx - 1 + offset) % n) + 1
    local candidate = order[idx]
    if tracker.isEligible(candidate) then return candidate end
  end
  return "threat"
end

-- Returns an array of `level` token type strings for this turn, for the
-- given starting-deck id.
function Escalation.pickSequence(deckId, level, turn, runSeed, highestLevel)
  local cfg = configFor(deckId, level)
  local tracker = newCapTracker(deckId)

  if cfg.mode == "predetermined" then
    local order = cfg.order or { "threat" }
    local sequence = {}
    for i = 1, level do
      local startIdx = (i - 1) % #order + 1
      local picked = pickEligibleInOrder(order, startIdx, tracker)
      sequence[i] = picked
      tracker.record(picked)
    end
    return sequence
  end

  local pool = unlockedList(deckId, highestLevel)
  if cfg.mode == "pool" and cfg.pool then
    local unlockedSet = {}
    for _, t in ipairs(pool) do unlockedSet[t] = true end
    local restricted = {}
    for _, t in ipairs(cfg.pool) do
      if unlockedSet[t] then restricted[#restricted + 1] = t end
    end
    if #restricted > 0 then pool = restricted end
  end

  local rng = makeGenerator(runSeed, level, turn)
  local sequence = {}
  for i = 1, level do
    local eligible = {}
    for _, t in ipairs(pool) do
      if tracker.isEligible(t) then eligible[#eligible + 1] = t end
    end
    local picked = #eligible > 0 and eligible[rng:random(#eligible)] or "threat"
    sequence[i] = picked
    tracker.record(picked)
  end
  return sequence
end

return Escalation
