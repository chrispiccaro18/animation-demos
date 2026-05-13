https = nil
local overlayStats = require("lib.overlayStats")
local runtimeLoader = require("runtime.loader")
local events = require("lib.events")
local areas  = require("core.areas")
local Card   = require("core.card")
local Hand   = require("core.hand")
local config       = require("lib.config")
local Projectile   = require("core.projectile")
local projectiles  = require("core.projectiles")

local shipAsset = nil
local hand = Hand.new()

function love.load()
  https = runtimeLoader.loadHTTPS()
  shipAsset = love.graphics.newImage("assets/main-ship.png")
  local cardAsset        = love.graphics.newImage("assets/card-template-front.png")
  local chompedCardAsset = love.graphics.newImage("assets/chomped-card.png")
  areas.load()
  local projFont = love.graphics.newFont("assets/NotoSans-Medium.ttf", 36)
  projectiles.ram = Projectile.new({ asset = love.graphics.newImage("assets/large-ram.png"), font = projFont })
  projectiles.progress = Projectile.new({ asset = love.graphics.newImage("assets/progress.png"), font = projFont, fontColor = {1, 1, 1, 1} })
  projectiles.threat = Projectile.new({ asset = love.graphics.newImage("assets/threat.png"), font = projFont, fontColor = {1, 1, 1, 1} })
  hand:add(Card.new(600, 400, cardAsset, chompedCardAsset))
  -- hand:add(Card.new(200, 400, cardAsset, chompedCardAsset))
  events.load()
  overlayStats.load()
end

function love.draw()
  -- if shipAsset then
  --   love.graphics.draw(shipAsset, 0, 0)
  -- end
  areas.drawBefore(hand:isDragging())
  hand:draw()
  areas.drawAfter(hand:isDragging())
  for _, proj in pairs(projectiles) do proj:draw() end
  areas.drawStatic()
  overlayStats.draw()
end

function love.update(dt)
  realDt = dt
  gameDt = dt * config.speed
  local mouseX, mouseY = love.mouse.getPosition()
  hand:update(mouseX, mouseY)
  areas.update()
  for _, proj in pairs(projectiles) do proj:update() end
  events.update()
  overlayStats.update(dt)
end

function love.mousepressed(x, y, button, istouch, presses)
  hand:mousepressed(x, y, button)
end

function love.keypressed(key)
  if key == "escape" and love.system.getOS() ~= "Web" then
    love.event.quit()
  elseif key == "space" then
    if hand.cards[1] then print(hand.cards[1].hover.can) end
  elseif key == "tab" then
    config.cycleSpeed()
    print("Speed: " .. config.speed .. "x")
  else
    overlayStats.handleKeyboard(key)
  end
end

function love.touchpressed(id, x, y, dx, dy, pressure)
  overlayStats.handleTouch(id, x, y, dx, dy, pressure)
end
