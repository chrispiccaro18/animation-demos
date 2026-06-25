local AssetManifest = require("assets.manifest")
local Token     = require("core.token")
local animation = require("lib.animation")
local Color = require("lib.color")

local Dtor = {}

-- Public: position + slot state — initialized in Dtor.load()
Dtor.area = {}

local _queue            = {}
local _transitCard      = nil
local _dtorSlotAsset    = nil
local _emptyNullifySlot = nil
local _tokenAssets      = {}
local _font             = nil

-- Layout initialized in Dtor.load()
local _text = {}

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
  Dtor.area = {
    x        = 3194 * SCALE_X,
    y        = 639  * SCALE_Y,
    w        = 494  * SCALE_X,
    h        = 1088 * SCALE_Y,
    maxSlots = 6,
    slots    = {},
  }
  _text = {
    x           = 2176 * SCALE_X,
    y           = 448  * SCALE_Y,
    w           = 1095 * SCALE_X,
    h           = 80   * SCALE_Y,
    content     = "",
    alpha       = 0,
    targetAlpha = 0,
  }
  for i = 1, Dtor.area.maxSlots do
    Dtor.area.slots[i] = { occupied = false, reserved = false, nullified = false }
  end
  _dtorSlotAsset = AssetManifest.get("card", "dtorSlot")
  _emptyNullifySlot = AssetManifest.get("card", "emptyNullifySlot")
  _tokenAssets = {
    threat   = AssetManifest.get("tokens", "threat"),
    progress = AssetManifest.get("tokens", "progress"),
    nullify  = AssetManifest.get("tokens", "nullify"),
    ram      = AssetManifest.get("tokens", "ram"),
    progressNegative = AssetManifest.get("tokens", "progressNegative"),
    threatNegative = AssetManifest.get("tokens", "threatNegative"),
    shuffle         = AssetManifest.get("tokens", "shuffle"),
    drawToDtor      = AssetManifest.get("tokens", "drawToDtor"),
    drawToHand      = AssetManifest.get("tokens", "drawToHand"),
  }
  _font = AssetManifest.getFont(72)
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
    local s = dq.slots[i]
    if s and not s.occupied and not s.reserved then
      s.reserved = true
      return { x = dq.x + dq.w / 2, y = dq.y + (i - 0.5) * slotH, index = i }
    end
  end
  -- Overflow: all visual slots full; reserve a logical slot beyond maxSlots
  local i = dq.maxSlots + 1
  while i <= dq.maxSlots + 50 do
    if not dq.slots[i] then
      dq.slots[i] = { occupied = false, reserved = false, nullified = false }
    end
    if not dq.slots[i].occupied and not dq.slots[i].reserved then
      dq.slots[i].reserved = true
      -- Animate to last visual slot position
      return { x = dq.x + dq.w / 2, y = dq.y + (dq.maxSlots - 0.5) * slotH, index = i }
    end
    i = i + 1
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
-- Compute a shuffled permutation of occupied dtor slots (80% bias for
-- top slot to change), mark all involved slots in-transit, update queue
-- entry slotIndices, re-sort the queue top-to-bottom, and return an
-- array of move descriptors for the caller to animate.
-- Returns nil when there are 1 or fewer occupied slots.
------------------------------------------------------------------------
function Dtor.beginShuffle()
  local dq    = Dtor.area
  local slotH = dq.h / dq.maxSlots

  -- Flat list of every occupied slot with ownership metadata
  local occupied = {}
  for entryIdx, entry in ipairs(_queue) do
    for withinIdx, slotIdx in ipairs(entry.slotIndices) do
      if dq.slots[slotIdx] and dq.slots[slotIdx].occupied then
        local subTokens = {}
        for _, eff in ipairs(entry.card.data.dtor or {}) do
          table.insert(subTokens, eff.type)
        end
        table.insert(occupied, {
          slotIdx   = slotIdx,
          entryIdx  = entryIdx,
          withinIdx = withinIdx,
          scale     = dq.slots[slotIdx].scale,
          subTokens = subTokens,
        })
      end
    end
  end

  if #occupied <= 1 then return nil end

  -- Fisher-Yates shuffle of destination slot indices
  local toIndices = {}
  for _, o in ipairs(occupied) do table.insert(toIndices, o.slotIdx) end
  for i = #toIndices, 2, -1 do
    local j = math.random(1, i)
    toIndices[i], toIndices[j] = toIndices[j], toIndices[i]
  end
  -- 80% bias: force the top slot to receive a different token
  if math.random() < 0.8 and toIndices[1] == occupied[1].slotIdx then
    local swapWith = math.random(2, #toIndices)
    toIndices[1], toIndices[swapWith] = toIndices[swapWith], toIndices[1]
  end

  -- Mark all occupied slots as in-transit (suppresses static drawing)
  for _, o in ipairs(occupied) do
    dq.slots[o.slotIdx].occupied = false
    dq.slots[o.slotIdx].reserved = true
  end

  -- Build move descriptors and update queue entry slot indices
  local moves = {}
  for i, o in ipairs(occupied) do
    local toIdx = toIndices[i]
    _queue[o.entryIdx].slotIndices[o.withinIdx] = toIdx
    local fromVisIdx = math.min(o.slotIdx, dq.maxSlots)
    local toVisIdx   = math.min(toIdx,     dq.maxSlots)
    table.insert(moves, {
      fromX     = dq.x + dq.w / 2,
      fromY     = dq.y + (fromVisIdx - 0.5) * slotH,
      toX       = dq.x + dq.w / 2,
      toY       = dq.y + (toVisIdx   - 0.5) * slotH,
      toIdx     = toIdx,
      scale     = o.scale,
      subTokens = o.subTokens,
    })
  end

  -- Re-sort queue so end-turn processes entries top-to-bottom
  table.sort(_queue, function(a, b)
    return (a.slotIndices[1] or math.huge) < (b.slotIndices[1] or math.huge)
  end)
  _updateTextContent()

  return moves
end

function Dtor.topSlot()
  local dq    = Dtor.area
  local slotH = dq.h / dq.maxSlots
  return { x = dq.x + dq.w / 2, y = dq.y + (1 - 0.5) * slotH, index = 1 }
end

------------------------------------------------------------------------
-- Text visibility
------------------------------------------------------------------------
function Dtor.setTransitCard(card)
  _transitCard = card
end

function Dtor.clearTransitCard()
  _transitCard = nil
end

function Dtor.reset()
  _queue        = {}
  _transitCard  = nil
  _text.content     = ""
  _text.alpha       = 0
  _text.targetAlpha = 0
  Dtor.area.slots = {}
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
  if _transitCard then _transitCard:update() end
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
        local oldVisY   = dq.y + (math.min(oldIdx,   dq.maxSlots) - 0.5) * slotH
        local newVisY   = dq.y + (math.min(nextSlot, dq.maxSlots) - 0.5) * slotH

        if oldVisY ~= newVisY then
          -- Visible animation (covers visible→visible and overflow→visible)
          local capturedN = nextSlot
          local subTokens = {}
          for _, effect in ipairs(entry.card.data.dtor or {}) do
            table.insert(subTokens, effect.type)
          end
          if not dq.slots[capturedN] then
            dq.slots[capturedN] = { occupied = false, reserved = false, nullified = false }
          end
          dq.slots[capturedN].reserved = true
          Dtor.releaseSlot(oldIdx)
          Token.new_attract(
            dq.x + dq.w / 2, oldVisY,
            dq.x + dq.w / 2, newVisY,
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
        else
          -- Overflow→overflow: both map to the same visual position; update index silently
          Dtor.releaseSlot(oldIdx)
          if not dq.slots[nextSlot] then
            dq.slots[nextSlot] = { occupied = false, reserved = false, nullified = false }
          end
          dq.slots[nextSlot].occupied  = true
          dq.slots[nextSlot].reserved  = false
          dq.slots[nextSlot].scale     = slotScale
          dq.slots[nextSlot].nullified = slotNullif
        end
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

  -- Count occupied slots including any overflow beyond maxSlots
  local totalOccupied = 0
  local overflowDots  = 0
  for i, slot in pairs(dq.slots) do
    if type(i) == "number" and slot.occupied then
      totalOccupied = totalOccupied + 1
      if i >= dq.maxSlots then overflowDots = overflowDots + 1 end
    end
  end
  local isOverflow = totalOccupied > dq.maxSlots

  for entryIdx, entry in ipairs(_queue) do
    for _, idx in ipairs(entry.slotIndices) do
      local slot = dq.slots[idx]
      -- In overflow mode, only draw slots strictly inside the visual range (< maxSlots)
      if slot and slot.occupied and (not isOverflow or idx < dq.maxSlots) then
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

  -- Overflow dot indicator: shown in last visual slot when total > maxSlots
  if isOverflow and overflowDots > 0 then
    local sx    = dq.x + dq.w / 2
    local sy    = dq.y + (dq.maxSlots - 0.5) * slotH
    local dotR  = 22 * SCALE_X
    local gap   = dotR * 2.8
    love.graphics.setColor(Color("#ff8b00", 1))
    for d = 1, overflowDots do
      local offset = (d - (overflowDots + 1) / 2) * gap
      love.graphics.circle("fill", sx + offset, sy, dotR)
    end
  end

  -- Pre-nullified empty slots: render at their actual fixed index
  if _emptyNullifySlot then
    local ew, eh = _emptyNullifySlot:getDimensions()
    for i = 1, dq.maxSlots do
      local slot = dq.slots[i]
      if slot and slot.nullified and not slot.occupied then
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

  if _transitCard then _transitCard:draw() end

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setLineWidth(1)
end

return Dtor
