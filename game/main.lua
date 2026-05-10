https = nil
local overlayStats = require("lib.overlayStats")
local runtimeLoader = require("runtime.loader")

local shipAsset = nil
local cardAsset = nil
local cardStartingX = 600
local cardStartingY = 400
local card = {
  hover = {
    is = false,
    can = true,
  },
  drag = {
    is = false,
    can = true,
    offsetX = 0,
    offsetY = 0,
  },
  stationary = true,
  w = 180,
  h = 270,
  scale = 1,
  current = {
    x = cardStartingX,
    y = cardStartingY,
    r = 0,
    rVel = 0,
    scale = 1,
  },
  target = {
    x = cardStartingX,
    y = cardStartingY,
    r = 0,
    scale = 1,
  },
  horizontalVelocity = 0
}

local playArea = {
  x = 0,
  y = 0,
  w = love.graphics.getWidth() / 2,
  h = love.graphics.getHeight() / 2,
  color = {0.5, 0.5, 0.5, 1},
}

-- need a small event system for when card is placed in play area
-- detect when "placed in play area": card.drag.is and not love.mouse.isDown(1) and mouseInPlayArea(mouseX, mouseY)
-- now it get's a target of the anticipation position
-- then give it a target position higher in the center
-- then scale up and scale back down
-- then drop it from play area to bottom of screen (card target y = love.graphics.getHeight() + card.h)

local function mouseInCard(x, y)
  return x >= card.current.x and x <= card.current.x + card.w and y >= card.current.y and y <= card.current.y + card.h
end

local function mouseInPlayArea(x, y)
  return x >= playArea.x and x <= playArea.x + playArea.w and y >= playArea.y and y <= playArea.y + playArea.h
end

local function cardInPlayArea()
  return card.current.x >= playArea.x and card.current.x + card.w <= playArea.x + playArea.w and
         card.current.y >= playArea.y and card.current.y <= playArea.y + playArea.h
  -- return card.current.x >= playArea.x and card.current.x + card.w <= playArea.x + playArea.w and
  --        card.current.y >= playArea.y and card.current.y + card.h <= playArea.y + playArea.h
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

local function expDecay(a, b, k, dt)
  return b + (a - b) * math.exp(-k * dt)
end

local function springDecay(pos, vel, target, stiffness, damping, dt)
  local force = (target - pos) * stiffness - vel * damping
  vel = vel + force * dt
  pos = pos + vel * dt
  return pos, vel
end

local stiffness = 80
local damping = 10
local influence = 0.002

local function updateCardPosition(dt)
  if not card.stationary then
    card.current.x = expDecay(card.current.x, card.target.x, 10, dt)
    card.current.y = expDecay(card.current.y, card.target.y, 10, dt)
    card.horizontalVelocity = (card.current.x - card.target.x) / dt
  -- else
  --   card.horizontalVelocity = 0
  end
  local rForce = -card.current.r * stiffness - card.current.rVel * damping + card.horizontalVelocity * -influence
  card.current.rVel = card.current.rVel + rForce * dt
  card.current.r = card.current.r + card.current.rVel * dt
  card.current.scale = expDecay(card.current.scale, card.target.scale, 18, dt)
end

local function updateCardStationary()
  if math.abs(card.current.x - card.target.x) < 0.1 and math.abs(card.current.y - card.target.y) < 0.1 then
    card.current.x = card.target.x
    card.current.y = card.target.y
    card.stationary = true
  else
    card.stationary = false
  end
end

function love.load()
  https = runtimeLoader.loadHTTPS()
  -- Your game load here
  shipAsset = love.graphics.newImage("assets/main-ship.png")
  cardAsset = love.graphics.newImage("assets/card-template-front.png")
  overlayStats.load() -- Should always be called last
end

function love.draw()
  -- Your game draw here

  if shipAsset then
    love.graphics.draw(shipAsset, 0, 0)
  end

  love.graphics.setColor(playArea.color)
  love.graphics.rectangle("line", playArea.x, playArea.y, playArea.w, playArea.h)
  love.graphics.setColor(1, 1, 1, 1)

  if cardAsset then
    love.graphics.push()
    love.graphics.translate(card.current.x + card.w / 2, card.current.y + card.h / 2)
    love.graphics.rotate(card.current.r)
    love.graphics.scale(card.current.scale, card.current.scale)
    love.graphics.draw(cardAsset, -card.w / 2, -card.h / 2)
    love.graphics.pop()
  end
  overlayStats.draw() -- Should always be called last
end

function love.update(dt)
  local mouseX, mouseY = love.mouse.getPosition()

  if mouseInPlayArea(mouseX, mouseY) and card.drag.is then
    playArea.color = {0.5, 0.5, 1, 1} -- Blue
  elseif cardInPlayArea() then
    playArea.color = {1, 1, 1, 1} -- White
  elseif mouseInPlayArea(mouseX, mouseY) then
    playArea.color = {0.5, 1, 0.5, 1} -- Green
  else
    playArea.color = {0.5, 0.5, 0.5, 1} -- Default color
  end


  if card.drag.is and not love.mouse.isDown(1) then
    card.drag.is = false
    card.drag.can = true
    -- is mouse is in play area, snap card to center of play area
    if mouseInPlayArea(mouseX, mouseY) then
      card.target.x = playArea.x + (playArea.w - card.w) / 2
      card.target.y = playArea.y + (playArea.h - card.h / 2)
    else
      -- reset card position
      card.target.x = cardStartingX
      card.target.y = cardStartingY
    end
  end

  if card.drag.is then
    card.target.x = mouseX - card.drag.offsetX
    card.target.y = mouseY - card.drag.offsetY
  end

  if card.hover.can and not card.drag.is and mouseInCard(mouseX, mouseY) then
    card.hover.is = true
    card.hover.can = false
    card.target.scale = 1.05
  elseif mouseInCard(mouseX, mouseY) and card.drag.is then
    card.target.scale = 1.125
  elseif not mouseInCard(mouseX, mouseY) and not card.drag.is then
    card.hover.is = false
    card.hover.can = true
    card.target.scale = 1
  elseif mouseInCard(mouseX, mouseY) and not card.drag.is then
    card.target.scale = 1.05
  end

  if cardInPlayArea() and card.stationary and not card.drag.is and not card.hover.is then
    card.target.y = playArea.y + (playArea.h - card.h) / 2
  end

  updateCardPosition(dt)
  updateCardStationary()
  overlayStats.update(dt) -- Should always be called last
end

function love.mousepressed(x, y, button, istouch, presses)
  if button == 1 and mouseInCard(x, y) then
    if card.drag.can then
      card.hover.is = false
      card.hover.can = false
      card.drag.is = true
      card.drag.can = false
      card.drag.offsetX = x - card.current.x
      card.drag.offsetY = y - card.current.y
    end
  end
end

function love.keypressed(key)
  if key == "escape" and love.system.getOS() ~= "Web" then
    love.event.quit()
  else
    overlayStats.handleKeyboard(key) -- Should always be called last
  end
end

function love.touchpressed(id, x, y, dx, dy, pressure)
  overlayStats.handleTouch(id, x, y, dx, dy, pressure) -- Should always be called last
end
