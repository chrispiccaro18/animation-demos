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
local sequences    = require("core.sequences")

local shipAsset = nil
local dissolveShader = nil
-- local ramChipAsset = nil
-- local erdnaseAsset = nil
local hand = Hand.new()

function love.load()
  https = runtimeLoader.loadHTTPS()
  shipAsset = love.graphics.newImage("assets/main-ship.png")
  -- local cardAsset        = love.graphics.newImage("assets/card-back-no-color.png")
  local cardAsset        = love.graphics.newImage("assets/kilo-card-base.png")
  -- local cardAsset        = love.graphics.newImage("assets/card-template-front-flipped.png")
  local chompedCardAsset = love.graphics.newImage("assets/chomped-card.png")
  -- ramChipAsset = love.graphics.newImage("assets/ram-chip-tiny.png")
  -- erdnaseAsset = love.graphics.newImage("assets/erdnase.png")
  dissolveShader = love.graphics.newShader("assets/dissolve.fs")
  areas.load()
  local projFont = love.graphics.newFont("assets/NotoSans-Medium.ttf", 36)
  projectiles.ram = Projectile.new({ asset = love.graphics.newImage("assets/large-ram.png"), font = projFont })
  projectiles.ramChip = Projectile.new({ asset = love.graphics.newImage("assets/ram-chip.png"), font = projFont, animationExp = 18 })
  projectiles.ramChip2 = Projectile.new({ asset = love.graphics.newImage("assets/ram-chip.png"), font = projFont, animationExp = 18 })
  projectiles.progress = Projectile.new({ asset = love.graphics.newImage("assets/new-progress.png"), font = projFont, fontColor = {1, 1, 1, 1} })
  -- projectiles.progress = Projectile.new({ asset = love.graphics.newImage("assets/progress.png"), font = projFont, fontColor = {1, 1, 1, 1} })
  projectiles.threat = Projectile.new({ asset = love.graphics.newImage("assets/new-threat.png"), font = projFont, fontColor = {1, 1, 1, 1} })
  projectiles.spiderThreat = Projectile.new({ asset = love.graphics.newImage("assets/spider-guy-w-threat.png"), font = projFont, fontColor = {1, 1, 1, 1} })
  -- projectiles.threat = Projectile.new({ asset = love.graphics.newImage("assets/threat.png"), font = projFont, fontColor = {1, 1, 1, 1} })
  local card = Card.new(600, 400, cardAsset, chompedCardAsset)
  card.partAssets = {
    base         = cardAsset,
    -- top          = love.graphics.newImage("assets/card-top-play.png"),
    -- middle       = love.graphics.newImage("assets/card-middle-discard.png"),
    -- bottom       = love.graphics.newImage("assets/card-bottom-dtor.png"),
    -- middleTop    = love.graphics.newImage("assets/card-middle-top.png"),
    -- middleBottom = love.graphics.newImage("assets/card-middle-bottom.png"),
    ramChip      = love.graphics.newImage("assets/ram-chip.png"),
    spiderGuy     = love.graphics.newImage("assets/spider-guy.png"),
    threat = love.graphics.newImage("assets/new-threat.png"),
    progress = love.graphics.newImage("assets/new-progress.png"),
  }
  card:setParts({
    { id = "base", asset = card.partAssets.base, yOffset = 0},
    { id = "ramChip", asset = card.partAssets.ramChip, xOffset = card.w - 67, yOffset = card.h - 40, },
    { id = "ramChip2", asset = card.partAssets.ramChip, xOffset = card.w - 40, yOffset = card.h - 40, },
    { id = "spiderGuy", asset = card.partAssets.spiderGuy, xOffset = 21, yOffset = 156, },
    { id = "threat", asset = card.partAssets.threat, xOffset = 67, yOffset = 164, },
    { id = "progress", asset = card.partAssets.progress, xOffset = 67, yOffset = 54, },
  })
  card.shader = dissolveShader
  hand:add(card)
  -- hand:add(Card.new(200, 400, cardAsset, chompedCardAsset))
  events.load()
  overlayStats.load()
end

local function hexToRGBA(hex)
  hex = hex:gsub("#", "")
  local r = tonumber(hex:sub(1, 2), 16) / 255
  local g = tonumber(hex:sub(3, 4), 16) / 255
  local b = tonumber(hex:sub(5, 6), 16) / 255
  -- local a = tonumber(hex:sub(7, 8), 16) / 255 or 1
  return {r, g, b, 1}
end

function love.draw()
  love.graphics.setColor(hexToRGBA("#20222E"))
  love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
  love.graphics.setColor(1, 1, 1, 1)
  -- if shipAsset then
  --   love.graphics.draw(shipAsset, 0, 0)
  -- end
  areas.drawBefore(hand:isDragging())
  -- if ramChipAsset then love.graphics.draw(ramChipAsset, 610, 410) end
  -- if ramChipAsset then love.graphics.draw(ramChipAsset, 635, 410) end
  hand:draw()
  -- if erdnaseAsset then love.graphics.draw(erdnaseAsset, 640, 520) end
  for _, proj in pairs(projectiles) do proj:draw() end
  areas.drawAfter(hand:isDragging())
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
  elseif key == "1" then
    local card = hand.cards[1]
    if card then sequences.popTopOff(card, areas) end
  elseif key == "2" then
    local card = hand.cards[1]
    if card then sequences.insertMiddle(card) end
  elseif key == "d" then
    local card = hand.cards[1]
    if card then card:startDissolve() end

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
    local card = hand.cards[1]
    if card then
      -- card:clearParts()
      card:resetDissolve()
    end
  else
    overlayStats.handleKeyboard(key)
  end
end

function love.touchpressed(id, x, y, dx, dy, pressure)
  overlayStats.handleTouch(id, x, y, dx, dy, pressure)
end
