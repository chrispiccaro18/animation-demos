https = nil
SCALE_X = 0
SCALE_Y = 0
POSITIVE_ENV_EFFECTS = false
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
local AssetManifest = require("assets.manifest")
local RichText      = require("core.richText")
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
local gameOverScreen  = require("core.gameOverScreen")
local Run             = require("core.run")
local Profile         = require("core.profile")
local Unlocks         = require("core.unlocks")
local Escalation      = require("core.escalation")
local Settings        = require("lib.settings")
local cardPickScreen  = require("core.cardPickScreen")
local unlockCeremony  = require("core.unlockCeremony")
local menuScreen      = require("core.menuScreen")
local sandbox         = require("core.sandbox")
local optionsMenu     = require("core.optionsMenu")

local appState = "menu"

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
local menuCanvas = nil
local canvasW    = 0
local canvasH    = 0
local viewX      = 0
local viewY      = 0
local viewScale  = 1

local tutorialActive      = true
local _levelCompleteTimer = nil
local _lossBoardCleared   = false
-- Hold after the board clears (post-flourish, see core/newSequences.lua's
-- resolveOutcome) before the unlock ceremony/card-pick screen appears.
local LEVEL_COMPLETE_HOLD = 1.5

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

local resetGame   -- forward declaration (cardPickScreen needs the reference before definition)
local function fullReset()
  Run.newRun()
  resetGame()
end

local function showMenu()
  sandbox.refreshUnlocks()
  sequences.setSandboxMode(true)
  menuScreen.show()
end

-- Shared board/UI reset -- used to start a fresh level, load a save, return
-- to the menu mid-run, and to clear the board after a win/loss resolves
-- (see the gameOver == "levelComplete" branch and the loss fallthrough in
-- love.update). Leaves deck/hand/dtor/progress/threat/ram construction, and
-- the gameOver/_levelCompleteTimer/_lossBoardCleared flow flags, to the
-- caller -- those mean different things depending on why the board is
-- being cleared.
-- opts.keepMessage (bool): skip clearing the message singleton -- used by
-- the win/loss one-shot clears so "LEVEL COMPLETE"/"FAILURE" stays on
-- screen through the ceremony/pick or gameOverScreen hand-off instead of
-- getting wiped the instant the board clears.
local function resetBoardState(opts)
  opts = opts or {}
  events.loadAll()
  actionQueue.reset()
  Token.clearAll()
  Debris.clearAll()
  Dtor.reset()
  laser.hide()

  progressBar.reset()
  threatBar.reset()
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
  if not opts.keepMessage then
    message.text          = ""
    message.subtitle      = ""
    message.textColor     = { 1, 1, 1, 1 }
    message.current       = { scale = 1, alpha = 1.0 }
    message.target        = { scale = 1, alpha = 1.0 }
  end
  gameOverScreen.reset()
  if camera then camera:setIdle() end

  hand = NewHand.new()
  deck = Deck.new(220 * SCALE_X, 1840 * SCALE_Y, cardBackAsset)
  hover.setDeck(deck)
  sequences.setDeck(deck)
  sequences.setHand(hand)
end

resetGame = function()
  resetBoardState()
  gameOver              = nil
  _levelCompleteTimer   = nil
  _lossBoardCleared      = false

  for i, cardData in ipairs(Run.getCurrentDeckData()) do
    local card = Card.new(canvasW / 2, canvasH / 2, cardData)
    card.deckIndex = i
    deck:add(card)
  end
  deck:shuffle()

  envEffects.syncState()
  sequences.beginTurn()

  -- message.text          = "LEVEL 0 START"
  -- message.textColor     = Palette.accent
  -- -- message.textColor     = { 0.9, 0.9, 1.0, 1.0 }
  -- message.current.scale = 6
  -- message.target.scale  = 1.0
  -- message.current.alpha = 0.0
  -- message.target.alpha  = 1.0
  -- events.push({
  --   fn = function()
  --     message.text          = ""
  --     message.current.alpha = 0.0
  --     message.target.alpha  = 1.0
  --   end,
  --   blocking = false, blockable = false, persistent = false,
  --   delay = 1.5, type = "before",
  -- })
  -- local ram1X, ram1Y = areas.randomPoolPosition()
  -- areas.addPoolChip(ram1X, ram1Y)
  -- local ram2X, ram2Y = areas.randomPoolPosition()
  -- areas.addPoolChip(ram2X, ram2Y)
end

-- Rebuild the board from Run.getSavedTurn() (populated by a prior Run.load()),
-- reproducing the exact drawPile/hand/dtor/progress/threat/ram snapshot that
-- was captured right after the last beginTurn finished dealing.
local function loadGame()
  local saved = Run.getSavedTurn()
  if not saved then return end

  resetBoardState()
  gameOver              = nil
  _levelCompleteTimer   = nil
  _lossBoardCleared      = false

  local deckData     = Run.getCurrentDeckData()
  local cardsByIndex = {}
  local function cardFor(i)
    if not cardsByIndex[i] then
      local card = Card.new(canvasW / 2, canvasH / 2, deckData[i])
      card.deckIndex = i
      cardsByIndex[i] = card
    end
    return cardsByIndex[i]
  end

  for _, idx in ipairs(saved.drawPile) do
    deck:add(cardFor(idx))
  end

  for _, idx in ipairs(saved.hand) do
    hand:add(cardFor(idx), false, false)
  end
  hand:layout()
  for _, card in ipairs(hand.cards) do
    card.current.x     = card.target.x
    card.current.y     = card.target.y
    card.current.scale = card.scales.idle
    card.target.scale  = card.scales.idle
  end

  for _, entry in ipairs(saved.dtor.entries) do
    Dtor.restoreEntry(cardFor(entry.deckIndex), entry.slotIndex, entry.nullified)
  end
  for _, slotIdx in ipairs(saved.dtor.preNullifiedSlots) do
    Dtor.restorePreNullifiedSlot(slotIdx)
  end
  if Dtor.hasEntry() then Dtor.showText() end

  progressBar.setCount(saved.progress)
  threatBar.setCount(saved.threat)
  for _ = 1, (saved.ram or 0) do
    local x, y = areas.randomPoolPosition()
    areas.addPoolChip(x, y)
  end

  local level = Run.getLevel()

  if level > 0 then
    local flingAcc = Token.makeCascadeAccumulator()
    -- Pre-compute each token's launch delay so the env anim can hold at peak
    -- until the final token is flung. The last delay is the time (from the
    -- first fling) until the last token launches.
    local flingDelays = {}
    for i = 1, level do flingDelays[i] = flingAcc:nextDelay() end
    local holdDuration = flingDelays[level] or 0

    -- Trigger the anim once, pinned at full scale for the whole cascade.
    events.push({
      fn = function() envEffects.triggerAnim("negative", holdDuration) end,
      blocking = false, blockable = true, persistent = false,
      delay = 0, type = "immediate",
    })

    local function endTurnFlingOptions(token_type, direction, acc)
    local flingDirection = direction or "downward"

    return {
      type       = token_type,
      bounces    = math.random(1, 3),
      base_scale = 1.25,
      delay      = acc and acc:nextDelay() or false,
      target_rect = areas.flingTarget,
      [flingDirection] = true,
    }
  end

    local highestLevel = Profile.getHighestLevelReached()
    local sequence = Escalation.pickSequence(level, Run.getTurn(), Run.getRunSeed(), highestLevel)

    for i = 1, level do
      local d = flingDelays[i]
      events.push({
        fn = function()
          local x, y = envEffects.getPosition("negative")
          local tokenType = sequence[i]
          local opts = endTurnFlingOptions(tokenType, "rightward")
          opts.delay = d
          Token.new_fling(x, y, areas.desk, opts)
          Audio.playImpactIn()
        end,
        blocking = false, blockable = true, persistent = false,
        delay = 0, type = "immediate",
      })
    end
    events.push({
      fn = function() return Token.allDone() end,
      blocking = true, blockable = true, persistent = false,
      delay = 0, type = "poll",
    })
    events.push({
      fn = function()
        Token.attractDone("ram", areas.pool, {
        onArrive = function()
          Audio.playRamImpact()
        end
      })
      end,
      blocking = true, blockable = true, persistent = false,
      delay = 0, type = "immediate",
    })
    events.push({
      fn = function()
        return Token.allDone()
      end,
      blocking = true, blockable = true, persistent = false,
      delay = 0, type = "poll"
    })
    events.push({
      fn = function()
        local ramTokens = Token.removeDone("ram")
        for _, t in ipairs(ramTokens) do
          areas.addPoolChip(t.x, t.y)
        end
      end,
      blocking = true, blockable = true, persistent = false,
      delay = 0.1, type = "after"
    })
  end

  envEffects.syncState()
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
  RichText.load()
  Audio.load()
  local settings = Settings.load()
  love.audio.setVolume(settings.volume)
  config.speedIndex = settings.speedIndex
  config.speed      = config.speedPresets[settings.speedIndex] or config.speed

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
  envEffects.load(areas.leftLine)
  hover.load()
  message.load()
  particles.load()
  deck = Deck.new(220 * SCALE_X, 1840 * SCALE_Y, cardBackAsset)
  sequences.setDeck(deck)
  sequences.setHand(hand)
  sandbox.setDeckAndHand(deck, hand)
  print("ScaleX: " .. SCALE_X .. ", ScaleY: " .. SCALE_Y)

  events.loadAll()
  overlayStats.load()
  speedControl.load()

  gameCanvas = love.graphics.newCanvas(canvasW, canvasH)
  menuCanvas = love.graphics.newCanvas(canvasW, canvasH)
  overlayStats.setGameCanvas(gameCanvas)
  updateViewport()

  glow = Glow.load(canvasW, canvasH)
  glow:setQuality(settings.glowQuality, canvasW, canvasH)
  hud.load(
    function() tutorialActive = true end,
    fullReset,
    function() love.system.openURL("https://forms.gle/sjbzYgS94u2w27iq5") end
  )
  gameOverScreen.load(fullReset)
  cardPickScreen.load(resetGame)
  unlockCeremony.load()

  Profile.setActive(1) -- no profile picker yet; always resume/create profile 1
  Run.newRun()
  sandbox.init()

  optionsMenu.load({
    getGlowQuality = function() return glow.qualityName end,
    setGlowQuality = function(q) glow:setQuality(q, canvasW, canvasH) end,
  })

  menuScreen.load(
    function()  -- Continue
      if Run.load() then loadGame() end
      appState = "game"
      sequences.setSandboxMode(false)
      menuScreen.hide()
    end,
    function()  -- New Run
      fullReset()
      appState = "game"
      sequences.setSandboxMode(false)
      menuScreen.hide()
    end,
    function()  -- Options
      optionsMenu.show()
    end,
    love.system.getOS() ~= "Web" and function() love.event.quit() end or nil
  )
  showMenu()
end

function love.draw()
  local sx, sy = screenshake.getOffset()
  local activeCanvas

  -- Full-window background always covers the letterbox bars, regardless of
  -- what's centered in the 16:9 canvas on top of it.
  love.graphics.setColor(Palette.void)
  love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
  love.graphics.setColor(1, 1, 1, 1)

  if appState == "menu" then
    love.graphics.setCanvas(menuCanvas)
    love.graphics.clear(0, 0, 0, 0)

    love.graphics.push()
    love.graphics.translate(sx, sy)
    glow:renderBottom()
    Debris.drawAll()
    sandbox.drawScene()
    particles.draw()
    Token.drawAll()
    glow:renderMid()
    glow:renderTop()
    love.graphics.pop()
    sandbox.draw()
    menuScreen.draw()
    optionsMenu.draw()
    hoverTooltip.draw()

    activeCanvas = menuCanvas
  else  -- "game"
    love.graphics.push()
    love.graphics.translate(sx, sy)
    if boardAsset then
      love.graphics.draw(boardAsset, viewX, viewY, 0, viewScale * SCALE_X, viewScale * SCALE_Y)
    end
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.pop()

    love.graphics.setColor(0, 0, 0, 0.2)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(1, 1, 1, 1)

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
    envEffects.draw()
    message.draw()
    glow:renderMid()
    hand:drawDragged()
    gameOverScreen.draw()
    unlockCeremony.draw()
    cardPickScreen.draw()
    glow:renderTop()
    hoverTooltip.draw()
    cardTooltip.draw()
    love.graphics.pop()
    hud.draw()
    if tutorialActive then tutorial.draw() end

    activeCanvas = gameCanvas
  end

  overlayStats.draw()
  love.graphics.setCanvas()

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setBlendMode("alpha", "premultiplied")
  love.graphics.draw(activeCanvas, viewX, viewY, 0, viewScale, viewScale)
  love.graphics.setBlendMode("alpha")
end

local function collectGlowRequests(mx, my)
  glowRequests.collectAll(glow, hand, deck, mx, my)
  cardTooltip.collectGlowRequests(glow)
  cardPickScreen.collectGlowRequests(glow)
  unlockCeremony.collectGlowRequests(glow)
end

function love.update(dt)
  realDt = dt
  gameDt = dt * config.speed
  screenshake.update(realDt)
  local mx, my = love.mouse.getPosition()
  local mouseX, mouseY = toGame(mx, my)
  Audio.update()
  overlayStats.update(dt)

  if appState == "menu" then
    if optionsMenu.isActive() then
      optionsMenu.update(mouseX, mouseY)
    else
      menuScreen.update(mouseX, mouseY)
      sandbox.update(dt, mouseX, mouseY)
      hoverTooltip.clear()
      sandbox.collectTooltipRequests()
      hoverTooltip.update()
    end
    pulse.update(realDt)
    particles.update(realDt)
    Debris.updateAll(gameDt)
    Token.updateAll(realDt, gameDt)
    Dtor.update(realDt)
    progressBar.update(realDt)
    threatBar.update(realDt)
    events.updateAll()
    glow:update(realDt)
    return
  end

  if tutorialActive then return end

  hud.update(mouseX, mouseY)
  pulse.update(realDt)
  message.update(realDt)

  -- Level complete: show celebration message, then transition to the unlock
  -- ceremony (if this level crossed a token-unlock threshold) and the card
  -- pick screen
  if gameOver == "levelComplete" then
    if not _levelCompleteTimer then
      -- First frame after resolveOutcome's flourish finished (see
      -- core/newSequences.lua) -- clear the settled board before the
      -- ceremony/pick screen dims in over it. Keep the "LEVEL COMPLETE"
      -- message up through the hold below.
      resetBoardState({ keepMessage = true })
    end
    _levelCompleteTimer = (_levelCompleteTimer or 0) + realDt
    if _levelCompleteTimer >= LEVEL_COMPLETE_HOLD then
      gameOver              = nil
      _levelCompleteTimer   = nil

      local oldHighest = Profile.getHighestLevelReached()
      local newHighest = Run.getLevel() + 1 -- level the player is about to start
      Profile.reportLevelReached(newHighest)
      local newlyUnlocked = Unlocks.newlyUnlocked(oldHighest, newHighest)

      local function showPick()
        cardPickScreen.show(Run.getOfferCards(Profile.getHighestLevelReached()))
      end

      if #newlyUnlocked > 0 then
        unlockCeremony.show(newlyUnlocked, showPick)
      else
        showPick()
      end
    end
    return
  end

  -- Unlock ceremony: handle its own update + tooltips
  if unlockCeremony.isActive() then
    unlockCeremony.update(realDt, mouseX, mouseY)
    cardTooltip.clear()
    hoverTooltip.clear()
    unlockCeremony.collectTooltipRequests()
    cardTooltip.update(mouseX, mouseY)
    hoverTooltip.update()
    collectGlowRequests(mouseX, mouseY)
    glow:update(realDt)
    return
  end

  -- Card pick screen: handle its own update + tooltips
  if cardPickScreen.isActive() then
    cardPickScreen.update(realDt, mouseX, mouseY)
    cardTooltip.clear()
    hoverTooltip.clear()
    cardPickScreen.collectTooltipRequests()
    cardTooltip.update(mouseX, mouseY)
    hoverTooltip.update()
    collectGlowRequests(mouseX, mouseY)
    glow:update(realDt)
    return
  end

  progressBar.update(realDt)
  threatBar.update(realDt)
  envEffects.update(gameDt)
  particles.update(realDt)
  Debris.updateAll(gameDt)
  gameOverScreen.update(realDt, mouseX, mouseY)
  if gameOver then
    if gameOver == "loss" and not _lossBoardCleared then
      -- First frame after resolveOutcome's flourish finished -- clear the
      -- settled board so gameOverScreen's buttons fade in over a clean
      -- state instead of the frozen failure board. Keep the "FAILURE"
      -- message up since gameOverScreen has no background of its own.
      _lossBoardCleared = true
      resetBoardState({ keepMessage = true })
    end
    return
  end

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
  if areas.scanner.both.active then Token.triggerQuiverNear(areas.scanner.both.y, nil, scannerRemaining(areas.scanner.both), areas.scanner.both.direction) end
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
  if appState == "menu" then
    if optionsMenu.isActive() then
      optionsMenu.mousepressed(gx, gy, button)
    else
      local consumed = sandbox.mousepressed(gx, gy, button)
      if not consumed then consumed = menuScreen.mousepressed(gx, gy, button) end
      if not consumed then Debris.mousePressed(gx, gy, button) end
    end
    return
  end
  if tutorialActive then
    tutorial.mousepressed(gx, gy, button)
    return
  end
  if unlockCeremony.isActive() then
    unlockCeremony.mousepressed(gx, gy, button)
    return
  end
  if cardPickScreen.isActive() then
    cardPickScreen.mousepressed(gx, gy, button)
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
    if optionsMenu.isActive() then
      optionsMenu.hide()
    elseif appState == "game" then
      resetBoardState()
      gameOver              = nil
      _levelCompleteTimer   = nil
      _lossBoardCleared      = false
      appState = "menu"
      showMenu()
    else
      love.event.quit()
    end
  elseif key == "r" and appState == "game" then
    fullReset()
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
        if appState == "game" then fullReset() end
      elseif maxTouches == 2 then
        if appState == "game" then tutorialActive = not tutorialActive end
      elseif maxTouches == 1 then
        local gx, gy = toGame(x, y)
        if appState == "menu" then
          if optionsMenu.isActive() then
            optionsMenu.touchpressed(gx, gy)
          elseif not sandbox.touchpressed(gx, gy) then
            menuScreen.touchpressed(gx, gy)
          end
        elseif tutorialActive then
          tutorial.touchpressed(gx, gy)
        elseif unlockCeremony.isActive() then
          unlockCeremony.touchpressed(gx, gy)
        elseif cardPickScreen.isActive() then
          cardPickScreen.touchpressed(gx, gy)
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
