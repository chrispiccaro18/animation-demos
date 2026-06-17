https = nil
SCALE_X = love.graphics.getWidth() / 3840
SCALE_Y = love.graphics.getHeight() / 2160
local overlayStats   = require("lib.overlayStats")
local speedControl   = require("lib.speedControl")
local runtimeLoader = require("runtime.loader")
local events = require("lib.events")
local areas  = require("core.areas")
local Card   = require("core.card")
-- local Hand   = require("core.hand")
local NewHand   = require("core.newHand")
local config       = require("lib.config")
local sequences    = require("core.newSequences")
local Deck         = require("core.deck")
local Camera       = require("core.camera")
local Token        = require("core.token")
local laser        = require("core.laser")
local Dtor         = require("core.dtor")
local particles    = require("core.particles")
local CardData     = require("data.cards")
local AssetManifest = require("assets.manifest")

local Color = require("lib.color")

local touches = {}

local cardBackAsset = nil
local dissolveShader = nil
local tiltShader = nil
screenshake = require("lib.screenshake")
gameOver = nil
local hand = NewHand.new()
local deck = nil

local boardAsset = nil
local camera = nil

local previousSpeed = config.speed

local gameCanvas = nil
local canvasW    = 0
local canvasH    = 0
local viewX      = 0
local viewY      = 0
local viewScale  = 1

local function updateViewport()
  local sw = love.graphics.getWidth()
  local sh = love.graphics.getHeight()
  viewScale = math.min(sw / canvasW, sh / canvasH)
  viewX = math.floor((sw - canvasW * viewScale) / 2)
  viewY = math.floor((sh - canvasH * viewScale) / 2)
end

local function toGame(x, y)
  return (x - viewX) / viewScale, (y - viewY) / viewScale
end

local function resetGame()
  events.loadAll()
  Token.clearAll()
  Dtor.reset()
  laser.hide()

  areas.progressBar.count = 0
  areas.progressBar.textArea.value = "00/10"
  areas.threatBar.count = 0
  areas.threatBar.textArea.value = "00/10"
  areas.endTurn.frozen = false
  areas.endTurn.state = "idle"
  areas.endTurn.hover.can = true
  areas.endTurn.hover.is = false
  areas.endTurn.click.can = false
  areas.endTurn.click.is = false
  areas.scanner.left.active = false
  areas.scanner.left.y = areas.desk.y
  areas.scanner.right.active = false
  areas.scanner.right.y = areas.desk.y
  areas.pool.chips = {}
  areas.message.text = ""
  areas.message.subtitle = ""
  areas.message.textColor = { 1, 1, 1, 1 }
  gameOver = nil

  hand = NewHand.new()
  deck = Deck.new(220 * SCALE_X, 1840 * SCALE_Y, cardBackAsset)
  sequences.setDeck(deck)

  for _ = 1, 2 do
    local card = Card.new(
      love.graphics.getWidth() / 2,
      love.graphics.getHeight() / 2,
      CardData.cards.card1
    )
    deck:add(card)
  end
  for _ = 1, 2 do
    local card = Card.new(
      love.graphics.getWidth() / 2,
      love.graphics.getHeight() / 2,
      CardData.cards.card2
    )
    deck:add(card)
  end
  for _ = 1, 2 do
    local card = Card.new(
      love.graphics.getWidth() / 2,
      love.graphics.getHeight() / 2,
      CardData.cards.card3
    )
    deck:add(card)
  end
  for _ = 1, 2 do
    local card = Card.new(
      love.graphics.getWidth() / 2,
      love.graphics.getHeight() / 2,
      CardData.cards.card4
    )
    deck:add(card)
  end
  for _ = 1, 2 do
    local card = Card.new(
      love.graphics.getWidth() / 2,
      love.graphics.getHeight() / 2,
      CardData.cards.card5
    )
    deck:add(card)
  end
  deck:shuffle()

  for _ = 1, 4 do
    sequences.dealCardToHand(hand)
  end

  camera:setIdle()
end

function love.load()
  https = runtimeLoader.loadHTTPS()
  AssetManifest.load()

  Token.load()
  Dtor.load()
  camera = Camera.load()
  camera:setIdle()

  boardAsset = AssetManifest.get("board", "base")
  cardBackAsset = AssetManifest.get("card", "back")
  -- boardAsset:setFilter("linear", "linear")
  -- boardAsset:setMipmapFilter("linear")
  dissolveShader = love.graphics.newShader("assets/dissolve.fs")
  tiltShader = love.graphics.newShader("assets/tilt.fs")

  Card.load(dissolveShader, tiltShader)
  areas.load()
  particles.load()
  deck = Deck.new(220 * SCALE_X, 1840 * SCALE_Y, cardBackAsset)
  sequences.setDeck(deck)
  print("ScaleX: " .. SCALE_X .. ", ScaleY: " .. SCALE_Y)

  events.loadAll()
  overlayStats.load()
  speedControl.load()
  canvasW    = love.graphics.getWidth()
  canvasH    = love.graphics.getHeight()
  gameCanvas = love.graphics.newCanvas(canvasW, canvasH)
  updateViewport()
  resetGame()
end

function love.draw()
  -- Fill full screen to cover letterbox bars
  love.graphics.setColor(Color("#12131A"))
  -- love.graphics.setColor(hexToRGBA("#20222E"))
  love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
  love.graphics.setColor(1, 1, 1, 1)

  -- Draw all game content into the fixed-resolution canvas
  love.graphics.setCanvas(gameCanvas)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.setColor(Color("#12131A"))
  love.graphics.rectangle("fill", 0, 0, canvasW, canvasH)
  love.graphics.setColor(1, 1, 1, 1)

  local sx, sy = screenshake.getOffset()
  love.graphics.push()
  love.graphics.translate(sx, sy)

  if boardAsset then
    love.graphics.draw(boardAsset, 0, 0, 0, SCALE_X, SCALE_Y)
  end

  particles.draw()
  areas.drawStatic()
  Dtor.drawAll()
  if camera then camera:draw() end
  if camera then camera:drawScannerLines(areas.scanner) end
  if deck then deck:draw() end
  hand:draw()
  Token.drawAll()
  areas.drawScanners()
  love.graphics.pop()

  overlayStats.draw()
  speedControl.draw()
  love.graphics.setCanvas()

  -- Blit the canvas onto the screen, centered and letterboxed
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(gameCanvas, viewX, viewY, 0, viewScale, viewScale)
end

function love.update(dt)
  realDt = dt
  gameDt = dt * config.speed
  local touchCount = 0
  for _ in pairs(touches) do touchCount = touchCount + 1 end
  if touchCount == 3 then
    resetGame()
  end
  screenshake.update(realDt)
  overlayStats.update(dt)
  areas.updateMessage(realDt)
  areas.updateBars(realDt)
  particles.update(realDt)
  if gameOver then return end
  local mx, my = love.mouse.getPosition()
  local mouseX, mouseY = toGame(mx, my)

  if camera then camera:update(realDt, mouseX, mouseY, areas.scanner) end
  laser.update(gameDt)
  hand:update(mouseX, mouseY)
  Token.updateAll(realDt, gameDt)
  Dtor.update(realDt)
  areas.updateScanners(gameDt)
  if not hand:isDragging() and not areas.endTurn.frozen then
    if areas.updateEndTurn(realDt, mouseX, mouseY) then
      sequences.endTurn(hand)
    end
  end
  if areas.scanner.left.active  then Token.triggerQuiverNear(areas.scanner.left.y)  end
  if areas.scanner.right.active then Token.triggerQuiverNear(areas.scanner.right.y) end
  events.updateAll()
end

function love.mousepressed(x, y, button, istouch, presses)
  if speedControl.mousepressed(x, y, button) then return end
  local gx, gy = toGame(x, y)
  hand:mousepressed(gx, gy, button)
end

function love.keyreleased(key)
  if key == "space" then
    config.speed = previousSpeed
    speedControl.setSpaceHeld(false)
    print("Speed: " .. config.speed .. "x")
  end
end

function love.keypressed(key)
  if key == "escape" and love.system.getOS() ~= "Web" then
    love.event.quit()
  elseif key == "r" then
    resetGame()
  elseif key == "s" then
    screenshake.trigger()
  elseif key == "q" then
    areas.scanner.left.active = not areas.scanner.left.active
  elseif key == "w" then
    areas.scanner.right.active = not areas.scanner.right.active
  elseif key == "tab" then
    config.cycleSpeed()
    print("Speed: " .. config.speed .. "x")
  elseif key == "space" then
    previousSpeed = config.speed
    config.speed = 3.0
    speedControl.setSpaceHeld(true)
    print("Speed: " .. config.speed .. "x")
  else
    overlayStats.handleKeyboard(key)
  end
end


function love.resize(w, h)
  updateViewport()
end

function love.touchpressed(id, x, y, dx, dy, pressure)
  touches[id] = { x = x, y = y }
  overlayStats.handleTouch(id, x, y, dx, dy, pressure)
end

function love.touchmoved(id, x, y)
  if touches[id] then
    touches[id] = { x = x, y = y }
  end
end

function love.touchreleased(id, x, y, dx, dy, pressure)
  if touches[id] then
    touches[id] = nil
  end
end
