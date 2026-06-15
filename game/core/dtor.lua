local animation = require("lib.animation")
local Token     = require("core.token")
local Color = require("lib.color")

local W = SCALE_X * 3840
local H = SCALE_Y * 2160

local Dtor = {}

-- Public: position + slot state (replaces areas.dtorQueue)
Dtor.area = {
  x        = 3194 * W / 3840,
  y        = 639  * H / 2160,
  w        = 494  * W / 3840,
  h        = 1088 * H / 2160,
  maxSlots = 6,
  slots    = {},
}

local _queue            = {}
local _dtorSlotAsset    = nil
local _emptyNullifySlot = nil
local _tokenAssets      = {}
local _font             = nil

local _text = {
  x           = 2176 * W / 3840,
  y           = 448  * H / 2160,
  w           = 1095 * W / 3840,
  h           = 80   * H / 2160,
  content     = "",
  alpha       = 0,
  targetAlpha = 0,
}

------------------------------------------------------------------------
-- Private: rebuild text from the current top queue entry
------------------------------------------------------------------------
local function _updateTextContent()
  if #_queue == 0 then
    _text.content = ""
    return
  end
  local effects = _queue[1].card.data.dtor
  if not effects or #effects == 0 then
    _text.content = ""
    return
  end
  local counts = {}
  local order  = {}
  for _, effect in ipairs(effects) do
    local t = effect.type:upper()
    if not counts[t] then
      counts[t] = 0
      table.insert(order, t)
    end
    counts[t] = counts[t] + 1
  end
  local parts = {}
  for _, t in ipairs(order) do
    if counts[t] > 1 then
      table.insert(parts, counts[t] .. " " .. t)
    else
      table.insert(parts, t)
    end
  end
  _text.content = table.concat(parts, "  ·  ")
end

------------------------------------------------------------------------

function Dtor.load()
  for i = 1, Dtor.area.maxSlots do
    Dtor.area.slots[i] = { occupied = false, reserved = false, nullified = false }
  end
  _dtorSlotAsset = love.graphics.newImage("assets/proto/dtor-slot.png")
  _emptyNullifySlot = love.graphics.newImage("assets/proto/empty-nullify-dtor.png")
  _tokenAssets = {
    threat   = love.graphics.newImage("assets/proto/threat-token.png"),
    progress = love.graphics.newImage("assets/proto/progress-token.png"),
    nullify  = love.graphics.newImage("assets/proto/nullify-token.png"),
    ram      = love.graphics.newImage("assets/proto/ram-chip.png"),
  }
  _font = love.graphics.newFont("assets/NotoSans-Medium.ttf", 36)
end

------------------------------------------------------------------------
-- Entry queue
------------------------------------------------------------------------
function Dtor.register(card, slotIndices)
  table.insert(_queue, { card = card, slotIndices = slotIndices })
  _updateTextContent()
end

function Dtor.hasEntry()
  return #_queue > 0
end

function Dtor.peekEntry()
  return _queue[1]
end

function Dtor.popEntry()
  local entry = table.remove(_queue, 1)
  _updateTextContent()
  return entry
end

function Dtor.isEntryNullified(index)
  local entry = _queue[index or 1]
  if not entry or not entry.slotIndices or #entry.slotIndices == 0 then return false end
  local slotIdx = entry.slotIndices[1]
  return Dtor.area.slots[slotIdx] and Dtor.area.slots[slotIdx].nullified
end

------------------------------------------------------------------------
-- Slot management (replaces areas.reserveDtorSlot / claimDtorSlot etc.)
------------------------------------------------------------------------
function Dtor.reserveSlot()
  local dq    = Dtor.area
  local slotH = dq.h / dq.maxSlots
  for i = 1, dq.maxSlots do
    if not dq.slots[i].occupied and not dq.slots[i].reserved then
      dq.slots[i].reserved = true
      return {
        x     = dq.x + dq.w / 2,
        y     = dq.y + (i - 0.5) * slotH,
        index = i,
      }
    end
  end
  return nil
end

function Dtor.claimSlot(index, scale)
  local slot = Dtor.area.slots[index]
  if slot then
    slot.reserved = false
    slot.occupied = true
    slot.scale    = scale or 1
  end
end

function Dtor.releaseSlot(index)
  local slot = Dtor.area.slots[index]
  if slot then
    slot.occupied  = false
    slot.reserved  = false
    slot.nullified = false
    slot.scale     = nil
  end
end

function Dtor.nextUnnullifiedSlot()
  local dq    = Dtor.area
  local slotH = dq.h / dq.maxSlots
  for i = 1, dq.maxSlots do
    if dq.slots[i].occupied and not dq.slots[i].nullified then
      return { x = dq.x + dq.w / 2, y = dq.y + (i - 0.5) * slotH, index = i }
    end
  end
  for i = 1, dq.maxSlots do
    if not dq.slots[i].occupied and not dq.slots[i].reserved and not dq.slots[i].nullified then
      return { x = dq.x + dq.w / 2, y = dq.y + (i - 0.5) * slotH, index = i }
    end
  end
  return nil
end

function Dtor.nullifyNextSlot()
  local dq = Dtor.area
  for i = 1, dq.maxSlots do
    if dq.slots[i].occupied and not dq.slots[i].nullified then
      dq.slots[i].nullified = true; return
    end
  end
  for i = 1, dq.maxSlots do
    if not dq.slots[i].occupied and not dq.slots[i].reserved and not dq.slots[i].nullified then
      dq.slots[i].nullified = true; return
    end
  end
end

------------------------------------------------------------------------
-- Text visibility
------------------------------------------------------------------------
function Dtor.reset()
  _queue = {}
  _text.content     = ""
  _text.alpha       = 0
  _text.targetAlpha = 0
  for i = 1, Dtor.area.maxSlots do
    Dtor.area.slots[i] = { occupied = false, reserved = false, nullified = false }
  end
end

function Dtor.showText()
  _text.targetAlpha = 1
end

function Dtor.hideText()
  _text.targetAlpha = 0
end

function Dtor.getTextCenter()
  return _text.x + _text.w / 2, _text.y + _text.h / 2
end

------------------------------------------------------------------------
-- Update — tick text alpha animation
------------------------------------------------------------------------
function Dtor.update(dt)
  _text.alpha = animation.expDecay(_text.alpha, _text.targetAlpha, 12, dt)
end

------------------------------------------------------------------------
-- Animate remaining entries sliding up to fill from slot 1.
------------------------------------------------------------------------
function Dtor.compactSlots()
  local dq    = Dtor.area
  local slotH = dq.h / dq.maxSlots

  local nextSlot = 1

  -- Pass 1: compact occupied queue-entry slots
  local acc1 = Token.makeCascadeAccumulator(0.08)
  for _, entry in ipairs(_queue) do
    local newIndices = {}
    for _, oldIdx in ipairs(entry.slotIndices) do
      local slotScale  = dq.slots[oldIdx] and dq.slots[oldIdx].scale
      local slotNullif = dq.slots[oldIdx] and dq.slots[oldIdx].nullified

      if oldIdx ~= nextSlot then
        local oldSx     = dq.x + dq.w / 2
        local oldSy     = dq.y + (oldIdx - 0.5) * slotH
        local newSy     = dq.y + (nextSlot - 0.5) * slotH
        local capturedN = nextSlot
        local subTokens = {}
        for _, effect in ipairs(entry.card.data.dtor or {}) do
          table.insert(subTokens, effect.type)
        end
        dq.slots[capturedN].reserved = true
        Dtor.releaseSlot(oldIdx)
        Token.new_attract(
          oldSx, oldSy,
          dq.x + dq.w / 2, newSy,
          acc1:next({
            type             = slotNullif and "dtor_null" or "dtor",
            base_scale       = slotScale or 1,
            subTokens        = slotNullif and nil or subTokens,
            initial_speed    = 100 * SCALE_X,
            acceleration     = 200 * SCALE_X,
            no_anticipation  = true,
            onArrive      = function(t)
              dq.slots[capturedN].occupied  = true
              dq.slots[capturedN].reserved  = false
              dq.slots[capturedN].scale     = slotScale
              dq.slots[capturedN].nullified = slotNullif
              Token.removeSingle(t)
            end,
          })
        )
      end

      table.insert(newIndices, nextSlot)
      nextSlot = nextSlot + 1
    end
    entry.slotIndices = newIndices
  end

  -- Pass 2: compact pre-nullified empty slots
  local acc2 = Token.makeCascadeAccumulator(0.08)
  for i = 1, dq.maxSlots do
    if dq.slots[i].nullified and not dq.slots[i].occupied and not dq.slots[i].reserved then
      if i ~= nextSlot then
        local capturedN = nextSlot
        dq.slots[capturedN].reserved = true
        dq.slots[i].nullified = false
        Token.new_attract(
          dq.x + dq.w / 2, dq.y + (i - 0.5) * slotH,
          dq.x + dq.w / 2, dq.y + (nextSlot - 0.5) * slotH,
          acc2:next({
            type            = "dtor_null",
            base_scale      = 1.5,
            initial_speed   = 100 * SCALE_X,
            acceleration    = 200 * SCALE_X,
            no_anticipation = true,
            onArrive      = function(t)
              dq.slots[capturedN].nullified = true
              dq.slots[capturedN].reserved  = false
              Token.removeSingle(t)
            end,
          })
        )
      end
      nextSlot = nextSlot + 1
    end
  end
end

------------------------------------------------------------------------
-- Draw slots + text
------------------------------------------------------------------------
function Dtor.drawAll()
  if not _dtorSlotAsset then return end
  local dq    = Dtor.area
  local slotH = dq.h / dq.maxSlots
  local sw, sh = _dtorSlotAsset:getDimensions()

  for entryIdx, entry in ipairs(_queue) do
    for _, idx in ipairs(entry.slotIndices) do
      local slot = dq.slots[idx]
      if slot and slot.occupied then
        local sx = dq.x + dq.w / 2
        local sy = dq.y + (idx - 0.5) * slotH
        local sc = (slot.scale or 1) * SCALE_X * 0.3

        love.graphics.push()
        love.graphics.translate(sx, sy)
        love.graphics.scale(sc, sc)

        love.graphics.setColor(1, 1, 1, 1)
        local slotAsset = slot.nullified and _emptyNullifySlot or _dtorSlotAsset
        love.graphics.draw(slotAsset, 0, 0, 0, 1, 1, sw / 2, sh / 2)

        local effects = entry.card.data.dtor
        if effects and #effects > 0 then
          local n          = #effects
          local tokenSlotW = sw / n
          for i, effect in ipairs(effects) do
            local asset = _tokenAssets[effect.type]
            if asset then
              local tw, th = asset:getDimensions()
              local s  = math.min(tokenSlotW / tw, sh / th) * 0.85
              local cx = (i - 0.5) * tokenSlotW - sw / 2
              love.graphics.draw(asset, cx, 0, 0, s, s, tw / 2, th / 2)
            end
          end
        end

        love.graphics.pop()
      end
    end

    -- if entryIdx < #_queue and #entry.slotIndices > 0 then
    --   local lastIdx = entry.slotIndices[#entry.slotIndices]
    --   local sepY    = dq.y + lastIdx * slotH + slotH * 0.1
    --   love.graphics.setColor(1, 0.3, 0.3, 0.5)
    --   love.graphics.setLineWidth(1.5 * SCALE_Y)
    --   love.graphics.line(dq.x + 4 * SCALE_X, sepY, dq.x + dq.w - 4 * SCALE_X, sepY)
    -- end
  end

  -- Pre-nullified empty slots: render at their actual fixed index
  if _emptyNullifySlot then
    local ew, eh = _emptyNullifySlot:getDimensions()
    for i = 1, dq.maxSlots do
      local slot = dq.slots[i]
      if slot.nullified and not slot.occupied then
        local sx = dq.x + dq.w / 2
        local sy = dq.y + (i - 0.5) * slotH
        local sc = 1.5 * SCALE_X * 0.3
        love.graphics.push()
        love.graphics.translate(sx, sy)
        love.graphics.scale(sc, sc)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(_emptyNullifySlot, 0, 0, 0, 1, 1, ew / 2, eh / 2)
        love.graphics.pop()
      end
    end
  end

  -- Text overlay
  if _text.alpha > 0.01 and _text.content ~= "" and _font then
    local isTopEntryNullified = Dtor.isEntryNullified()
    -- local isTopEntryNullified = _queue[1] and _queue[1].slotIndices and #_queue[1].slotIndices > 0 and Dtor.area.slots[_queue[1].slotIndices[1]] and Dtor.area.slots[_queue[1].slotIndices[1]].nullified
    love.graphics.setColor(Color("#D56E6E", _text.alpha))
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(_font)
    love.graphics.printf(_text.content, _text.x, _text.y + (_text.h - _font:getHeight()) / 2, _text.w, "center")
    love.graphics.setFont(prevFont)
    if isTopEntryNullified then
      love.graphics.setColor(Color("#FF8C00", _text.alpha))
      love.graphics.setLineWidth(8 * SCALE_X)
      love.graphics.line(_text.x + 20 * SCALE_X, _text.y + _text.h / 2, _text.x + _text.w - 20 * SCALE_X, _text.y + _text.h / 2)
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setLineWidth(1)
end

return Dtor
