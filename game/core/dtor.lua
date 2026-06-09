local areas = require("core.areas")
local Token = require("core.token")

local Dtor = {}

local _queue         = {}
local _dtorSlotAsset = nil
local _tokenAssets   = {}

function Dtor.load()
  _dtorSlotAsset = love.graphics.newImage("assets/proto/dtor-slot.png", { mipmaps = true })
  _tokenAssets = {
    threat   = love.graphics.newImage("assets/proto/threat-token.png",   { mipmaps = true }),
    progress = love.graphics.newImage("assets/proto/progress-token.png", { mipmaps = true }),
    nullify  = love.graphics.newImage("assets/proto/nullify-token.png",  { mipmaps = true }),
    ram      = love.graphics.newImage("assets/proto/ram-chip.png",       { mipmaps = true }),
  }
end

function Dtor.register(card, slotIndices)
  table.insert(_queue, { card = card, slotIndices = slotIndices })
end

function Dtor.hasEntry()
  return #_queue > 0
end

function Dtor.popEntry()
  return table.remove(_queue, 1)
end

------------------------------------------------------------------------
-- Animate remaining entries sliding up to fill from slot 1.
-- Releases each old slot, creates a Token.new_attract to the new
-- position, and on arrival re-claims the slot then self-removes.
------------------------------------------------------------------------
function Dtor.compactSlots()
  if #_queue == 0 then return end
  local dq    = areas.dtorQueue
  local slotH = dq.h / dq.maxSlots

  local nextSlot = 1
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
        areas.releaseDtorSlot(oldIdx)
        Token.new_attract(
          oldSx, oldSy,
          dq.x + dq.w / 2, newSy,
          {
            type          = "dtor",
            base_scale    = slotScale or 1,
            subTokens     = subTokens,
            initial_speed = 100 * SCALE_X,
            acceleration  = 200 * SCALE_X,
            onArrive      = function(t)
              dq.slots[capturedN].occupied  = true
              dq.slots[capturedN].reserved  = false
              dq.slots[capturedN].scale     = slotScale
              dq.slots[capturedN].nullified = slotNullif
              Token.removeSingle(t)
            end,
          }
        )
      end

      table.insert(newIndices, nextSlot)
      nextSlot = nextSlot + 1
    end
    entry.slotIndices = newIndices
  end
end

------------------------------------------------------------------------
-- Draw dtor-slot.png as background for each entry, with the card's
-- individual token types distributed on top.
------------------------------------------------------------------------
function Dtor.drawAll()
  if not _dtorSlotAsset then return end
  local dq    = areas.dtorQueue
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
        love.graphics.draw(_dtorSlotAsset, 0, 0, 0, 1, 1, sw / 2, sh / 2)

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

    if entryIdx < #_queue and #entry.slotIndices > 0 then
      local lastIdx = entry.slotIndices[#entry.slotIndices]
      local sepY    = dq.y + lastIdx * slotH + slotH * 0.1
      love.graphics.setColor(1, 0.3, 0.3, 0.5)
      love.graphics.setLineWidth(1.5 * SCALE_Y)
      love.graphics.line(dq.x + 4 * SCALE_X, sepY, dq.x + dq.w - 4 * SCALE_X, sepY)
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setLineWidth(1)
end

return Dtor
