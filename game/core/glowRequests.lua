local areas       = require("core.areas")
local hover       = require("core.hover")
local Dtor        = require("core.dtor")
local Palette     = require("lib.palette")
local pulse       = require("lib.pulse")
local progressBar = require("core.progressBar")
local threatBar   = require("core.threatBar")
local envEffects  = require("core.envEffects")
local AssetManifest = require("assets.manifest")
local ActionQueue = require("core.actionQueue")

local M = {}

-- Start times for negative-tick pulse — reset when the negative state begins so
-- glows start at minimum alpha rather than snapping to mid-cycle.
local _progressNegStartT = nil
local _threatNegStartT   = nil

local TOKEN_PALETTE_KEYS = {
  progress         = "positive",
  progressNegative = "positiveNeg",
  threat           = "danger",
  threatNegative   = "threatNeg",
  nullify          = "nullify",
  ram              = "energy",
  drawToHand       = "draw",
  dtor             = "warning",
  shuffle          = "warning",
  drawToDtor       = "warning",
}

-- ──────────────────────────────────────────────────────────────────────────────
-- Card slot / terminal glows (called during drag from sequences or main)
-- ──────────────────────────────────────────────────────────────────────────────

-- Emits a border-rect glow for each occupied slot in `zone` on `card`.
-- `keyPrefix` becomes the glow item key (e.g. "card-slot-play").
-- `extraRotation` (optional) is added to card.current.r — use math.pi/4 for diamond slots.
-- Returns seenTypes { [tokenType] = true } for use with requestTerminalGlows.
function M.requestSlotGlows(glow, card, zone, keyPrefix, extraRotation)
  local n = card._slotCounts and card._slotCounts[zone] or 0
  local seenTypes = {}
  for i = 1, n do
    local rect      = card:getSlotCanvasRect(zone, i)
    local slot      = card._slots[zone] and card._slots[zone][i]
    local tokenType = slot and slot.token and slot.token.token_type
    local color     = Palette[TOKEN_PALETTE_KEYS[tokenType]] or Palette.accent
    local scale = 1.0
    if tokenType == "ram" then
      scale = 0.8
    end
    if rect then
      glow:request(keyPrefix .. ":" .. i, {
        kind     = "rect",
        cx       = rect.cx,
        cy       = rect.cy,
        w        = rect.w * scale,
        h        = rect.h * scale,
        rotation = card.current.r + (extraRotation or 0),
        color    = color,
        alpha    = 0.65,
        pulse    = { speed = 2.0, min = 0.0, max = 1.0 },
        light    = { radius = 30 * SCALE_X, alpha = 0.4 },
      }, "top")
    end
    if tokenType then seenTypes[tokenType] = true end
  end
  return seenTypes
end

-- Emits terminal destination glow rects based on seenTypes from requestSlotGlows.
-- `deck` is optional; omit (or pass nil) when drawToHand terminal is not relevant.
function M.requestTerminalGlows(glow, seenTypes, deck)
  local terminalSize = 110 * SCALE_X

  if seenTypes["progress"] or seenTypes["progressNegative"] then
    local t = seenTypes["progress"] and "progress" or "progressNegative"
    glow:request("terminal:progress", {
      kind  = "rect",
      cx    = areas.progressDestination.x,
      cy    = areas.progressDestination.y,
      w     = terminalSize,
      h     = terminalSize,
      color = Palette[TOKEN_PALETTE_KEYS[t]],
      alpha = 0.7,
      pulse = { speed = 2.0, min = 0.0, max = 1.0 },
      light = { radius = 30 * SCALE_X, alpha = 0.3 },
    })
  end

  if seenTypes["threat"] or seenTypes["threatNegative"] then
    local t = seenTypes["threat"] and "threat" or "threatNegative"
    glow:request("terminal:threat", {
      kind         = "rect",
      cx           = areas.threatDestination.x,
      cy           = areas.threatDestination.y,
      w            = terminalSize,
      h            = terminalSize,
      color        = Palette[TOKEN_PALETTE_KEYS[t]],
      alpha        = 0.8,
      luminescence = 1.5,
      pulse        = { speed = 2.0, min = 0.0, max = 1.0 },
      light        = { radius = 30 * SCALE_X, alpha = 0.3 },
    })
  end

  if seenTypes["nullify"] then
    local slot = Dtor.nextUnnullifiedSlot()
    if slot then
      glow:request("terminal:nullify", {
        kind  = "rect",
        cx    = slot.x,
        cy    = slot.y,
        w     = Dtor.area.w * 0.8,
        h     = terminalSize * 1.2,
        color = Palette[TOKEN_PALETTE_KEYS["nullify"]],
        alpha = 0.7,
        pulse = { speed = 2.0, min = 0.0, max = 1.0 },
        light = { radius = terminalSize * 1.2, alpha = 0.3 },
      })
    end
  end

  if seenTypes["ram"] then
    glow:request("terminal:ram", {
      kind  = "rect",
      cx    = areas.pool.x + areas.pool.w * 0.5,
      cy    = areas.pool.y + areas.pool.h * 0.5,
      w     = areas.pool.w,
      h     = areas.pool.h,
      color = Palette[TOKEN_PALETTE_KEYS["ram"]],
      alpha = 0.5,
      pulse = { speed = 2.0, min = 0.0, max = 1.0 },
      light = { radius = 30 * SCALE_X, alpha = 0.3 },
    })
  end

  if seenTypes["drawToHand"] and deck then
    glow:request("terminal:drawToHand", {
      kind  = "rect",
      cx    = deck.x,
      cy    = deck.y,
      w     = deck.w * SCALE_X,
      h     = deck.h * SCALE_Y,
      color = Palette[TOKEN_PALETTE_KEYS["drawToHand"]],
      alpha = 0.7,
      pulse = { speed = 2.0, min = 0.0, max = 1.0 },
      light = { radius = 30 * SCALE_X, alpha = 0.3 },
    })
  end

  if seenTypes["dtor"] or seenTypes["shuffle"] or seenTypes["drawToDtor"] then
    glow:request("terminal:dtor", {
      kind  = "rect",
      cx    = Dtor.area.x + Dtor.area.w * 0.5,
      cy    = Dtor.area.y + Dtor.area.h * 0.5 - (18 * SCALE_Y),
      w     = Dtor.area.w,
      h     = Dtor.area.h + (25 * SCALE_Y),
      color = Palette[TOKEN_PALETTE_KEYS["dtor"]],
      alpha = 0.5,
      pulse = { speed = 2.0, min = 0.0, max = 1.0 },
      light = { radius = Dtor.area.w, alpha = 0.3 },
    })
  end
end

-- Ghost ticks on the progress/threat bars previewing what this card will add/remove.
-- zone: "playEffect" when dragging to play, "discardEffect" when dragging to discard.
-- Positive tokens: ghost images appear at positions beyond the current tick count.
-- Negative tokens: override the last N existing tick keys with a pulsing removal color.
function M.requestGhostTickGlows(glow, card, zone)
  local n = card._slotCounts and card._slotCounts[zone] or 0
  local progressCount    = 0
  local threatCount      = 0
  local progressNegCount = 0
  local threatNegCount   = 0
  for i = 1, n do
    local slot      = card._slots[zone] and card._slots[zone][i]
    local tokenType = slot and slot.token and slot.token.token_type
    if tokenType == "progress" then
      progressCount = progressCount + 1
    elseif tokenType == "threat" then
      threatCount = threatCount + 1
    elseif tokenType == "progressNegative" then
      progressNegCount = progressNegCount + 1
    elseif tokenType == "threatNegative" then
      threatNegCount = threatNegCount + 1
    end
  end

  local ghostTickScale = 1.0

  -- Positive: ghost images at positions beyond current count
  for _, g in ipairs(progressBar.getGhostTickPositions(progressCount)) do
    glow:request("ghost-progress-" .. g.index, {
      kind  = "image",
      image = g.asset,
      x     = g.cx, y = g.cy,
      sx    = SCALE_X * ghostTickScale,
      sy    = SCALE_Y * ghostTickScale,
      ox    = g.aw / 2, oy = g.ah / 2,
      color = Palette.positive,
      alpha = 0.55,
      pulse = { speed = 2.0, min = 0.0, max = 0.8 },
      luminescence = 1.75,
    })
  end

  for _, g in ipairs(threatBar.getGhostTickPositions(threatCount)) do
    glow:request("ghost-threat-" .. g.index, {
      kind  = "image",
      image = g.asset,
      x     = g.cx, y = g.cy,
      sx    = SCALE_X * ghostTickScale,
      sy    = SCALE_Y * ghostTickScale,
      ox    = g.aw / 2, oy = g.ah / 2,
      color = Palette.danger,
      alpha = 0.55,
      luminescence = 1.75,
      pulse = { speed = 2.0, min = 0.0, max = 0.8 },
    })
  end

  -- Negative: overwrite the last N existing tick glow keys using shared pulse so the
  -- glow stays in phase with the sprite alpha set by progressBar/threatBar draw().
  if progressNegCount > 0 then
    local pA    = pulse.valueFrom(2.0, 0.3, 1.0, _progressNegStartT)
    local ticks = progressBar.getTickData()
    for j = 1, math.min(progressNegCount, #ticks) do
      local tick = ticks[#ticks - j + 1]
      glow:request("progress-tick-" .. tick.index, {
        kind         = "image",
        image        = tick.asset,
        x            = tick.cx, y = tick.cy,
        sx           = SCALE_X * ghostTickScale,
        sy           = SCALE_Y * ghostTickScale,
        ox           = tick.aw / 2, oy = tick.ah / 2,
        color        = Palette.positiveNeg,
        alpha        = pA,
        fadeIn       = false,
        fadeOut      = false,
        luminescence = 1.75,
      }, "top")
    end
  end

  if threatNegCount > 0 then
    local pA    = pulse.valueFrom(2.0, 0.3, 1.0, _threatNegStartT)
    local ticks = threatBar.getTickData()
    for j = 1, math.min(threatNegCount, #ticks) do
      local tick = ticks[#ticks - j + 1]
      glow:request("threat-tick-" .. tick.index, {
        kind         = "image",
        image        = tick.asset,
        x            = tick.cx, y = tick.cy,
        sx           = SCALE_X * ghostTickScale,
        sy           = SCALE_Y * ghostTickScale,
        ox           = tick.aw / 2, oy = tick.ah / 2,
        color        = Palette.threatNeg,
        alpha        = pA,
        fadeIn       = false,
        fadeOut      = false,
        luminescence = 1.75,
      }, "top")
    end
  end
end

-- Ghost glows on the card's topEnergyHoles (RAM cost) slots when dragging to play.
-- If pool has enough chips: pulsing rect on each slot. If not: "Insufficient RAM" in pool.
function M.requestRamCostGlows(glow, card)
  if ActionQueue.isRunning() then return end

  local ramNeeded = card._slotCounts and card._slotCounts["topEnergyHoles"] or 0
  if ramNeeded == 0 then return end

  if #areas.pool.chips >= ramNeeded then
    -- Ghost glow on each card RAM slot (diamond-shaped holes).
    for i = 1, ramNeeded do
      local rect = card:getSlotCanvasRect("topEnergyHoles", i)
      if rect then
        glow:request("ram-cost-slot:" .. i, {
          kind     = "rect",
          cx       = rect.cx,
          cy       = rect.cy,
          w        = rect.w * 0.8,
          h        = rect.h * 0.8,
          rotation = card.current.r + math.pi / 4,
          color    = Palette.energy,
          alpha    = 0.65,
          pulse    = { speed = 2.0, min = 0.0, max = 1.0 },
          light    = { radius = 30 * SCALE_X, alpha = 0.4 },
        }, "top")
      end
    end
    -- Highlight the first N chips in the pool — FIFO, so these are the ones that will actually be consumed.
    for i = 1, ramNeeded do
      local chip = areas.pool.chips[i]
      if chip then
        glow:request("ram-pool-chip:" .. i, {
          kind  = "rect",
          cx    = chip.x,
          cy    = chip.y,
          w     = 70 * SCALE_X,
          h     = 70 * SCALE_Y,
          rotation = math.pi / 4,
          color = Palette.energy,
          alpha = 0.7,
          pulse = { speed = 2.0, min = 0.0, max = 1.0 },
          light = { radius = 50 * SCALE_X, alpha = 0.35 },
        })
      end
    end
  else
    areas.pool.insufficientRam = true
    local belowRamText = areas.pool.y + areas.pool.h / 4 + 100 * SCALE_Y
    glow:request("ram-zone-text:insufficient", {
      kind  = "callback",
      color = Palette.warning,
      alpha = 0.9,
      pulse = { speed = 3.0, min = 0.5, max = 1.0 },
      draw  = function(alpha, time, spec)
        love.graphics.setFont(AssetManifest.getFont(72))
        love.graphics.printf(
          "Insufficient RAM",
          areas.pool.x,
          belowRamText,
          areas.pool.w,
          "center"
        )
      end,
    })
  end
end

-- Slot glows for the play effect zone + terminal destination glows.
function M.requestPlayZoneGlows(glow, card, deck)
  local seenTypes = M.requestSlotGlows(glow, card, "playEffect", "card-slot-play")
  M.requestTerminalGlows(glow, seenTypes, deck)
  M.requestGhostTickGlows(glow, card, "playEffect")
  M.requestRamCostGlows(glow, card)
end

-- Slot glows for all discard-visible zones (discardEffect, dtorEffect, bottomEnergy)
-- + terminal destination glows. No deck needed: drawToHand tokens don't appear here.
function M.requestDiscardZoneGlows(glow, card)
  local seenTypes = {}
  local function merge(t) for k, v in pairs(t) do seenTypes[k] = v end end

  merge(M.requestSlotGlows(glow, card, "discardEffect", "card-slot-discard"))
  merge(M.requestSlotGlows(glow, card, "bottomEnergy",  "card-slot-energy", math.pi / 4))

  local dtorRect = card:getZoneCanvasRect("dtorEffect")
  if dtorRect then
    seenTypes["dtor"] = true
    glow:request("card-slot-dtor", {
      kind     = "rect",
      cx       = dtorRect.cx,
      cy       = dtorRect.cy,
      w        = dtorRect.w,
      h        = dtorRect.h,
      rotation = card.current.r,
      color    = Palette.warning,
      alpha    = 0.65,
      pulse    = { speed = 2.0, min = 0.0, max = 1.0 },
      light    = { radius = 30 * SCALE_X, alpha = 0.4 },
    }, "top")
  end

  M.requestTerminalGlows(glow, seenTypes, nil)
  M.requestGhostTickGlows(glow, card, "discardEffect")
end

-- ──────────────────────────────────────────────────────────────────────────────
-- UI bar glows  (top layer — always above dragged cards)
-- ──────────────────────────────────────────────────────────────────────────────

function M.requestProgressGlows(glow)
  for _, tick in ipairs(progressBar.getTickData()) do
    glow:request("progress-tick-" .. tick.index, {
      kind  = "image",
      image = tick.asset,
      x     = tick.cx, y = tick.cy,
      sx    = SCALE_X * tick.s * 1.2,
      sy    = SCALE_Y * tick.s * 1.1,
      ox    = tick.aw / 2, oy = tick.ah / 2,
      color = Palette.positive,
      alpha = 0.7,
      light = { radius = 100 * SCALE_X, alpha = 0.15 },
    }, "top")
  end
end

function M.requestThreatGlows(glow)
  for _, tick in ipairs(threatBar.getTickData()) do
    glow:request("threat-tick-" .. tick.index, {
      kind  = "image",
      image = tick.asset,
      x     = tick.cx, y = tick.cy,
      sx    = SCALE_X * tick.s * 1.2,
      sy    = SCALE_Y * tick.s * 1.1,
      ox    = tick.aw / 2, oy = tick.ah / 2,
      color = Palette.danger,
      alpha = 0.7,
      light = { radius = 100 * SCALE_X, alpha = 0.45 },
    }, "top")
  end
end

function M.requestDtorTextGlow(glow)
  local data = Dtor.getTextGlowData()
  if data then
    glow:request("dtor-text-light", {
      kind  = "filledRect",
      cx    = data.cx,
      cy    = data.cy,
      w     = data.w,
      h     = data.h,
      color = Palette.warning,
      alpha = data.alpha * 0.1,
      pulse = { speed = 1.5, min = 0.5, max = 1.0 },
      light = { radius = 40 * SCALE_X, alpha = data.alpha * 0.2 },
    })
  end

  local line = Dtor.getNullifyLineGlowData()
  if line then
    glow:request("dtor-nullify-line", {
      kind  = "filledRect",
      cx    = line.cx,
      cy    = line.cy,
      w     = line.w,
      h     = line.h,
      color = Palette.warning,
      alpha = line.alpha * 0.85,
      pulse = { speed = 2.0, min = 0.3, max = 1.0 },
      light = { radius = 55 * SCALE_X, alpha = line.alpha * 0.4 },
    })
  end
end

function M.requestEnvGlows(glow)
  for _, icon in ipairs(envEffects.getIconGlowData()) do
    local iw = icon.img:getWidth()
    local ih = icon.img:getHeight()
    if icon.isAnim then
      glow:request("env-anim-" .. tostring(icon.img), {
        kind         = "image",
        image        = icon.img,
        x            = icon.x, y = icon.y,
        sx           = SCALE_X * (icon.scale * 1.1),
        sy           = SCALE_Y * (icon.scale * 1.1),
        luminescence = 1.5 * icon.scale,
        ox           = iw / 2, oy = ih / 2,
        color        = icon.glowColor,
        alpha        = icon.animAlpha * 0.9,
        light        = { radius = 100 * SCALE_X, alpha = 0.35 },
      }, "top")
    elseif icon.isActive then
      glow:request("env-idle-" .. tostring(icon.img) .. "-" .. tostring(icon.x) .. "-" .. tostring(icon.y), {
        kind  = "image",
        image = icon.img,
        x     = icon.x, y = icon.y,
        sx    = SCALE_X * icon.scale,
        sy    = SCALE_Y * icon.scale,
        ox    = iw / 2, oy = ih / 2,
        color = icon.glowColor,
        alpha = 0.35,
        light = { radius = 100 * SCALE_X, alpha = 0.35 },
      }, "top")
    end
  end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Drag zone hints  (mid layer — visible during drag, behind the held card)
-- ──────────────────────────────────────────────────────────────────────────────

local function requestDragZoneGlows(glow, draggingCard, deck)
  glow:request("drop-zone-text:play", {
    kind  = "callback",
    color = { 1.0, 1.0, 1.0, 1.0 },
    alpha = 0.5,
    pulse = { speed = 2.0, min = 0.20, max = 1.0 },
    draw  = function(alpha, time, spec)
      love.graphics.setFont(AssetManifest.getFont(72))
      love.graphics.printf(
        "PLAY",
        areas.play.x - 20 * SCALE_X,
        areas.play.y + areas.play.h - 120 * SCALE_Y,
        areas.play.w,
        "right"
      )
    end,
  })

  glow:request("drop-zone-text:discard", {
    kind   = "callback",
    color  = { 1.0, 1.0, 1.0, 1.0 },
    alpha  = 0.5,
    radius = 14,
    pulse  = { speed = 2.0, min = 0.20, max = 1.0 },
    draw   = function(alpha, time, spec)
      love.graphics.setFont(AssetManifest.getFont(72))
      love.graphics.printf(
        "DISCARD",
        areas.discard.x + 20 * SCALE_X,
        areas.discard.startY + areas.discard.h - 120 * SCALE_Y,
        areas.discard.w,
        "left"
      )
    end,
  })

  glow:request("ram-zone-text:ram", {
    kind   = "callback",
    color  = { 1.0, 1.0, 1.0, 1.0 },
    alpha  = 0.5,
    radius = 14,
    pulse  = { speed = 2.0, min = 0.20, max = 1.0 },
    draw   = function(alpha, time, spec)
      love.graphics.setFont(AssetManifest.getFont(72))
      love.graphics.printf(
        "RAM: " .. tostring(#areas.pool.chips),
        areas.pool.x,
        areas.pool.y + areas.pool.h / 4,
        areas.pool.w,
        "center"
      )
    end,
  })

  if draggingCard.zoneState == "play" then
    M.requestPlayZoneGlows(glow, draggingCard, deck)
  elseif draggingCard.zoneState == "discard" then
    M.requestDiscardZoneGlows(glow, draggingCard)
  end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Master orchestrator — call once per frame from love.update
-- ──────────────────────────────────────────────────────────────────────────────

function M.collectAll(glow, hand, deck)
  areas.pool.insufficientRam = false

  -- Find dragging card first so we can gate bar pulsing before emitting glows.
  local draggingCard = nil
  for _, card in ipairs(hand.cards) do
    if card.drag.is then draggingCard = card; break end
  end

  -- Count negative tokens in the active drag zone — only those affect existing ticks.
  local progressNegCount = 0
  local threatNegCount   = 0
  if draggingCard then
    local zone = draggingCard.zoneState == "play"    and "playEffect"
              or draggingCard.zoneState == "discard" and "discardEffect"
    if zone then
      local n = draggingCard._slotCounts and draggingCard._slotCounts[zone] or 0
      for i = 1, n do
        local slot = draggingCard._slots[zone] and draggingCard._slots[zone][i]
        local t    = slot and slot.token and slot.token.token_type
        if t == "progressNegative" then progressNegCount = progressNegCount + 1 end
        if t == "threatNegative"   then threatNegCount   = threatNegCount   + 1 end
      end
    end
  end

  if progressNegCount > 0 and _progressNegStartT == nil then
    _progressNegStartT = pulse.getTime()
  elseif progressNegCount == 0 then
    _progressNegStartT = nil
  end
  if threatNegCount > 0 and _threatNegStartT == nil then
    _threatNegStartT = pulse.getTime()
  elseif threatNegCount == 0 then
    _threatNegStartT = nil
  end

  progressBar.setTickPulseCount(progressNegCount)
  threatBar.setTickPulseCount(threatNegCount)

  M.requestProgressGlows(glow)
  M.requestThreatGlows(glow)
  M.requestEnvGlows(glow)
  M.requestDtorTextGlow(glow)
  hover.collectGlowRequests(glow)

  -- Post-rejection insufficient RAM feedback.
  if areas.pool.insufficientRamTimer > 0 then
    areas.pool.insufficientRam = true
    local fadeAlpha = math.min(1.0, areas.pool.insufficientRamTimer / areas.RAM_FADE_TIME)
    glow:request("ram-zone-text:insufficient", {
      kind  = "callback",
      color = Palette.warning,
      alpha = 0.9 * fadeAlpha,
      pulse = { speed = 3.0, min = 0.5, max = 1.0 },
      draw  = function(alpha, time, spec)
        love.graphics.setFont(AssetManifest.getFont(72))
        love.graphics.printf(
          "Insufficient RAM",
          areas.pool.x,
          areas.pool.y + areas.pool.h / 4 + 100 * SCALE_Y,
          areas.pool.w,
          "center"
        )
      end,
    })
  end

  if draggingCard then
    requestDragZoneGlows(glow, draggingCard, deck)
  end
end

return M
