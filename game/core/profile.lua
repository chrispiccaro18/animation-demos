local Serialize = require("lib.serialize")
local Run       = require("core.run")

-- Per-profile meta progression (unlocks, stats) plus the small index file
-- that will back a future profile-select screen. No UI to create/switch
-- profiles yet, so callers just activate a fixed id (see Profile.setActive).
local Profile = {}

local INDEX_PATH = "profiles/index.lua"

local _activeId = nil
local _data     = nil

local function profileDir(id)  return "profiles/" .. id end
local function profilePath(id) return profileDir(id) .. "/profile.lua" end

local function loadIndex()
  return Serialize.loadFile(INDEX_PATH) or {}
end

local function saveIndex(index)
  love.filesystem.createDirectory("profiles")
  local ok, err = love.filesystem.write(INDEX_PATH, "return " .. Serialize.pretty(index) .. "\n")
  if not ok then print("[Profile] saveIndex failed: " .. tostring(err)) end
end

local function defaultProfileData(name)
  return {
    name                      = name,
    highestLevelReachedByDeck = { original = 0 },
  }
end

local function ensureIndexed(id, name)
  local index = loadIndex()
  for _, entry in ipairs(index) do
    if entry.id == id then return end
  end
  table.insert(index, { id = id, name = name })
  saveIndex(index)
end

function Profile.list()
  return loadIndex()
end

function Profile.getActiveId() return _activeId end
function Profile.getData()     return _data end

-- Highest level ever reached WITH A GIVEN STARTING DECK (see
-- data/cards.lua's CardData.startingDecks), across all runs of that deck.
function Profile.getHighestLevelReached(deckId)
  deckId = deckId or "original"
  local byDeck = _data and _data.highestLevelReachedByDeck or {}
  return byDeck[deckId] or 0
end

-- Bumps the given deck's high-water mark and persists it, if `level` is a
-- new best for that deck. Call whenever Run.nextLevel() advances (see
-- cardPickScreen.lua), passing Run.getDeckType().
function Profile.reportLevelReached(deckId, level)
  if not _data then return end
  deckId = deckId or "original"
  _data.highestLevelReachedByDeck = _data.highestLevelReachedByDeck or {}
  local current = _data.highestLevelReachedByDeck[deckId] or 0
  if (level or 0) > current then
    _data.highestLevelReachedByDeck[deckId] = level
    Profile.save()
  end
end

function Profile.save()
  if not _activeId or not _data then return end
  love.filesystem.createDirectory(profileDir(_activeId))
  local ok, err = love.filesystem.write(
    profilePath(_activeId), "return " .. Serialize.pretty(_data) .. "\n")
  if not ok then print("[Profile] save failed: " .. tostring(err)) end
end

-- Activates profile `id`, creating it with default data if it doesn't exist
-- yet, and points Run at that profile's save directory.
function Profile.setActive(id)
  local dir  = profileDir(id)
  local name = "Profile " .. id
  love.filesystem.createDirectory(dir)

  _activeId = id
  _data     = Serialize.loadFile(profilePath(id))
  if not _data then
    _data = defaultProfileData(name)
    Profile.save()
  end
  ensureIndexed(id, _data.name or name)

  Run.setSaveDir(dir)
end

return Profile
