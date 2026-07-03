https = nil
SCALE_X = 0
SCALE_Y = 0
local overlayStats   = require("lib.overlayStats")
local speedControl   = require("lib.speedControl")
local runtimeLoader = require("runtime.loader")
local events = require("lib.events")
local areas       = require("core.areas")
local progressBar = require("core.progressBar")
local threatBar   = require("core.threatBar")
local envEffects  = require("core.envEffects")
local Card   = require("core.card")
-- local Hand   = require("core.hand")
local NewHand   = require("core.newHand")
local config       = require("lib.config")
local message      = require("core.message")
local sequences    = require("core.newSequences")
local actionQueue  = require("core.actionQueue")
local Deck         = require("core.deck")
local Camera       = require("core.camera")
local Token        = require("core.token")
local Debris       = require("core.debris")
local laser        = require("core.laser")
local Dtor         = require("core.dtor")
local particles    = require("core.particles")
local CardData     = require("data.cards")
local AssetManifest = require("assets.manifest")
local Audio = require("assets.audio")

local Color        = require("lib.color")
local Palette      = require("lib.palette")
local Glow         = require("lib.glow.Glow")
local glowRequests = require("core.glowRequests")
local pulse        = require("lib.pulse")

local hover          = require("core.hover")
local cardTooltip    = require("core.cardTooltip")
local hoverTooltip   = require("core.hoverTooltip")
local tutorial       = require("core.tutorial")
local hud            = require("core.hud")
local gameOverScreen = require("core.gameOverScreen")

local glow = nil

local touches = {}
local maxTouches = 0
local touchStartTime = 0
local TAP_THRESHOLD = 0.4

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

local tutorialActive = true

local function updateViewport()
  local sw = love.graphics.getWidth()
  local sh = love.graphics.getHeight()
  viewScale = math.min(sw / canvasW, sh / canvasH)
  viewX = math.floor((sw - canvasW * viewScale) / 2)
  viewY = math.floor((sh - canvasH * viewScale) / 2)
  print("Viewport updated: viewX=" .. viewX .. ", viewY=" .. viewY .. ", viewScale=" .. viewScale)
  print("Window size: width=" .. love.graphics.getWidth() .. ", height=" .. love.graphics.getHeight())
end

local function toGame(x, y)
  return (x - viewX) / viewScale, (y - viewY) / viewScale
end

local function resetGame()
  events.loadAll()
  actionQueue.reset()
  Token.clearAll()
  Debris.clearAll()
  Dtor.reset()
  laser.hide()

  progressBar.reset()
  threatBar.reset()
  envEffects.syncState()
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
  message.text         = ""
  message.subtitle     = ""
  message.textColor    = { 1, 1, 1, 1 }
  message.current      = { scale = 1 }
  message.target       = { scale = 1 }
  gameOver = nil
  gameOverScreen.reset()

  hand = NewHand.new()
  deck = Deck.new(220 * SCALE_X, 1840 * SCALE_Y, cardBackAsset)
  hover.setDeck(deck)
  sequences.setDeck(deck)
  sequences.setHand(hand)

  for _, cardData in pairs(CardData.startingDeck) do
  -- for _, cardData in pairs(CardData.cards) do
    local card = Card.new(
      canvasW / 2,
      canvasH / 2,
      cardData
    )
    deck:add(card)
  end
  deck:shuffle()

  for _ = 1, 4 do
    sequences.dealCardToHand()
  end

  camera:setIdle()

  -- local ram1X, ram1Y = areas.randomPoolPosition()
  -- areas.addPoolChip(ram1X, ram1Y)
  -- local ram2X, ram2Y = areas.randomPoolPosition()
  -- areas.addPoolChip(ram2X, ram2Y)
end

function love.load()
  local n = math.max(1, math.min(
    math.floor(love.graphics.getWidth() / 640),
    math.floor(love.graphics.getHeight() / 360)
  ))
  canvasW = n * 640
  canvasH = n * 360
  SCALE_X = canvasW / 3840
  SCALE_Y = canvasH / 2160
  print(string.format("Canvas: %dx%d  SCALE: %.4f,%.4f  Window: %dx%d",
    canvasW, canvasH, SCALE_X, SCALE_Y,
    love.graphics.getWidth(), love.graphics.getHeight()))

  https = runtimeLoader.loadHTTPS()
  local seed = os.time()
  math.randomseed(seed)

  AssetManifest.load()
  Audio.load()
  love.audio.setVolume(0.25)
  -- love.audio.setVolume(0.5)
  -- love.audio.setVolume(1.0)

  Token.load()
  Dtor.load()
  camera = Camera.load()
  camera:setIdle()

  boardAsset = AssetManifest.get("board", "base")
  cardBackAsset = AssetManifest.get("card", "back")
  dissolveShader = love.graphics.newShader("assets/dissolve.fs")
  tiltShader = love.graphics.newShader("assets/tilt.fs")

  if love.system.getOS() == "Web" and canvasW < 720 then
   tiltShader = nil
  end

  Card.load(dissolveShader, tiltShader)
  cardTooltip.load()
  hoverTooltip.load()
  tutorial.load()
  tutorial.onClose = function() tutorialActive = false end
  areas.load()
  hover.load()
  message.load()
  particles.load()
  deck = Deck.new(220 * SCALE_X, 1840 * SCALE_Y, cardBackAsset)
  sequences.setDeck(deck)
  print("ScaleX: " .. SCALE_X .. ", ScaleY: " .. SCALE_Y)

  events.loadAll()
  overlayStats.load()
  speedControl.load()

  gameCanvas = love.graphics.newCanvas(canvasW, canvasH)
  overlayStats.setGameCanvas(gameCanvas)
  updateViewport()

  glow = Glow.load(canvasW, canvasH)
  hud.load(
    function() tutorialActive = true end,
    resetGame,
    function() love.system.openURL("https://forms.gle/sjbzYgS94u2w27iq5") end
  )
  gameOverScreen.load(resetGame)

  resetGame()
end

function love.draw()
  -- Fill full screen to cover letterbox bars
  love.graphics.setColor(Palette.void)
  love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
  love.graphics.setColor(1, 1, 1, 1)

  -- Draw all game content into the fixed-resolution canvas
  -- love.graphics.setCanvas(gameCanvas)
  -- love.graphics.clear(0, 0, 0, 0)
  -- love.graphics.setColor(Palette.void)
  -- love.graphics.rectangle("fill", 0, 0, canvasW, canvasH)
  love.graphics.setColor(1, 1, 1, 1)

  local sx, sy = screenshake.getOffset()
  love.graphics.push()
  love.graphics.translate(sx, sy)

  if boardAsset then
    love.graphics.draw(boardAsset, viewX, viewY, 0, viewScale * SCALE_X, viewScale * SCALE_Y)
  end
  love.graphics.setColor(0, 0, 0, 0.3)
  love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.pop()


  -- if not tutorialActive then
    love.graphics.setColor(0, 0, 0, 0.2)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(1, 1, 1, 1)
  -- end

  love.graphics.setCanvas(gameCanvas)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.push()
  love.graphics.translate(sx, sy)

  glow:renderBottom()
  Debris.drawAll()
  areas.drawStatic()
  if deck then deck:draw() end
  if camera then camera:draw() end
  if camera then camera:drawScannerLines(areas.scanner) end
  areas.drawScanners()
  areas.drawDynamic()
  hand:draw()
  Dtor.drawAll()
  particles.draw()
  Token.drawAll()
  message.draw()
  glow:renderMid()
  hand:drawDragged()
  glow:renderTop()
  gameOverScreen.draw()
  cardTooltip.draw()
  hoverTooltip.draw()
  love.graphics.pop()

  hud.draw()
  if tutorialActive then tutorial.draw() end

  overlayStats.draw()
  speedControl.draw()
  love.graphics.setCanvas()

  -- Blit the canvas onto the screen, centered and letterboxed
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setBlendMode("alpha", "premultiplied")
  love.graphics.draw(gameCanvas, viewX, viewY, 0, viewScale, viewScale)
  love.graphics.setBlendMode("alpha")
end

local function collectGlowRequests(mx, my)
  glowRequests.collectAll(glow, hand, deck, mx, my)
  cardTooltip.collectGlowRequests(glow)
end

function love.update(dt)
  realDt = dt
  gameDt = dt * config.speed
  screenshake.update(realDt)
  local mx, my = love.mouse.getPosition()
  local mouseX, mouseY = toGame(mx, my)
  Audio.update()
  overlayStats.update(dt)
  if tutorialActive then return end

  hud.update(mouseX, mouseY)
  pulse.update(realDt)
  message.update(realDt)
  progressBar.update(realDt)
  threatBar.update(realDt)
  envEffects.update(gameDt)
  particles.update(realDt)
  Debris.updateAll(gameDt)
  gameOverScreen.update(realDt, mouseX, mouseY)
  if gameOver then return end

  if camera then camera:update(realDt, mouseX, mouseY, areas.scanner) end
  laser.update(gameDt)
  hand:update(mouseX, mouseY)
  Token.updateAll(realDt, gameDt)
  Dtor.update(realDt)
  areas.updateScanners(gameDt)
  areas.updatePoolChips(gameDt, mouseX, mouseY)
  if not hand:isDragging() and not areas.endTurn.frozen then
    if areas.updateEndTurn(realDt, mouseX, mouseY) then
      actionQueue.push({
        card     = nil,
        terminal = true,
        fn       = function()
          hand:setActiveCardDraw(false)
          sequences.endTurn()
        end,
        onReject = function(_item)
          areas.endTurn.frozen    = false
          areas.endTurn.state     = "idle"
          areas.endTurn.hover.can = true
          areas.endTurn.click.can = false
        end,
      })
    end
  end
  local dk = areas.desk
  local function scannerRemaining(s)
    if s.direction == 1 then
      return ((dk.y + dk.h - s.y) + dk.h) / s.speed
    else
      return (s.y - dk.y) / s.speed
    end
  end
  if areas.scanner.left.active  then Token.triggerQuiverNear(areas.scanner.left.y,  nil, scannerRemaining(areas.scanner.left),  areas.scanner.left.direction)  end
  if areas.scanner.right.active then Token.triggerQuiverNear(areas.scanner.right.y, nil, scannerRemaining(areas.scanner.right), areas.scanner.right.direction) end
  events.updateAll()
  actionQueue.update()
  cardTooltip.clear()
  hoverTooltip.clear()
  hand:collectTooltipRequests()
  if hand:isDragging() then
    hover.update(-9999, -9999)
  else
    hover.update(mouseX, mouseY)
  end
  hover.collectTooltipRequests(hoverTooltip)
  cardTooltip.update(mouseX, mouseY)
  hoverTooltip.update()
  collectGlowRequests(mouseX, mouseY)
  glow:update(realDt)
end

function love.mousepressed(x, y, button, istouch, presses)
  local gx, gy = toGame(x, y)
  if speedControl.mousepressed(gx, gy, button) then return end
  if tutorialActive then
    tutorial.mousepressed(gx, gy, button)
    return
  end
  if gameOverScreen.mousepressed(gx, gy, button) then return end
  if hud.mousepressed(gx, gy, button) then return end
  Debris.mousePressed(gx, gy, button)
  hand:mousepressed(gx, gy, button, istouch)
end

function love.keyreleased(key)
  if key == "space" then
    config.speed = previousSpeed
    speedControl.setSpaceHeld(false)
  end
end

function love.keypressed(key)
  if key == "escape" and love.system.getOS() ~= "Web" then
    love.event.quit()
  elseif key == "r" then
    resetGame()
  elseif key == "return" then
    if tutorialActive then
      tutorialActive = false
    else
      -- resetGame()
      tutorialActive = true
    end
  elseif key == "s" then
    -- screenshake.trigger()
    print(events.get("terminalArrive").isRunning())
    print("Token all done: ", Token.allDone())
  elseif key == "q" then
    areas.scanner.left.active = not areas.scanner.left.active
  elseif key == "w" then
    areas.scanner.right.active = not areas.scanner.right.active
  elseif key == "tab" then
    config.cycleSpeed()
  elseif key == "space" then
    previousSpeed = config.speed
    config.speed = 3.0
    speedControl.setSpaceHeld(true)
  elseif key == "left" or key == "right" then
    local names   = Palette.variantNames()
    local current = Palette.getVariant()
    local idx     = 1
    for i, name in ipairs(names) do
      if name == current then idx = i; break end
    end
    if key == "right" then
      idx = (idx % #names) + 1
    else
      idx = ((idx - 2) % #names) + 1
    end
    Palette.setVariant(names[idx])
    print("Palette: " .. names[idx])
  elseif key == "o" then
    print(events.isRunning())
  elseif key == "p" then
    local GlowConfig = require("lib.glow.GlowConfig")
    GlowConfig.debug.disablePulse = not GlowConfig.debug.disablePulse
    print("[Glow] disablePulse=" .. tostring(GlowConfig.debug.disablePulse))
  elseif key == "g" then
    local GlowConfig = require("lib.glow.GlowConfig")
    GlowConfig.enabled = not GlowConfig.enabled
    print("[Glow] enabled=" .. tostring(GlowConfig.enabled))
  elseif key == "b" then
    local GlowConfig = require("lib.glow.GlowConfig")
    GlowConfig.debug.disableBlur = not GlowConfig.debug.disableBlur
    print("[Glow] disableBlur=" .. tostring(GlowConfig.debug.disableBlur))
  elseif key == "f6" then
    local tiers = { "high", "medium", "low", "mobileWeb", "fake" }
    local current = glow.qualityName
    local idx = 1
    for i, name in ipairs(tiers) do
      if name == current then idx = i; break end
    end
    local next = tiers[(idx % #tiers) + 1]
    glow:setQuality(next, canvasW, canvasH)
    print("[Glow] quality=" .. next)
  else
    overlayStats.handleKeyboard(key)
  end
end


function love.resize(w, h)
  updateViewport()
end

function love.touchpressed(id, x, y, dx, dy, pressure)
  if next(touches) == nil then
    maxTouches = 0
    touchStartTime = love.timer.getTime()
  end
  touches[id] = { x = x, y = y }
  local count = 0
  for _ in pairs(touches) do count = count + 1 end
  maxTouches = math.max(maxTouches, count)
  overlayStats.handleTouch(id, x, y, dx, dy, pressure)
end

function love.touchmoved(id, x, y)
  if touches[id] then
    touches[id] = { x = x, y = y }
  end
end

function love.touchreleased(id, x, y, dx, dy, pressure)
  touches[id] = nil
  if next(touches) == nil then
    local elapsed = love.timer.getTime() - touchStartTime
    if elapsed < TAP_THRESHOLD then
      if maxTouches == 3 then
        resetGame()
      elseif maxTouches == 2 then
        tutorialActive = not tutorialActive
      elseif maxTouches == 1 then
        local gx, gy = toGame(x, y)
        if tutorialActive then
          tutorial.touchpressed(gx, gy)
        elseif gameOverScreen.touchpressed(gx, gy) then
          -- handled
        else
          hud.touchpressed(gx, gy)
        end
      end
    end
    maxTouches = 0
  end
end
