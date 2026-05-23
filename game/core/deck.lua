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
  table.insert(self.cards, card)

  -- Snap to deck position
  card.current.x    = self.x
  card.current.y    = self.y
  card.target.x     = self.x
  card.target.y     = self.y

  -- Reset physics
  card.current.r    = 0
  card.current.rVel = 0
  card.current.scale = 0.95
  card.target.scale  = 0.95
  card.stationary    = true

  -- Reset interaction flags
  card._excluded   = false
  card.hover.is    = false
  card.hover.can   = true
  card.drag.is     = false
  card.drag.can    = true

  -- Reset visuals
  card.drawShadow  = false
  card:resetDissolve()
  card:snapParts()
end

--- Remove and return the top card of the deck, or nil if empty.
--- @return table|nil
function Deck:deal()
  if #self.cards == 0 then return nil end
  local card = table.remove(self.cards, 1)
  card.drawShadow = true
  return card
end

--- @return number
function Deck:count()
  return #self.cards
end

--- @return boolean
function Deck:isEmpty()
  return #self.cards == 0
end

--- Draw the visual card-back pile and a count label below it.
function Deck:draw()
  if #self.cards == 0 then return end

  local maxLayers = math.min(#self.cards, 5)
  love.graphics.setColor(1, 1, 1, 1)

  -- Draw deepest layer first so the top card renders on top
  -- for i = maxLayers, 1, -1 do
  --   local offset = (i - 1) * 2
  --   love.graphics.draw(self.backAsset, self.x - offset, self.y - offset)
  -- end
  love.graphics.draw(self.backAsset, self.x, self.y)

  -- Count label centred on the pile
  love.graphics.setColor(1, 1, 1, 0.7)
  love.graphics.printf(tostring(#self.cards), self.x, self.y + self.h / 2 - 18, self.w, "center")
  love.graphics.setColor(1, 1, 1, 1)
end

return Deck
