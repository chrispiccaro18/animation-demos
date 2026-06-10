https = nil
local overlayStats = require("lib.overlayStats")
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

local Color = require("lib.color")

local shipAsset = nil
local dissolveShader = nil
local tiltShader = nil
screenshake = require("lib.screenshake")
-- local ramChipAsset = nil
-- local erdnaseAsset = nil
local hand = NewHand.new()
local deck = nil

local tokens = {}

local boardAsset = nil
local camera = nil

local dtorFont = nil

SCALE_X = love.graphics.getWidth() / 3840
SCALE_Y = love.graphics.getHeight() / 2160

function love.load()
  https = runtimeLoader.loadHTTPS()
  shipAsset = love.graphics.newImage("assets/main-ship.png")
  local cardBackAsset    = love.graphics.newImage("assets/kilo-card-back.png")
  -- ramChipAsset = love.graphics.newImage("assets/ram-chip-tiny.png")
  -- erdnaseAsset = love.graphics.newImage("assets/erdnase.png")

  Token.load()
  Dtor.load()
  camera = Camera.load()
  camera:setIdle()

  boardAsset = love.graphics.newImage(
    "assets/proto/board.png",
    { mipmaps = true }
  )
  boardAsset:setFilter("linear", "linear")
  boardAsset:setMipmapFilter("linear")

  dissolveShader = love.graphics.newShader("assets/dissolve.fs")
  tiltShader = love.graphics.newShader("assets/tilt.fs")
  Card.load(dissolveShader, tiltShader)
  areas.load()
  deck = Deck.new(40, love.graphics.getHeight() - 310, cardBackAsset)
  hand.deck = deck
  local projFont = love.graphics.newFont("assets/NotoSans-Medium.ttf", 36)
  dtorFont = love.graphics.newFont("assets/NotoSans-Medium.ttf", 64 * love.graphics.getHeight() / 2160)
  projectiles.ram = Projectile.new({ asset = love.graphics.newImage("assets/large-ram.png"), font = projFont })
  projectiles.ramChip = Projectile.new({ asset = love.graphics.newImage("assets/ram-chip.png"), font = projFont, animationExp = 18 })
  projectiles.ramChip2 = Projectile.new({ asset = love.graphics.newImage("assets/ram-chip.png"), font = projFont, animationExp = 18 })
  projectiles.progress = Projectile.new({ asset = love.graphics.newImage("assets/new-progress.png"), font = projFont, fontColor = {1, 1, 1, 1} })
  -- projectiles.progress = Projectile.new({ asset = love.graphics.newImage("assets/progress.png"), font = projFont, fontColor = {1, 1, 1, 1} })
  projectiles.threat = Projectile.new({ asset = love.graphics.newImage("assets/new-threat.png"), font = projFont, fontColor = {1, 1, 1, 1} })
  projectiles.spiderThreat = Projectile.new({ asset = love.graphics.newImage("assets/spider-guy-w-threat.png"), font = projFont, fontColor = {1, 1, 1, 1} })
  -- projectiles.threat = Projectile.new({ asset = love.graphics.newImage("assets/threat.png"), font = projFont, fontColor = {1, 1, 1, 1} })
  local scaleX = love.graphics.getWidth() / 3840
  local scaleY = love.graphics.getHeight() / 2160
  print("ScaleX: " .. scaleX .. ", ScaleY: " .. scaleY)

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
  events.load()
  overlayStats.load()
end

function love.draw()
  -- #12131A
  love.graphics.setColor(Color("#12131A"))
  -- love.graphics.setColor(hexToRGBA("#20222E"))
  love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
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


  -- if deck and hand:isDragging() then deck:draw() end
  -- if deck and not hand:isDragging() then deck:draw() end
  -- for _, proj in pairs(projectiles) do proj:draw() end
  -- areas.drawAfter(hand:isDragging())
  areas.drawStatic()
  Dtor.drawAll()
  if camera then camera:draw() end
  if camera then camera:drawScannerLines(areas.scanner) end
  hand:draw()
  Token.drawAll()
  areas.drawScanners()
  love.graphics.pop()

  -- if singleNewCard then
  --   singleNewCard:draw()
  -- end

  overlayStats.draw()
end

function love.update(dt)
  realDt = dt
  gameDt = dt * config.speed
  screenshake.update(realDt)
  local mouseX, mouseY = love.mouse.getPosition()
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
  Token.updateAll(realDt)
  Dtor.update(realDt)
  areas.updateScanners(realDt)
  if not hand:isDragging() and not areas.endTurn.frozen then
    if areas.updateEndTurn(realDt, mouseX, mouseY) then
      sequences.endTurn(hand)
    end
  end
  if areas.scanner.left.active  then Token.triggerQuiverNear(areas.scanner.left.y)  end
  if areas.scanner.right.active then Token.triggerQuiverNear(areas.scanner.right.y) end
  -- areas.update(mouseX, mouseY)
  -- for _, proj in pairs(projectiles) do proj:update() end
  events.update()
  overlayStats.update(dt)
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
  hand:mousepressed(x, y, button)
end

function love.keypressed(key)
  if key == "escape" and love.system.getOS() ~= "Web" then
    love.event.quit()
  elseif key == "space" then
    -- if hand.cards[1] then print(hand.cards[1].current.r) end
    areas.takeFromDestructorQueue()
  elseif key == "s" then
    screenshake.trigger()
  elseif key == "q" then
    areas.scanner.left.active = not areas.scanner.left.active
  elseif key == "w" then
    areas.scanner.right.active = not areas.scanner.right.active
  elseif key == "tab" then
    config.cycleSpeed()
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
  elseif key == "d" then
    -- areas.reorderDestructorQueue()
    -- print("here")
    local card = hand.cards[1]
    -- card:shake()

    if card then card:startReverseDissolve() end
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

function love.touchpressed(id, x, y, dx, dy, pressure)
  overlayStats.handleTouch(id, x, y, dx, dy, pressure)
end
