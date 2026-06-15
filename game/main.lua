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
local Projectile   = require("core.projectile")
local projectiles  = require("core.projectiles")
local sequences    = require("core.newSequences")
local Deck         = require("core.deck")
local Camera       = require("core.camera")
local Token        = require("core.token")
local laser        = require("core.laser")
local Dtor         = require("core.dtor")
local CardData     = require("data.cards")

local Color = require("lib.color")

local touches = {}

local shipAsset = nil
local cardBackAsset = nil
local dissolveShader = nil
local tiltShader = nil
screenshake = require("lib.screenshake")
gameOver = nil
-- local ramChipAsset = nil
-- local erdnaseAsset = nil
local hand = NewHand.new()
local deck = nil

local tokens = {}

local boardAsset = nil
local camera = nil

local dtorFont = nil
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
  areas.destructor.queue = {}
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
  deck:shuffle()

  for _ = 1, 4 do
    sequences.dealCardToHand(hand)
  end

  camera:setIdle()
end

function love.load()
  https = runtimeLoader.loadHTTPS()
  shipAsset = love.graphics.newImage("assets/main-ship.png")
  cardBackAsset = love.graphics.newImage("assets/kilo-card-back.png")
  -- ramChipAsset = love.graphics.newImage("assets/ram-chip-tiny.png")
  -- erdnaseAsset = love.graphics.newImage("assets/erdnase.png")

  Token.load()
  Dtor.load()
  camera = Camera.load()
  camera:setIdle()

  boardAsset = love.graphics.newImage(
    "assets/proto/board.png"
  )
  boardAsset:setFilter("linear", "linear")
  -- boardAsset:setMipmapFilter("linear")

  dissolveShader = love.graphics.newShader("assets/dissolve.fs")
  tiltShader = love.graphics.newShader("assets/tilt.fs")
  Card.load(dissolveShader, tiltShader)
  areas.load()
  deck = Deck.new(220 * SCALE_X, 1840 * SCALE_Y, cardBackAsset)
  sequences.setDeck(deck)
  local projFont = love.graphics.newFont("assets/NotoSans-Medium.ttf", 36)
  dtorFont = love.graphics.newFont("assets/NotoSans-Medium.ttf", 64 * SCALE_Y)
  projectiles.ram = Projectile.new({ asset = love.graphics.newImage("assets/large-ram.png"), font = projFont })
  projectiles.ramChip = Projectile.new({ asset = love.graphics.newImage("assets/ram-chip.png"), font = projFont, animationExp = 18 })
  projectiles.ramChip2 = Projectile.new({ asset = love.graphics.newImage("assets/ram-chip.png"), font = projFont, animationExp = 18 })
  projectiles.progress = Projectile.new({ asset = love.graphics.newImage("assets/new-progress.png"), font = projFont, fontColor = {1, 1, 1, 1} })
  -- projectiles.progress = Projectile.new({ asset = love.graphics.newImage("assets/progress.png"), font = projFont, fontColor = {1, 1, 1, 1} })
  projectiles.threat = Projectile.new({ asset = love.graphics.newImage("assets/new-threat.png"), font = projFont, fontColor = {1, 1, 1, 1} })
  projectiles.spiderThreat = Projectile.new({ asset = love.graphics.newImage("assets/spider-guy-w-threat.png"), font = projFont, fontColor = {1, 1, 1, 1} })
  -- projectiles.threat = Projectile.new({ asset = love.graphics.newImage("assets/threat.png"), font = projFont, fontColor = {1, 1, 1, 1} })
  print("ScaleX: " .. SCALE_X .. ", ScaleY: " .. SCALE_Y)

  -- local exampleData = {
  --   topEnergy    = 3,
  --   bottomEnergy = 3,
  --   play    = { { type = "progress", value = 1 }, { type = "progress", value = 1 }, { type = "nullify",  value = 1 } },
  --   discard = { { type = "progress", value = 1 }, { type = "threat",   value = 1 }, { type = "nullify",  value = 1 } },
  --   dtor = { { type = "threat", value = 1 }, { type = "threat",   value = 1 }, { type = "threat",  value = 1 } },
  -- }

  local exampleData = {
    topEnergy    = 1,
    bottomEnergy = 1,
    play    = { { type = "progress", value = 1 }, { type = "nullify", value = 1 } },
    discard = { { type = "threat", value = 1 }, { type = "threat",   value = 1 } },
    dtor = { { type = "threat", value = 1 }, { type = "threat",   value = 1 } },
  }
  local exampleData2 = {
    topEnergy    = 2,
    bottomEnergy = 2,
    play    = { { type = "progress", value = 1 }, { type = "progress", value = 1 } },
    discard = { { type = "threat", value = 1 }, { type = "nullify",   value = 1 } },
    dtor = { { type = "threat", value = 1 }, { type = "threat",   value = 1 }, { type = "threat",   value = 1 } },
  }

  -- for _ = 1, 2 do
  --   deck:add(Card.new(0, 0, exampleData))
  -- end

  for _ = 1, 3 do
    local card = Card.new(
      love.graphics.getWidth() / 2,
      love.graphics.getHeight() / 2,
      exampleData
    )
    hand:add(card, true, true)
  end
  for _ = 1, 2 do
    local card = Card.new(
      love.graphics.getWidth() / 2,
      love.graphics.getHeight() / 2,
      exampleData2
    )
    hand:add(card, true, true)
  end
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
  -- if shipAsset then
  --   love.graphics.draw(shipAsset, 0, 0)
  -- end
  if boardAsset then
    love.graphics.draw(boardAsset, 0, 0, 0, SCALE_X, SCALE_Y)
  end
  -- areas.drawBefore(hand:isDragging())


  -- for _, proj in pairs(projectiles) do proj:draw() end
  -- areas.drawAfter(hand:isDragging())
  areas.drawStatic()
  Dtor.drawAll()
  if camera then camera:draw() end
  if camera then camera:drawScannerLines(areas.scanner) end
  if deck then deck:draw() end
  hand:draw()
  Token.drawAll()
  areas.drawScanners()
  love.graphics.pop()

  -- if singleNewCard then
  --   singleNewCard:draw()
  -- end

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
  if gameOver then return end
  local mx, my = love.mouse.getPosition()
  local mouseX, mouseY = toGame(mx, my)
  -- if singleNewCard then
  -- --   if singleNewCard:containsPoint(mouseX, mouseY) and singleNewCard.hover.can then
  -- --    singleNewCard.hover.is = true
  -- --    singleNewCard.hover.can = false
  -- --    singleNewCard.target.scale = 0.75
  -- --  else
  -- --    singleNewCard.hover.is = false
  -- --    singleNewCard.hover.can = true
  -- --    singleNewCard.target.scale = 0.5
  -- --  end
  --   -- singleNewCard:update(realDt, mouseX, mouseY)

  --   if singleNewCard.drag.is and camera then
  --     if areas.mouseInPlay(mouseX, mouseY) then
  --       camera:setColor(Color("#6ED59E"))
  --       singleNewCard:moveToPlay()
  --     elseif areas.mouseInDiscard(mouseX, mouseY) then
  --       camera:setColor(Color("#D56E6E"))
  --       singleNewCard:moveToDiscard()
  --     else
  --       camera:setColor(Color("#FFFFFF"))
  --       singleNewCard:returnToIdle()
  --     end
  --   end
  -- end
  if camera then camera:update(realDt, mouseX, mouseY, areas.scanner) end
  laser.update(realDt)
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
  -- areas.update(mouseX, mouseY)
  -- for _, proj in pairs(projectiles) do proj:update() end
  events.updateAll()
end

function love.mousepressed(x, y, button, istouch, presses)
  -- if singleNewCard and button == 1 and singleNewCard:containsPoint(x, y) then
  --   print("Clicked on single new card!")
  --   singleNewCard.drag.is = true
  --   singleNewCard.drag.can = false
  --   singleNewCard.hover.is = false
  --   singleNewCard.hover.can = false
  --   singleNewCard.target.scale = 1.0
  -- end
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
  elseif key == "1" then
    -- local card = hand.cards[1]
    -- if card then sequences.popTopOff(card, areas) end
  elseif key == "n" then
    if deck then
      -- local card = deck:deal()
      -- if card then hand:add(card, false) end
    end
  elseif key == "2" then
    -- local card = hand.cards[1]
    -- if card then sequences.insertMiddle(card) end
  elseif key == "f" then
    if deck then
      local card = deck:deal()
      if card then hand:add(card, false, true) end
    end
  elseif key == "d" then
    -- areas.reorderDestructorQueue()
    -- print("here")
    local card = hand.cards[1]
    events.push({
      fn = function()
        if card and deck then
          card.target.x = deck:position().x
          card.target.y = deck:position().y
          card.target.scale = 0.0
          card._excluded = true
          card.drawShadow = false
          card.hover.can = false
          card.hover.is  = false
          card.drag.can  = false
        end
      end,
      blocking = true, blockable = true, persistent = false,
      delay = 0, type = "immediate",
    })
    events.push({
      fn = function()
        return card:isAtTarget()
      end,
      blocking = true, blockable = true, persistent = false,
      delay = 0, type = "poll",
    })
    events.push({
      fn = function()
        if card then hand:remove(card) end
        if deck then
          deck:add(card)
        end
      end,
      blocking = true, blockable = true, persistent = false,
      delay = 0, type = "immediate",
    })
    -- local card = deck:deal()
    -- if card then
    --   hand:add(card, false, true)
    -- end
    -- card:shake()

    -- if card then card:startReverseDissolve() end
    -- if card then
    --   print("Starting dissolve on card")
    --   card:startDissolve()
    -- end

    -- events.push({
    --   fn = function()
    --     projectiles.ramChip:launch(
    --       card.current.x + card.w - 67,
    --       card.current.y + card.h - 40,
    --       card.current.x + card.w - 67,
    --       card.current.y + card.h - 40,
    --       ""
    --     )
    --     local increase = 1.5
    --    projectiles.spiderThreat:launch(
    --     card.target.x + 90,
    --     card.target.y + 180,
    --     card.target.x + 90,
    --     card.target.y + 180,
    --     ""
    --   )
    --   end,
    --   blocking = true, blockable = true, persistent = false,
    --   delay = 0, type = "immediate",
    -- })
    -- events.push({
    --   fn = function()
    --     projectiles.ramChip2:launch(
    --       card.current.x + card.w - 40,
    --       card.current.y + card.h - 40,
    --       card.current.x + card.w - 40,
    --       card.current.y + card.h - 40,
    --       ""
    --     )
    --   end,
    --   blocking = true, blockable = true, persistent = false,
    --   delay = 0.7, type = "after",
    -- })
    -- events.push({
    --   fn = function()
    --     projectiles.ramChip:launch(
    --       projectiles.ramChip.current.x,
    --       projectiles.ramChip.current.y,
    --       areas.discard.x + areas.discard.w / 2,
    --       areas.discard.current.y + areas.discard.h / 2,
    --       ""
    --     )
    --   end,
    --   blocking = true, blockable = true, persistent = false,
    --   delay = 0.25, type = "after",
    -- })
    -- events.push({
    --   fn = function()
    --     projectiles.ramChip2:launch(
    --       projectiles.ramChip2.current.x,
    --       projectiles.ramChip2.current.y,
    --       areas.discard.x + areas.discard.w / 2 + 40,
    --       areas.discard.current.y + areas.discard.h / 2,
    --       ""
    --     )
    --   end,
    --   blocking = true, blockable = true, persistent = false,
    --   delay = 0.7, type = "after",
    -- })
  elseif key == "0" then
    table.insert(tokens, Token.new_fling(
      love.graphics.getWidth() / 2,
      love.graphics.getHeight() / 2,
      {
        x = areas.desk.x + areas.desk.w / 2,
        y = areas.desk.y,
        w = areas.desk.w / 2,
        h = areas.desk.h / 2,
      },
      {
        bounces = math.random(2, 3),
        type = "progress",
      }
    ))
    -- table.insert(tokens, Token.new_fling(
    --   love.graphics.getWidth() / 2,
    --   love.graphics.getHeight() / 2,
    --   {
    --     x = areas.desk.x + areas.desk.w / 2,
    --     y = areas.desk.y,
    --     w = areas.desk.w / 2,
    --     h = areas.desk.h / 2,
    --   },
    --   {
    --     bounces = math.random(2, 3),
    --     type = "threat",
    --   }
    -- ))
    -- table.insert(tokens, Token.new_fling(
    --   love.graphics.getWidth() / 2,
    --   love.graphics.getHeight() / 2,
    --   {
    --     x = areas.desk.x + areas.desk.w / 2,
    --     y = areas.desk.y,
    --     w = areas.desk.w / 2,
    --     h = areas.desk.h / 2,
    --   },
    --   {
    --     bounces = math.random(2, 3),
    --     type = "ram",
    --   }
    -- ))
    -- table.insert(tokens, Token.new_fling(
    --   love.graphics.getWidth() / 2,
    --   love.graphics.getHeight() / 2,
    --   {
    --     x = areas.desk.x + areas.desk.w / 2,
    --     y = areas.desk.y,
    --     w = areas.desk.w / 2,
    --     h = areas.desk.h / 2,
    --   },
    --   {
    --     bounces = math.random(2, 3),
    --     type = "nullify",
    --   }
    -- ))

    -- table.insert(tokens, Token.new_attract(
    --   love.graphics.getWidth() / 2,
    --   love.graphics.getHeight() / 2,
    --   areas.desk.x,
    --   areas.desk.y
    -- ))
    -- local card = hand.cards[1]
    -- if card then
      -- card:clearParts()
      -- card:resetDissolve()
    -- end
  -- elseif key == "k" then
  --   -- local klak = areas.klak
  --   -- if klak.target.y == klak.upY then
  --   --   klak.target.y = klak.downY
  --   -- else
  --   --   klak.target.y = klak.upY
  --   -- end
  --   if singleNewCard then
  --     singleNewCard:moveToDiscard()
  --   end
  -- elseif key == "l" then
  --   if singleNewCard then
  --     singleNewCard:moveToPlay()
  --   end
  -- elseif key == "j" then
  --   if singleNewCard then
  --     singleNewCard:returnPartsToOrigin()
  --     singleNewCard:revealAllParts()
  --   end
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
