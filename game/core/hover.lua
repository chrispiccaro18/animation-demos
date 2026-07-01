-- Hover detection for static game areas.
--
-- Zones: env effect icons, progress bar env indicators, dtor column
-- (slots + text area + area fallback), deck.
--
-- Multi-highlight links:
--   env icon 1/2      ↔ matching progress indicator (bidirectional)
--   dtor slot 1       → dtor text area
--   dtor text area    → dtor slot 1 (if occupied/nullified)
--   dtor column area  → full-area fallback (suppressed when a valid slot is hovered)
--
-- Usage:
--   hover.load()          -- call once after areas.load()
--   hover.setDeck(deck)   -- call after each Deck.new (including reset)
--   hover.update(mx, my)  -- call every frame; pass (-9999,-9999) during drag
--   hover.collectGlowRequests(glow)  -- call from glowRequests.collectAll

local EnvEffects  = require("core.envEffects")
local Dtor        = require("core.dtor")
local ProgressBar = require("core.progressBar")
local Palette     = require("lib.palette")

local TOKEN_NAME = {
  progress         = "Progress",
  threat           = "Threat",
  nullify          = "Nullify",
  shuffle          = "Shuffle",
  progressNegative = "Neg. Progress",
  threatNegative   = "Neg. Threat",
  drawToHand       = "Draw to Hand",
  drawToDtor       = "Draw to Dtor",
  dtor             = "Dtor",
  ram              = "RAM",
}

local M = {}

local _zones = {}  -- { id, test, glows }
local _state = {}  -- id -> bool
local _deck  = nil

-- ─── Utilities ────────────────────────────────────────────────────────────────

local function hitRect(mx, my, cx, cy, hw, hh)
  return math.abs(mx - cx) <= hw and math.abs(my - cy) <= hh
end

local function addZone(id, testFn, glowFn)
  table.insert(_zones, { id = id, test = testFn, glows = glowFn })
  _state[id] = false
end

-- ─── Glow helpers ─────────────────────────────────────────────────────────────

local HOVER_PULSE = { speed = 1.2, min = 0.2, max = 1.0 }

-- Emits the dtor text-area glow (gated: only when text is visible).
local function glowDtorText(glow)
  local data = Dtor.getTextGlowData()
  if not data then return end
  glow:request("hover:dtor-text", {
    kind  = "filledRect",
    cx    = data.cx,
    cy    = data.cy,
    w     = data.w,
    h     = data.h,
    color = Palette.warning,
    alpha = 0.12,
    pulse = HOVER_PULSE,
    light = { radius = 55 * SCALE_X, alpha = 0.25 },
  })
end

-- Emits a per-slot hover glow. Gated: only when the slot is occupied or nullified.
-- Slot 1 also links to the dtor text area.
local function glowDtorSlot(glow, index)
  local dq   = Dtor.area
  local slot = dq.slots[index]
  if not slot or (not slot.occupied and not slot.nullified) then return end
  local slotH = dq.h / dq.maxSlots
  glow:request("hover:dtor-slot-" .. index, {
    kind  = "rect",
    cx    = dq.x + dq.w / 2,
    cy    = dq.y + (index - 0.5) * slotH,
    w     = dq.w * 0.8,
    h     = slotH * 0.8,
    color = Palette.warning,
    alpha = 0.4,
    pulse = HOVER_PULSE,
    light = { radius = 40 * SCALE_X, alpha = 0.3 },
  })
  if index == 1 then
    glowDtorText(glow)
  end
end

-- Dtor text-area zone glow: text + linked slot 1 (if slot 1 has content).
local function glowDtorTextZone(glow)
  glowDtorText(glow)
  local dq   = Dtor.area
  local slot = dq.slots[1]
  if not slot or (not slot.occupied and not slot.nullified) then return end
  local slotH = dq.h / dq.maxSlots
  glow:request("hover:dtor-slot-1", {
    kind  = "rect",
    cx    = dq.x + dq.w / 2,
    cy    = dq.y + 0.5 * slotH,
    w     = dq.w * 0.8,
    h     = slotH * 0.8,
    color = Palette.warning,
    alpha = 0.35,
    pulse = HOVER_PULSE,
    light = { radius = 40 * SCALE_X, alpha = 0.25 },
  })
end

-- Dtor column area fallback: fires when in the column but no occupied/nullified
-- slot is hovered (suppressed by valid slot hits).
local function glowDtorArea(glow)
  local dq = Dtor.area
  for i = 1, dq.maxSlots do
    if _state["dtor:slot-" .. i] then
      local slot = dq.slots[i]
      if slot and (slot.occupied or slot.nullified) then
        return  -- valid slot is hovered; let the slot glow handle it
      end
    end
  end
  glow:request("hover:dtor-area", {
    kind  = "rect",
    cx    = dq.x + dq.w * 0.5,
    cy    = dq.y + dq.h * 0.5 - (18 * SCALE_Y),
    w     = dq.w,
    h     = dq.h + (25 * SCALE_Y),
    color = Palette.warning,
    alpha = 0.28,
    pulse = HOVER_PULSE,
    light = { radius = dq.w * 0.6, alpha = 0.18 },
  })
end

-- Env icon glow + linked progress indicator for indices 1 and 2.
-- Called by both the env icon zones AND the progress indicator zones (bidirectional).
local function glowEnvIcon(glow, index)
  local d = EnvEffects.getSingleIconGlowData(index)
  if not d then return end
  local iw    = d.img:getWidth()
  local ih    = d.img:getHeight()
  local alpha = d.isActive and 0.6  or 0.3
  local lum   = d.isActive and 1.2  or 0.7
  local lAlpha= d.isActive and 0.4  or 0.2
  glow:request("hover:env-" .. tostring(index), {
    kind         = "image",
    image        = d.img,
    x            = d.x,
    y            = d.y,
    sx           = SCALE_X * 1.25,
    sy           = SCALE_Y * 1.25,
    ox           = iw / 2,
    oy           = ih / 2,
    color        = d.glowColor,
    alpha        = alpha,
    luminescence = lum,
    pulse        = HOVER_PULSE,
    light        = { radius = 130 * SCALE_X, alpha = lAlpha },
  }, "top")

  if index == 1 or index == 2 then
    local indAlpha  = d.isActive and 0.65 or 0.4
    local indLAlpha = d.isActive and 0.35 or 0.2
    for _, ind in ipairs(ProgressBar.getEnvIndicatorPositions()) do
      if ind.envIndex == index then
        local iw2, ih2 = ind.asset:getDimensions()
        glow:request("hover:progress-ind-" .. index, {
          kind  = "image",
          image = ind.asset,
          x     = ind.cx,
          y     = ind.cy,
          sx    = SCALE_X * 1.3,
          sy    = SCALE_Y * 1.3,
          ox    = iw2 / 2,
          oy    = ih2 / 2,
          color = Palette.positive,
          alpha = indAlpha,
          pulse = HOVER_PULSE,
          light = { radius = 70 * SCALE_X, alpha = indLAlpha },
        }, "top")
        break
      end
    end
  end
end

local function glowDeck(glow)
  if not _deck then return end
  local b = _deck:getHitBounds()
  if not b then return end
  glow:request("hover:deck", {
    kind  = "rect",
    cx    = b.cx,
    cy    = b.cy,
    w     = b.hw * 2,
    h     = b.hh * 2,
    color = Palette.draw,
    alpha = 0.45,
    pulse = HOVER_PULSE,
    light = { radius = 70 * SCALE_X, alpha = 0.35 },
  })
end

-- ─── Zone registration ────────────────────────────────────────────────────────

function M.load()
  _zones = {}
  _state = {}

  -- Env effect icons (negative, 1, 2) — mutually exclusive; see M.update()
  for _, idx in ipairs({ "negative", 1, 2 }) do
    local b = EnvEffects.getIconHitBounds(idx)
    if b then
      local cx, cy, hw, hh = b.cx, b.cy, b.hw, b.hh
      local i = idx
      addZone(
        "env:" .. tostring(i),
        function(mx, my) return hitRect(mx, my, cx, cy, hw, hh) end,
        function(glow)   glowEnvIcon(glow, i) end
      )
    end
  end

  -- Progress bar env-threshold indicators (bidirectional link to env icons)
  local inds = ProgressBar.getEnvIndicatorPositions()
  for _, ind in ipairs(inds) do
    local cx   = ind.cx
    local cy   = ind.cy
    local hw   = ind.iw * SCALE_X / 2 * 1.4
    local hh   = ind.ih * SCALE_Y / 2 * 1.4
    local envI = ind.envIndex
    addZone(
      "progress-ind:" .. envI,
      function(mx, my) return hitRect(mx, my, cx, cy, hw, hh) end,
      function(glow)   glowEnvIcon(glow, envI) end
    )
  end

  -- Dtor column area (fallback — before slot zones so slot zones can suppress it)
  local dq = Dtor.area
  do
    local cx = dq.x + dq.w / 2
    local cy = dq.y + dq.h / 2
    local hw = dq.w / 2
    local hh = dq.h / 2
    addZone(
      "dtor:area",
      function(mx, my) return hitRect(mx, my, cx, cy, hw, hh) end,
      glowDtorArea
    )
  end

  -- Dtor slots (individual)
  local slotH = dq.h / dq.maxSlots
  for i = 1, dq.maxSlots do
    local cx = dq.x + dq.w / 2
    local cy = dq.y + (i - 0.5) * slotH
    local hw = dq.w / 2
    local hh = slotH / 2
    local n  = i
    addZone(
      "dtor:slot-" .. i,
      function(mx, my) return hitRect(mx, my, cx, cy, hw, hh) end,
      function(glow)   glowDtorSlot(glow, n) end
    )
  end

  -- Dtor text area (bidirectional link with slot 1)
  local tb = Dtor.getTextBounds()
  do
    local cx = tb.x + tb.w / 2
    local cy = tb.y + tb.h / 2
    local hw = tb.w / 2
    local hh = tb.h * 0.75
    addZone(
      "dtor:text",
      function(mx, my) return hitRect(mx, my, cx, cy, hw, hh) end,
      glowDtorTextZone
    )
  end

  -- Deck
  addZone(
    "deck",
    function(mx, my)
      if not _deck then return false end
      local b = _deck:getHitBounds()
      return b ~= nil and hitRect(mx, my, b.cx, b.cy, b.hw, b.hh)
    end,
    glowDeck
  )
end

-- ─── Public API ───────────────────────────────────────────────────────────────

function M.setDeck(deck)
  _deck = deck
end

-- Run all hit tests. Pass (-9999, -9999) to clear all state (e.g. during drag).
function M.update(mx, my)
  for _, z in ipairs(_zones) do
    _state[z.id] = z.test(mx, my)
  end
  -- Env icons are mutually exclusive: only the first hit zone stays active.
  local foundEnv = false
  for _, idx in ipairs({ "negative", 1, 2 }) do
    local id = "env:" .. tostring(idx)
    if _state[id] then
      if foundEnv then
        _state[id] = false
      else
        foundEnv = true
      end
    end
  end
end

function M.isHovered(id)
  return _state[id] == true
end

function M.collectGlowRequests(glow)
  for _, z in ipairs(_zones) do
    if _state[z.id] and z.glows then
      z.glows(glow)
    end
  end
end

-- Issue tooltip requests for all currently-hovered static zones.
-- Call after hover.update() and before hoverTooltip.update().
--
-- Shared tooltips (same ID = same fade state, one box regardless of which
-- linked zone is hovered):
--   env:N  + progress-ind:N  → "tt:env:N"   anchored at env icon right edge
--   dtor:slot-1 + dtor:text  → "tt:dtor:front" anchored at dtor column left / slot-1 Y
function M.collectTooltipRequests(ht)
  -- Env icons and their linked progress-bar indicators share a tooltip anchored
  -- at the env icon so the box never jumps between zones.
  for _, idx in ipairs({ "negative", 1, 2 }) do
    local envZone = "env:" .. tostring(idx)
    local indZone = "progress-ind:" .. tostring(idx)
    if _state[envZone] or _state[indZone] then
      local d = EnvEffects.getTooltipData(idx)
      if d then
        local b = EnvEffects.getIconHitBounds(idx)
        local lines = {}
        local status = (d.isActive or d.isNegative) and "Active" or "Inactive"
        lines[#lines + 1] = "STATUS: " .. status
        if d.threshold then
          lines[#lines + 1] = "THRESHOLD: " .. d.threshold .. " system progress"
        end
        lines[#lines + 1] = "TRIGGER: End Turn"
        -- anchorY = visual top of the icon (remove the 1.3× hit-padding factor)
        local iconTop = b.cy - b.hh / 1.3
        local titleColor = Palette.muted
        if d.isNegative then
          titleColor = Palette.danger
        elseif d.isActive then
          titleColor = Palette.positive
        end
        ht.request("tt:env:" .. tostring(idx), {
          side         = "right",
          anchorX      = b.cx + b.hw,
          anchorY      = iconTop,
          title        = d.name,
          titleColor   = titleColor,
          effects      = d.effects,
          lines        = lines,
          arrowYOffset = (60 * SCALE_Y),
        })
      end
    end
  end

  -- Dtor front entry: slot-1 and the text area share one tooltip at a fixed
  -- anchor (dtor column left edge, slot-1 centre Y) so it doesn't jump.
  local dq    = Dtor.area
  local slotH = dq.h / dq.maxSlots
  local frontShown = false
  if _state["dtor:slot-1"] or _state["dtor:text"] then
    local td = Dtor.getFrontEntryTooltipData()
    if td then
      frontShown = true
      local titleStr = "Next Dtor Effect"
      if td.nullified then titleStr = titleStr .. "  [Nullified]" end
      ht.request("tt:dtor:front", {
        side       = "left",
        anchorX    = dq.x,
        anchorY    = dq.y,
        title      = titleStr,
        titleColor = Palette.warning,
        -- titleColor = td.nullified and Palette.warning or Palette.draw,
        effects    = td.effects,
        arrowYOffset = 65 * SCALE_Y
      })
    end
  end

  -- Individual dtor slots 2..maxSlots (each keeps its own anchor Y)
  local anySlotShown = frontShown
  for i = 2, dq.maxSlots do
    local zoneId = "dtor:slot-" .. i
    if _state[zoneId] then
      local td = Dtor.getSlotTooltipData(i)
      if td then
        anySlotShown = true
        local titleStr = "Dtor Slot " .. i
        if td.nullified then titleStr = titleStr .. "  [Nullified]" end
        ht.request("tt:dtor:slot-" .. i, {
          side       = "left",
          anchorX    = dq.x,
          anchorY    = dq.y + (i - 1) * slotH,
          title      = titleStr,
          titleColor = Palette.warning,
          -- titleColor = td.nullified and Palette.warning or Palette.draw,
          effects    = td.effects,
          arrowYOffset = 65 * SCALE_Y
        })
      end
    end
  end

  -- Dtor column fallback: suppressed whenever any slot or the text area is hovered
  if _state["dtor:area"] and not anySlotShown and not _state["dtor:text"] then
    local n = Dtor.queueLength()
    ht.request("tt:dtor:area", {
      side       = "left",
      anchorX    = dq.x,
      anchorY    = dq.y,
      title      = "Dtor Queue",
      titleColor = Palette.warning,
      lines      = {
        n > 0 and (n .. " effect" .. (n == 1 and "" or "s") .. " queued")
              or "Empty",
        "Top triggers at end turn",
      },
      arrowYOffset = 30 * SCALE_Y
    })
  end
end

return M
