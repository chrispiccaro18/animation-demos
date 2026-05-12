https = nil
local overlayStats = require("lib.overlayStats")
local runtimeLoader = require("runtime.loader")
local events = require("lib.events")

local shipAsset = nil
local cardAsset = nil
local chompedCardAsset = nil
local slotBottomAsset = nil
local slotTopAsset = nil
local slotText = ""
local discardSlotText = ""

local textObjectScale = 1
local playTextObject = nil
local discardTextObject = nil

local cardStartingX = 600
local cardStartingY = 400
local card = {
  asset = nil,
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
    scale = 0.95,
  },
  target = {
    x = cardStartingX,
    y = cardStartingY,
    r = 0,
    scale = 0.95,
  },
  horizontalVelocity = 0
}

local playArea = {
  x = 0,
  y = 0,
  w = love.graphics.getWidth() / 2 - 10,
  h = love.graphics.getHeight() / 2 - 10,
  color = {0.5, 0.5, 0.5, 1},
}

local discardStartingX = love.graphics.getWidth() / 2 + 10
local discardStartingY = 0
local discardArea = {
  current = {
    y = discardStartingY,
  },
  target = {
    y = discardStartingY,
  },
  x = discardStartingX,
  -- y = discardStartingY,
  w = love.graphics.getWidth() / 2 - 10,
  h = love.graphics.getHeight() / 2 - 10,
  color = {0.5, 0.5, 0.5, 1},
}

local endTurnArea = {
  x = love.graphics.getWidth() / 2 + 194,
  y = love.graphics.getHeight() - 74,
  w = 260,
  h = 74,
  color = {1, 0, 0, 1},
}

local function playCardSequence()
  -- Anticipation: nudge card slightly down before launching up
  events.push({
    fn = function()
      card.hover.is = false
      card.hover.can = false
      card.drag.is = false
      card.drag.can = false
      card.target.scale = 0.95
      card.target.x = playArea.x + (playArea.w - card.w) / 2
      card.target.y = playArea.y + (playArea.h - card.h / 2)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  events.push({
    fn = function()
      card.target.y = playArea.y + (playArea.h - card.h / 2) + 30
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after",
  })
  -- Move to center of play area, elevated
  events.push({
    fn = function()
      card.target.x = playArea.x + (playArea.w - card.w) / 2
      card.target.y = playArea.y
      -- card.target.y = playArea.y + (playArea.h - card.h) / 2
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  -- Scale up
  events.push({
    fn = function()
      card.target.scale = 1.2
      slotText = "+1 Progress"
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  -- Scale back down
  events.push({
    fn = function()
      card.target.scale = 0.95
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  events.push({
    fn = function()
      card.target.y = card.current.y - 30
      -- card.target.y = love.graphics.getHeight() - card.h
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after",
  })
  -- Drop to bottom of screen
  events.push({
    fn = function()
      slotText = ""
      card.target.y = cardStartingY
      -- card.target.y = love.graphics.getHeight() - card.h
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after",
  })
  events.push({
    fn = function()
      card.hover.can = true
      card.drag.can = true
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })
end

local function discardCardSequence()
  -- Anticipation: nudge card slightly down before launching up
  events.push({
    fn = function()
      card.hover.is = false
      card.hover.can = false
      card.drag.is = false
      card.drag.can = false
      card.target.scale = 0.95
      card.target.x = discardArea.x + (discardArea.w - card.w) / 2
      card.target.y = discardStartingY + (discardArea.h - card.h / 2)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  events.push({
    fn = function()
      card.target.y = discardStartingY + (discardArea.h - card.h / 2) + 30
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after",
  })
  -- Move to center of discard area, elevated
  events.push({
    fn = function()
      card.target.x = discardArea.x + (discardArea.w - card.w) / 2
      card.target.y = discardStartingY
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  -- Scale up
  events.push({
    fn = function()
      card.target.scale = 1.2
      card.asset = chompedCardAsset
      discardSlotText = "+1 RAM"
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  -- Scale back down
  events.push({
    fn = function()
      card.target.scale = 0.95
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  events.push({
    fn = function()
      card.target.y = card.current.y - 30
      -- card.target.y = love.graphics.getHeight() - card.h
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after",
  })
  -- Drop to bottom of screen
  events.push({
    fn = function()
      slotText = "+1 RAM"
      discardSlotText = ""
      card.target.y = love.graphics.getHeight() - card.asset:getHeight()
      -- card.target.y = love.graphics.getHeight() - card.h
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after",
  })
  events.push({
    fn = function()
      card.hover.can = false
      card.drag.can = false
      slotText = ""
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })
  -- events.push({
  --   fn = function()
  --     slotText = ""
  --     card.hover.can = true
  --     card.drag.can = true
  --     card.asset = cardAsset
  --     card.target.y = cardStartingY
  --     card.current.y = cardStartingY
  --   end,
  --   blocking = true, blockable = true, persistent = true,
  --   delay = 0.5, type = "before",
  -- })
end

local function endTurnSequence()
  events.push({
    fn = function()
      discardArea.target.y = love.graphics.getHeight() - 60 * 2
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  events.push({
    fn = function()
      discardSlotText = "+1 Threat"
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after",
  })
  events.push({
    fn = function()
      discardArea.target.y = discardStartingY
      card.target.y = discardStartingY
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.65, type = "after",
  })
  events.push({
    fn = function()
      card.target.y = card.current.y - 270
    end,
    blocking = true,
    blockable = true,
    persistent = false,
    delay = 0.65,
    type = "after",
  })
  events.push({
    fn = function()
      card.asset = cardAsset
      card.target.y = discardStartingY
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.65, type = "after",
  })
  events.push({
    fn = function()
      discardSlotText = ""
      card.target.y = card.current.y - 30
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after",
  })
  events.push({
    fn = function()
      discardSlotText = ""
      -- card.target.x = playArea.x + (playArea.w - card.w) / 2
      card.target.y = cardStartingY
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.055, type = "after",
  })
  events.push({
    fn = function()
      card.target.x = playArea.x + (playArea.w - card.w) / 2
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after",
  })
  events.push({
    fn = function()
      card.hover.can = true
      card.drag.can = true
    end,
    blocking = true, blockable = true, persistent = true,
    delay = 0, type = "immediate",
  })
end

local function mouseInCard(x, y)
  return x >= card.current.x and x <= card.current.x + card.w and y >= card.current.y and y <= card.current.y + card.h
end

local function mouseInPlayArea(x, y)
  return x >= playArea.x and x <= playArea.x + playArea.w and y >= playArea.y and y <= playArea.y + playArea.h
end

local function mouseInDiscardArea(x, y)
  return x >= discardArea.x and x <= discardArea.x + discardArea.w and y >= discardStartingY and
      y <= discardStartingY + discardArea.h
end

local function mouseInEndTurnArea(x, y)
  return x >= endTurnArea.x and x <= endTurnArea.x + endTurnArea.w and y >= endTurnArea.y and y <= endTurnArea.y + endTurnArea.h
end

local function cardInPlayArea()
  return card.current.x >= playArea.x and card.current.x + card.w <= playArea.x + playArea.w and
         card.current.y >= playArea.y and card.current.y <= playArea.y + playArea.h
  -- return card.current.x >= playArea.x and card.current.x + card.w <= playArea.x + playArea.w and
  --        card.current.y >= playArea.y and card.current.y + card.h <= playArea.y + playArea.h
end

local function cardInDiscardArea()
  return card.current.x >= discardArea.x and card.current.x + card.w <= discardArea.x + discardArea.w and
         card.current.y >= discardStartingY and card.current.y <= discardStartingY + discardArea.h
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

local function degreesToRadians(degrees)
  return degrees * math.pi / 180
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
  discardArea.current.y = expDecay(discardArea.current.y, discardArea.target.y, 10, dt)
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
  chompedCardAsset = love.graphics.newImage("assets/chomped-card.png")
  slotBottomAsset = love.graphics.newImage("assets/slot-bottom.png")
  slotTopAsset = love.graphics.newImage("assets/slot-top.png")
  local notoSansFont = love.graphics.newFont("assets/NotoSans-Medium.ttf", 40)
  playTextObject = love.graphics.newText(notoSansFont, "PLAY")
  discardTextObject = love.graphics.newText(notoSansFont, "DISCARD")
  card.asset = cardAsset
  events.load()
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
  love.graphics.setColor(discardArea.color)
  love.graphics.rectangle("line", discardArea.x, discardStartingY, discardArea.w, discardArea.h)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setColor(endTurnArea.color)
  love.graphics.rectangle("line", endTurnArea.x, endTurnArea.y, endTurnArea.w, endTurnArea.h)
  love.graphics.setColor(1, 1, 1, 1)

  if slotBottomAsset then
    love.graphics.draw(
      slotBottomAsset,
      playArea.x + (playArea.w - slotBottomAsset:getWidth()) / 2,
      playArea.y
    )
    love.graphics.draw(
      slotBottomAsset,
      discardArea.x + (discardArea.w - slotBottomAsset:getWidth()) / 2,
      discardArea.current.y
    )
    love.graphics.draw(
      slotBottomAsset,
      discardArea.x + (discardArea.w - slotBottomAsset:getWidth()) / 2,
      love.graphics.getHeight() - slotBottomAsset:getHeight(),
      degreesToRadians(180),
      1,
      1,
      slotBottomAsset:getWidth(),
      slotBottomAsset:getHeight()
    )
  end

  if card.drag.is then
    if playTextObject then
      love.graphics.draw(
        playTextObject,
        playArea.x,
        playArea.y + playArea.h - playTextObject:getHeight() * textObjectScale - 10,
        0,
        textObjectScale,
        textObjectScale
      )
    end
    if discardTextObject then
      love.graphics.draw(
        discardTextObject,
        discardArea.x + discardArea.w - discardTextObject:getWidth() * textObjectScale,
        discardArea.current.y + discardArea.h - discardTextObject:getHeight() * textObjectScale - 10,
        0,
        textObjectScale,
        textObjectScale
      )
    end
    if slotTopAsset then
      love.graphics.draw(
        slotTopAsset,
        playArea.x + (playArea.w - slotTopAsset:getWidth()) / 2,
        playArea.y
      )
      love.graphics.draw(
        slotTopAsset,
        discardArea.x + (discardArea.w - slotTopAsset:getWidth()) / 2,
        discardArea.current.y
      )
      love.graphics.setColor(0, 0, 0, 1)
      love.graphics.printf(
        slotText,
        playArea.x,
        playArea.y + 10,
        playArea.w,
        "center"
      )
      love.graphics.printf(
        discardSlotText,
        discardArea.x,
        discardArea.current.y + 10,
        discardArea.w,
        "center"
      )
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(
        slotTopAsset,
        discardArea.x + (discardArea.w - slotTopAsset:getWidth()) / 2,
        love.graphics.getHeight() - slotTopAsset:getHeight(),
        degreesToRadians(180),
        1, 1,
        slotTopAsset:getWidth(),
        slotTopAsset:getHeight()
      )
    end
  end

  if cardAsset then
    love.graphics.push()
    love.graphics.translate(card.current.x + card.w / 2, card.current.y + card.h / 2)
    love.graphics.rotate(card.current.r)
    love.graphics.scale(card.current.scale, card.current.scale)
    love.graphics.draw(card.asset, -card.w / 2, -card.h / 2)
    love.graphics.pop()
  end

  if not card.drag.is then
    if slotTopAsset then
      love.graphics.draw(
        slotTopAsset,
        playArea.x + (playArea.w - slotTopAsset:getWidth()) / 2,
        playArea.y
      )
      love.graphics.draw(
        slotTopAsset,
        discardArea.x + (discardArea.w - slotTopAsset:getWidth()) / 2,
        discardArea.current.y
      )
      love.graphics.setColor(0, 0, 0, 1)
      love.graphics.printf(
        slotText,
        playArea.x,
        playArea.y + 10,
        playArea.w,
        "center"
      )
      love.graphics.printf(
        discardSlotText,
        discardArea.x,
        discardArea.current.y + 10,
        discardArea.w,
        "center"
      )
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(
        slotTopAsset,
        discardArea.x + (discardArea.w - slotTopAsset:getWidth()) / 2,
        love.graphics.getHeight() - slotTopAsset:getHeight(),
        degreesToRadians(180),
        1, 1,
        slotTopAsset:getWidth(),
        slotTopAsset:getHeight()
      )
    end
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

  if mouseInDiscardArea(mouseX, mouseY) and card.drag.is then
    discardArea.color = {0.5, 0.5, 1, 1} -- Blue
  elseif cardInDiscardArea() then
    discardArea.color = {1, 1, 1, 1} -- White
  elseif mouseInDiscardArea(mouseX, mouseY) then
    discardArea.color = {0.5, 1, 0.5, 1} -- Green
  else
    discardArea.color = {0.5, 0.5, 0.5, 1} -- Default color
  end


  if card.drag.is and not love.mouse.isDown(1) then
    card.drag.is = false
    card.drag.can = true
    -- is mouse is in play area, trigger play sequence
    if mouseInPlayArea(mouseX, mouseY) then
      playCardSequence()
    elseif mouseInDiscardArea(mouseX, mouseY) then
      discardCardSequence()
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
    -- card.hover.can = false
    card.target.scale = 1.05
  elseif mouseInCard(mouseX, mouseY) and card.drag.is then
    card.target.scale = 1.125
  elseif not mouseInCard(mouseX, mouseY) and not card.drag.is and card.hover.can then
    card.hover.is = false
    -- card.hover.can = true
    card.target.scale = 0.95
  elseif mouseInCard(mouseX, mouseY) and card.hover.can and not card.drag.is then
    card.target.scale = 1.05
  end

  -- if cardInPlayArea() and card.stationary and not card.drag.is and not card.hover.is then
  --   card.target.y = playArea.y + (playArea.h - card.h) / 2
  -- end

  updateCardPosition(dt)
  updateCardStationary()
  events.update(dt)
  overlayStats.update(dt) -- Should always be called last
end

function love.mousepressed(x, y, button, istouch, presses)
  if button == 1 and mouseInEndTurnArea(x, y) then
    if card.asset == chompedCardAsset and card.stationary then
      endTurnSequence()
      print("Ending turn with card in discard pile")
    elseif card.asset == cardAsset then
      print("Ending turn with card in play")
    end
  elseif button == 1 and mouseInCard(x, y) then
    if card.drag.can then
      -- events.clear()
      card.hover.is = false
      -- card.hover.can = false
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
  elseif key == "space" then
    print(card.hover.can)
  else
    overlayStats.handleKeyboard(key) -- Should always be called last
  end
end

function love.touchpressed(id, x, y, dx, dy, pressure)
  overlayStats.handleTouch(id, x, y, dx, dy, pressure) -- Should always be called last
end
