local Deck       = {}
Deck.__index     = Deck

--- @param x number  left edge of the pile on screen
--- @param y number  top edge of the pile on screen
--- @param backAsset love.Image  card back texture
function Deck.new(x, y, backAsset)
  return setmetatable({
    cards     = {},
    x         = x,
    y         = y,
    w         = 180,
    h         = 270,
    backAsset = backAsset,
  }, Deck)
end

--- Add a card to the bottom of the deck and fully reset its state.
--- @param card table  Card object
function Deck:add(card)
  print("here")
  table.insert(self.cards, card)
  card:resetToInitial(self.x, self.y)
  card.current.scale = 0.95
  card.target.scale  = 0.95
  card.drawShadow    = false
end

--- Remove and return the top card of the deck, or nil if empty.
--- @return table|nil
function Deck:deal()
  if #self.cards == 0 then return nil end
  local card = table.remove(self.cards, 1)
  card.drawShadow = true
  return card
end

--- @return table|nil
function Deck:peek()
  return self.cards[1]
end

--- @return number
function Deck:count()
  return #self.cards
end

--- @return boolean
function Deck:isEmpty()
  return #self.cards == 0
end

--- @return table { x = number, y = number }
function Deck:position()
  return { x = self.x, y = self.y }
end

--- Draw the visual card-back pile.
--- Empty: nothing. Single: one card back. Stack (2+): layered depth effect.
function Deck:draw()
  if #self.cards == 0 then return end

  local iw, ih   = self.backAsset:getDimensions()
  -- Match visual height of a hand card at idle scale (card-base.png 1014px × 0.5)
  local sc       = (507 / ih) / 2 * SCALE_Y
  local cx, cy   = self.x, self.y
  local layers   = math.min(#self.cards, 3)
  local layerOff = 3 * SCALE_Y

  love.graphics.setColor(1, 1, 1, 1)

  if #self.cards == 1 then
    love.graphics.draw(self.backAsset, cx, cy, 0, sc, sc, iw / 2, ih / 2)
  else
    for i = layers, 1, -1 do
      local ox = -(i - 1) * layerOff
      local oy = -(i - 1) * layerOff
      love.graphics.draw(self.backAsset, cx + ox, cy + oy, 0, sc, sc, iw / 2, ih / 2)
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
end

return Deck
