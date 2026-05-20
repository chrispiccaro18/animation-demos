local areas     = require("core.areas")
local sequences = require("core.sequences")
local events    = require("lib.events")

local Hand = {}
Hand.__index = Hand

function Hand.new()
  return setmetatable({ cards = {}, lastDiscarded = nil }, Hand)
end

function Hand:layout()
  local gap = 20
  local active = {}
  for _, card in ipairs(self.cards) do
    if not card._excluded then active[#active + 1] = card end
  end
  local cardW = active[1] and active[1].w or 0
  local totalW = #active * cardW + math.max(#active - 1, 0) * gap
  local startX = (love.graphics.getWidth() - totalW) / 2
  local startY = love.graphics.getHeight() - 310

  for i, card in ipairs(active) do
    card._startX = startX + (i - 1) * (cardW + gap)
    card._startY = startY
    card.target.x = card._startX
    card.target.y = card._startY
  end
end

function Hand:add(card, snap, layout)
  self.cards[#self.cards + 1] = card
  if layout == nil then layout = true end
  if layout then self:layout() end

  -- self:layout()
  if snap then
    card.current.x = card._startX
    card.current.y = card._startY
  end
end

function Hand:remove(card)
  for i, c in ipairs(self.cards) do
    if c == card then
      table.remove(self.cards, i)
      break
    end
  end
  card._excluded = false
  self:layout()
end

function Hand:isDragging()
  for _, card in ipairs(self.cards) do
    if card.drag.is then return true end
  end
  return false
end

function Hand:unlockHand()
  for _, card in ipairs(self.cards) do
    card.hover.can = true
    card.hover.is  = false
    card.target.scale = 0.95
    card.drag.can  = true
    card.drag.is   = false
  end
end

function Hand:update(mouseX, mouseY)
  local draggingCard = nil
  for _, card in ipairs(self.cards) do
    if card.drag.is then draggingCard = card; break end
  end

  -- Suppress hover on siblings while a card is being dragged
  if draggingCard then
    for _, card in ipairs(self.cards) do
      if card ~= draggingCard then
        card.hover.can    = false
        card.hover.is     = false
        card.target.scale = 0.95
      end
    end
  end

  -- Update area highlight colors
  if areas.mouseInPlay(mouseX, mouseY) and draggingCard then
    areas.play.color = {0.5, 0.5, 1, 1}
  elseif draggingCard and areas.cardInPlay(draggingCard) then
    areas.play.color = {0.5, 0.5, 0.5, 1}
    -- areas.play.color = {1, 1, 1, 1}
  elseif areas.mouseInPlay(mouseX, mouseY) then
    areas.play.color = {0.5, 0.5, 0.5, 1}
    -- areas.play.color = {0.5, 1, 0.5, 1}
  else
    areas.play.color = {0.5, 0.5, 0.5, 1}
  end

  if areas.mouseInDiscard(mouseX, mouseY) and draggingCard then
    areas.discard.color = {0.5, 0.5, 1, 1}
  elseif draggingCard and areas.cardInDiscard(draggingCard) then
    areas.discard.color = {0.5, 0.5, 0.5, 1}
    -- areas.discard.color = {1, 1, 1, 1}
  elseif areas.mouseInDiscard(mouseX, mouseY) then
    areas.discard.color = {0.5, 0.5, 0.5, 1}
    -- areas.discard.color = {0.5, 1, 0.5, 1}
  else
    areas.discard.color = {0.5, 0.5, 0.5, 1}
  end

  for _, card in ipairs(self.cards) do
    -- Release drag
    if card.drag.is and not love.mouse.isDown(1) then
      card.drag.is  = false
      card.drag.can = true
      card._excluded = true
      self:layout()
      if areas.mouseInPlay(mouseX, mouseY) then
        if #areas.pool.chips < 2 then
          screenshake.triggerH()
          card._excluded = false
          self:layout()
          card.target.x = card._startX
          card.target.y = card._startY
        else
          sequences.play(card, areas,
            function()
              -- self:unlockHand()
            end,
            function()
              self:remove(card)
              -- self:unlockHand()
            end
          )
        end
      elseif areas.mouseInDiscard(mouseX, mouseY) then
        self.lastDiscarded = card
        -- c._excluded = true
        -- self:layout()
        sequences.discard(card, areas,
          function()
            self:unlockHand()
          end,
          function()
            self:remove(card)
            -- self:unlockHand()
          end
        )
      else
        card.target.x = card._startX
        card.target.y = card._startY
        card._excluded = false
        self:layout()
      end
      self:unlockHand()

    end

    -- Follow mouse while dragging
    if card.drag.is then
      card.target.x = mouseX - card.drag.offsetX
      card.target.y = mouseY - card.drag.offsetY
    end

    -- Hover scale
    if card.hover.can and not card.drag.is and card:containsPoint(mouseX, mouseY) then
      card.hover.is     = true
      card.target.scale = 1.05
      card.mouseX = mouseX
      card.mouseY = mouseY
    elseif card:containsPoint(mouseX, mouseY) and card.drag.is then
      card.target.scale = 1.125
    elseif not card:containsPoint(mouseX, mouseY) and not card.drag.is and card.hover.can then
      card.hover.is     = false
      card.target.scale = 0.95
    end

    card:update()
  end
end

function Hand:draw()
  for _, card in ipairs(self.cards) do
    if not card.drag.is then card:draw() end
  end
  for _, card in ipairs(self.cards) do
    if card.drag.is then card:draw() end
  end
end

function Hand:mousepressed(x, y, button)
  if button == 1 and areas.mouseInEndTurn(x, y) then
    areas.endTurn.state = "click"
    -- for _, card in ipairs(self.cards) do
    --   local c = card
    --   sequences.endTurn(c, areas, function() self:remove(c) end)
    -- end
    local ld = self.lastDiscarded
    if ld then
      self:add(ld, false, false)
      sequences.endTurn(ld, areas, function()
        print("End turn sequence done, resetting hand")
        self:layout()
        ld.hover.can = true
        ld.drag.can  = true
        self:unlockHand()
        self.lastDiscarded = nil

      end)
    end

    events.push({
      fn = function()
        areas.endTurn.state = "idle"
      end,
      blocking = true, blockable = true, persistent = false,
      delay = 0.5, type = "before",
    })
    return
  end

  for _, card in ipairs(self.cards) do
    if button == 1 and card:containsPoint(x, y) and card.drag.can then
      card.hover.is     = false
      card.drag.is      = true
      card.drag.can     = false
      card.drag.offsetX = x - card.current.x
      card.drag.offsetY = y - card.current.y
      return
    end
  end
end

return Hand
