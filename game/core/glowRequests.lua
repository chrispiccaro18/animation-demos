local areas   = require("core.areas")
local Dtor    = require("core.dtor")
local Palette = require("lib.palette")

local M = {}

local TOKEN_PALETTE_KEYS = {
  progress         = "positive",
  progressNegative = "positiveNeg",
  threat           = "danger",
  threatNegative   = "dangerNeg",
  nullify          = "nullify",
  ram              = "energy",
  drawToHand       = "draw",
  dtor             = "warning",
  shuffle          = "warning",
  drawToDtor       = "warning",
}

-- Emits a border-rect glow for each occupied slot in `zone` on `card`.
-- `keyPrefix` becomes the glow item key (e.g. "card-slot-play").
-- Returns seenTypes { [tokenType] = true } for use with requestTerminalGlows.
function M.requestSlotGlows(glow, card, zone, keyPrefix)
  local n = card._slotCounts and card._slotCounts[zone] or 0
  local seenTypes = {}
  for i = 1, n do
    local rect      = card:getSlotCanvasRect(zone, i)
    local slot      = card._slots[zone] and card._slots[zone][i]
    local tokenType = slot and slot.token and slot.token.token_type
    local color     = Palette[TOKEN_PALETTE_KEYS[tokenType]] or Palette.accent
    if rect then
      glow:request(keyPrefix .. ":" .. i, {
        kind     = "rect",
        x        = rect.cx - rect.w / 2,
        y        = rect.cy - rect.h / 2,
        w        = rect.w,
        h        = rect.h,
        rotation = card.current.r,
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
      x     = areas.progressDestination.x - terminalSize / 2,
      y     = areas.progressDestination.y - terminalSize / 2,
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
      x            = areas.threatDestination.x - terminalSize / 2,
      y            = areas.threatDestination.y - terminalSize / 2,
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
        x     = slot.x - terminalSize / 2,
        y     = slot.y - terminalSize / 2,
        w     = Dtor.area.w,
        h     = terminalSize,
        color = Palette[TOKEN_PALETTE_KEYS["nullify"]],
        alpha = 0.7,
        pulse = { speed = 2.0, min = 0.0, max = 1.0 },
        light = { radius = 30 * SCALE_X, alpha = 0.3 },
      })
    end
  end

  if seenTypes["ram"] then
    glow:request("terminal:ram", {
      kind  = "rect",
      x     = areas.pool.x,
      y     = areas.pool.y,
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
      x     = deck.x - terminalSize / 2,
      y     = deck.y - terminalSize / 2,
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
      x     = Dtor.area.x,
      y     = Dtor.area.y,
      w     = Dtor.area.w,
      h     = Dtor.area.h,
      color = Palette[TOKEN_PALETTE_KEYS["dtor"]],
      alpha = 0.5,
      pulse = { speed = 2.0, min = 0.0, max = 1.0 },
      -- light = { radius = 30 * SCALE_X, alpha = 0.3 },
    })
  end
end

-- Slot glows for the play effect zone + terminal destination glows.
function M.requestPlayZoneGlows(glow, card, deck)
  local seenTypes = M.requestSlotGlows(glow, card, "playEffect", "card-slot-play")
  M.requestTerminalGlows(glow, seenTypes, deck)
end

-- Slot glows for the discard effect zone + terminal destination glows.
-- No deck needed: drawToHand tokens don't appear on discard-zone cards.
function M.requestDiscardZoneGlows(glow, card)
  local seenTypes = M.requestSlotGlows(glow, card, "discardEffect", "card-slot-discard")
  M.requestTerminalGlows(glow, seenTypes, nil)
end

return M
