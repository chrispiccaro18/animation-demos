local areas   = require("core.areas")
local Dtor    = require("core.dtor")
local Palette = require("lib.palette")

local M = {}

local TOKEN_PALETTE_KEYS = {
  progress         = "positive",
  progressNegative = "positiveNeg",
  threat           = "danger",
  threatNegative   = "danger",
  nullify          = "nullify",
  ram              = "energy",
  drawToHand       = "draw",
  dtor             = "warning",
  shuffle          = "warning",
  drawToDtor       = "warning",
}

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
    if tokenType =="ram" then
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
      })
    end
    if tokenType then seenTypes[tokenType] = true end
  end
  return seenTypes
end

-- Emits terminal destination glow rects based on seenTypes from requestSlotGlows.
-- `deck` is optional; omit (or pass nil) when drawToHand terminal is not relevant.
function M.requestTerminalGlows(glow, seenTypes, deck)
  local terminalSize = 100 * SCALE_X

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

-- Slot glows for the play effect zone + terminal destination glows.
function M.requestPlayZoneGlows(glow, card, deck)
  local seenTypes = M.requestSlotGlows(glow, card, "playEffect", "card-slot-play")
  M.requestTerminalGlows(glow, seenTypes, deck)
end

-- Slot glows for all discard-visible zones (discardEffect, dtorEffect, bottomEnergy)
-- + terminal destination glows. No deck needed: drawToHand tokens don't appear here.
function M.requestDiscardZoneGlows(glow, card)
  local seenTypes = {}
  local function merge(t) for k, v in pairs(t) do seenTypes[k] = v end end

  merge(M.requestSlotGlows(glow, card, "discardEffect", "card-slot-discard"))
  merge(M.requestSlotGlows(glow, card, "bottomEnergy",  "card-slot-energy", math.pi / 4))

  -- dtorEffect: one wide rect for the whole background (dtor token as unit), not individual sub-slots.
  -- The zone always routes to terminal:dtor regardless of the payload types inside.
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
    })
  end

  M.requestTerminalGlows(glow, seenTypes, nil)
end

return M
