local areas     = require("core.areas")
local sequences = require("core.sequences")

local Hand = {}
Hand.__index = Hand

function Hand.new()
  return setmetatable({ cards = {} }, Hand)
end

function Hand:add(card)
  self.cards[#self.cards + 1] = card
end

function Hand:isDragging()
  for _, card in ipairs(self.cards) do
    if card.drag.is then return true end
  end
  return false
end

function Hand:update(mouseX, mouseY)
  local draggingCard = nil
  for _, card in ipairs(self.cards) do
    if card.drag.is then draggingCard = card; break end
  end

  -- Update area highlight colors
  if areas.mouseInPlay(mouseX, mouseY) and draggingCard then
    areas.play.color = {0.5, 0.5, 1, 1}
  elseif draggingCard and areas.cardInPlay(draggingCard) then
    areas.play.color = {1, 1, 1, 1}
  elseif areas.mouseInPlay(mouseX, mouseY) then
    areas.play.color = {0.5, 1, 0.5, 1}
  else
    areas.play.color = {0.5, 0.5, 0.5, 1}
  end

  if areas.mouseInDiscard(mouseX, mouseY) and draggingCard then
    areas.discard.color = {0.5, 0.5, 1, 1}
  elseif draggingCard and areas.cardInDiscard(draggingCard) then
    areas.discard.color = {1, 1, 1, 1}
  elseif areas.mouseInDiscard(mouseX, mouseY) then
    areas.discard.color = {0.5, 1, 0.5, 1}
  else
    areas.discard.color = {0.5, 0.5, 0.5, 1}
  end

  for _, card in ipairs(self.cards) do
    -- Release drag
    if card.drag.is and not love.mouse.isDown(1) then
      card.drag.is  = false
      card.drag.can = true
      if areas.mouseInPlay(mouseX, mouseY) then
        sequences.play(card, areas)
      elseif areas.mouseInDiscard(mouseX, mouseY) then
        sequences.discard(card, areas)
      else
        card.target.x = card._startX
        card.target.y = card._startY
      end
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
    card:draw()
  end
end

function Hand:mousepressed(x, y, button)
  if button == 1 and areas.mouseInEndTurn(x, y) then
    for _, card in ipairs(self.cards) do
      sequences.endTurn(card, areas)
      -- if card.asset == card.assets.chomped and card.stationary then
      --   print("Ending turn with card in discard pile")
      -- elseif card.asset == card.assets.default then
      --   print("Ending turn with card in play")
      -- end
    end
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
