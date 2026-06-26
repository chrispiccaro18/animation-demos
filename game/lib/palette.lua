-- Semantic color palette with swappable variants.
-- All values are {r, g, b, a} tables ready for love.graphics.setColor.
--
-- Switching variants:
--   Palette.setVariant("colorblind")   -- mutates _current in place
--   Palette.danger                     -- always reads the active variant's value
--   Palette.colors                     -- iterable table of only color entries
--
-- Variants are delta tables: only specify keys that differ from "default".
-- Unspecified keys fall back to the default variant's value.

local Color = require("lib.color")

-- ── Variant definitions ─────────────────────────────────────────────────────

local _variants = {

  default = {
    -- Neutral
    default  = Color("#FFFFFF"),        -- plain text, uncolored sprites
    muted    = Color("#8C8C9A"),        -- secondary text, captions, hints

    -- Outcomes
    positive = Color("#6ED59E"),        -- progress, good outcomes
    danger   = Color("#D56E6E"),        -- threat, harm (soft red)
    critical = Color("#9C2B2B"),        -- severe threat (deep red)
    warning  = Color("#FF8C00"),        -- attention, overflow, nullified

    -- Mechanics
    nullify  = Color("#aa33ff"),        -- nullify mechanic
    draw     = Color("#6e83d4"),        -- draw-to-hand mechanic
    energy   = Color("#d0be74"),        -- RAM / energy value

    -- UI chrome
    accent   = Color("#88EDFF"),        -- scanner lines, camera ring, UI highlights

    -- Environment
    void     = Color("#12131A"),        -- game background fill
  },

  -- Deuteranopia / protanopia: replaces red/green distinction with
  -- orange/blue. TODO: tune these values with a simulator.
  colorblind = {
    positive = Color("#5B8FFF"),        -- blue replaces green
    danger   = Color("#E69900"),        -- orange replaces red
    critical = Color("#994400"),        -- dark orange replaces deep red
    nullify  = Color("#CC44FF"),        -- shifted purple (brighter)
  },

  -- High-saturation mode for streaming or low-vision accessibility.
  highContrast = {
    default  = Color("#FFFFFF"),
    muted    = Color("#AAAAAA"),
    positive = Color("#00FF88"),
    danger   = Color("#FF4455"),
    critical = Color("#CC0022"),
    warning  = Color("#FFAA00"),
    accent   = Color("#00EEFF"),
    nullify  = Color("#BB00FF"),
    draw     = Color("#4488FF"),
  },

}

-- ── Mutable color state ─────────────────────────────────────────────────────
-- _current holds only color entries and is mutated on every setVariant call.
-- Palette methods live as rawkeys on Palette itself; color lookups fall
-- through to _current via __index so Palette.danger always returns the
-- active variant's value.

local _current = {}
local _active  = "default"

local Palette = setmetatable({
  -- colors: stable reference for iteration (richText, etc.) — only color entries.
  colors = _current,
}, {
  __index = _current,
})

-- ── Variant API ─────────────────────────────────────────────────────────────

-- Switch to a named variant. Merges delta over default into _current in place.
function Palette.setVariant(name)
  assert(_variants[name], "Unknown palette variant: " .. tostring(name))
  local base  = _variants.default
  local delta = _variants[name]
  for k, v in pairs(base) do
    _current[k] = delta[k] or v
  end
  _active = name
end

-- Return the name of the currently active variant.
function Palette.getVariant()
  return _active
end

-- Return a sorted list of all variant names (for a settings UI).
function Palette.variantNames()
  local names = {}
  for k in pairs(_variants) do table.insert(names, k) end
  table.sort(names)
  return names
end

-- ── Initialise ──────────────────────────────────────────────────────────────

Palette.setVariant("default")

return Palette
