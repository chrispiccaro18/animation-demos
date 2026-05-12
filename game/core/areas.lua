local animation = require("lib.animation")

local W = love.graphics.getWidth()
local H = love.graphics.getHeight()

local areas = {}

areas.play = {
  x = 0, y = 0,
  w = W / 2 - 10,
  h = H / 2 - 10,
  color = {0.5, 0.5, 0.5, 1},
  slotText = "",
}

areas.discard = {
  x = W / 2 + 10,
  startY = 0,
  w = W / 2 - 10,
  h = H / 2 - 10,
  color = {0.5, 0.5, 0.5, 1},
  slotText = "",
  current = { y = 0 },
  target  = { y = 0 },
}

areas.endTurn = {
  x = W / 2 + 194,
  y = H - 74,
  w = 260,
  h = 74,
  color = {1, 0, 0, 1},
}

local slotBottomAsset = nil
local slotTopAsset    = nil
local playTextObject  = nil
local discardTextObject = nil
local textObjectScale = 1

function areas.load()
  slotBottomAsset   = love.graphics.newImage("assets/slot-bottom.png")
  slotTopAsset      = love.graphics.newImage("assets/slot-top.png")
  local font        = love.graphics.newFont("assets/NotoSans-Medium.ttf", 40)
  playTextObject    = love.graphics.newText(font, "PLAY")
  discardTextObject = love.graphics.newText(font, "DISCARD")
end

function areas.update()
  areas.discard.current.y = animation.expDecay(areas.discard.current.y, areas.discard.target.y, 10, realDt)
end

-- Hit detection

function areas.mouseInPlay(x, y)
  local a = areas.play
  return x >= a.x and x <= a.x + a.w and y >= a.y and y <= a.y + a.h
end

function areas.mouseInDiscard(x, y)
  local a = areas.discard
  return x >= a.x and x <= a.x + a.w and y >= a.startY and y <= a.startY + a.h
end

function areas.mouseInEndTurn(x, y)
  local a = areas.endTurn
  return x >= a.x and x <= a.x + a.w and y >= a.y and y <= a.y + a.h
end

function areas.cardInPlay(card)
  local a = areas.play
  return card.current.x >= a.x and card.current.x + card.w <= a.x + a.w
     and card.current.y >= a.y and card.current.y <= a.y + a.h
end

function areas.cardInDiscard(card)
  local a = areas.discard
  return card.current.x >= a.x and card.current.x + card.w <= a.x + a.w
     and card.current.y >= a.startY and card.current.y <= a.startY + a.h
end

-- Draw helpers

local function drawSlotTops()
  if not slotTopAsset then return end
  local p = areas.play
  local d = areas.discard
  local deg180 = animation.degreesToRadians(180)

  love.graphics.draw(slotTopAsset, p.x + (p.w - slotTopAsset:getWidth()) / 2, p.y)
  love.graphics.draw(slotTopAsset, d.x + (d.w - slotTopAsset:getWidth()) / 2, d.current.y)
  love.graphics.setColor(0, 0, 0, 1)
  love.graphics.printf(p.slotText, p.x, p.y + 10, p.w, "center")
  love.graphics.printf(d.slotText, d.x, d.current.y + 10, d.w, "center")
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(
    slotTopAsset,
    d.x + (d.w - slotTopAsset:getWidth()) / 2,
    love.graphics.getHeight() - slotTopAsset:getHeight(),
    deg180, 1, 1,
    slotTopAsset:getWidth(), slotTopAsset:getHeight()
  )
end

-- Call before drawing cards. Draws area outlines, slot bottoms, and (when dragging)
-- the drop-zone labels and slot tops underneath the card.
function areas.drawBefore(isDragging)
  local p = areas.play
  local d = areas.discard
  local e = areas.endTurn
  local deg180 = animation.degreesToRadians(180)

  love.graphics.setColor(p.color)
  love.graphics.rectangle("line", p.x, p.y, p.w, p.h)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setColor(d.color)
  love.graphics.rectangle("line", d.x, d.startY, d.w, d.h)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setColor(e.color)
  love.graphics.rectangle("line", e.x, e.y, e.w, e.h)
  love.graphics.setColor(1, 1, 1, 1)

  if slotBottomAsset then
    love.graphics.draw(slotBottomAsset, p.x + (p.w - slotBottomAsset:getWidth()) / 2, p.y)
    love.graphics.draw(slotBottomAsset, d.x + (d.w - slotBottomAsset:getWidth()) / 2, d.current.y)
    love.graphics.draw(
      slotBottomAsset,
      d.x + (d.w - slotBottomAsset:getWidth()) / 2,
      love.graphics.getHeight() - slotBottomAsset:getHeight(),
      deg180, 1, 1,
      slotBottomAsset:getWidth(), slotBottomAsset:getHeight()
    )
  end

  if isDragging then
    if playTextObject then
      love.graphics.draw(
        playTextObject,
        p.x,
        p.y + p.h - playTextObject:getHeight() * textObjectScale - 10,
        0, textObjectScale, textObjectScale
      )
    end
    if discardTextObject then
      love.graphics.draw(
        discardTextObject,
        d.x + d.w - discardTextObject:getWidth() * textObjectScale,
        d.current.y + d.h - discardTextObject:getHeight() * textObjectScale - 10,
        0, textObjectScale, textObjectScale
      )
    end
    drawSlotTops()
  end
end

-- Call after drawing cards. Draws slot tops over the card when not dragging.
function areas.drawAfter(isDragging)
  if not isDragging then
    drawSlotTops()
  end
end

return areas
