local Button       = require("core.button")
local Token        = require("core.token")
local Manifest     = require("assets.manifest")
local Palette      = require("lib.palette")
local areas        = require("core.areas")
local events       = require("lib.events")
local progressBar  = require("core.progressBar")
local threatBar    = require("core.threatBar")
local Dtor         = require("core.dtor")
local Profile      = require("core.profile")
local Run          = require("core.run")
local Unlocks      = require("core.unlocks")
local UnlockLevels = require("data.unlocks")
local hoverTooltip = require("core.hoverTooltip")
local menuScreen   = require("core.menuScreen")
local animation    = require("lib.animation")
local Camera       = require("core.camera")
local laser        = require("core.laser")
local Card         = require("core.card")
local CardData     = require("data.cards")
local message      = require("core.message")
local Debris       = require("core.debris")
local actionQueue  = require("core.actionQueue")
local sequences    = require("core.newSequences")

local sandbox = {}

local TOKEN_TYPES = {
  "progress",
  "threat",
  "progressNegative",
  "threatNegative",
  "drawToHand",
  "drawToDtor",
  "nullify",
  "shuffle",
  "multiplyProgress",
  "multiplyThreat",
  "flip",
  "multiplyAll",
  -- "ram",
  -- "dtor",
  -- "dtor_null",
}

local function getTokenAsset(ttype)
  if ttype == "dtor" then
    return Manifest.get("card", "dtorSlot")
  elseif ttype == "dtor_null" then
    return Manifest.get("card", "emptyNullifySlot")
  else
    return Manifest.get("tokens", ttype)
  end
end

-- Layout constants (design units)
local BTN_SIZE = 150
local COL_GAP  = 10
local ROW_GAP  = 10
local PANEL_X  = 10
local PANEL_Y  = 70
local COLS     = 2

local TAB_W = 60
local TAB_GAP = 20
local TAB_COLLAPSED_X = 0
local TAB_TWEEN_RATE  = 24

local SCORE_CLEAR_W   = BTN_SIZE * 2 + COL_GAP
local SCORE_CLEAR_H   = 200
local SCORE_CLEAR_GAP = 20
local BOTTOM_MARGIN   = 40

local _selected    = nil -- kept only as "last flung" cosmetic marker; not a placement mode
local _scoreButton = nil
local _clearButton = nil
local _tab         = nil
local _iconButtons = {}
local _collapsed   = false
local _interacted  = false
local _panelShiftX = 0  -- how far the icon grid has slid left, mirroring the tab's travel

local _deck = nil
local _hand = nil

-- Contextual game-UI visibility: fades in fast while relevant token types are
-- on the desk, fades out slowly after a grace period once none are.
local HIDE_DELAY   = 1.2
local FADE_IN_RATE = 20
local FADE_OUT_RATE = 3

local function newFadeGroup()
  return {
    alpha = 0, hideTimer = 0, justHidden = false,
    update = function(self, dt, needed)
      self.hideTimer = needed and 0 or (self.hideTimer + dt)
      -- The grace period only applies once something has actually been shown —
      -- otherwise a fresh/cleared group (alpha == 0, hideTimer == 0 < HIDE_DELAY)
      -- would target 1 and visibly flash in before fading back out.
      local target
      if needed then
        target = 1
      elseif self.alpha > 0.01 and self.hideTimer < HIDE_DELAY then
        target = 1
      else
        target = 0
      end
      local wasVisible = self.alpha > 0.01
      local rate = (target > self.alpha) and FADE_IN_RATE or FADE_OUT_RATE
      self.alpha = animation.expDecay(self.alpha, target, rate, dt)
      self.justHidden = wasVisible and self.alpha <= 0.01
    end,
    snapHidden = function(self)
      self.alpha = 0
      self.hideTimer = 0
      self.justHidden = false
    end,
  }
end

local _visProgress = newFadeGroup()
local _visThreat    = newFadeGroup()
local _visDtor      = newFadeGroup()
local _visDeck      = newFadeGroup()
local _visHand      = newFadeGroup()
local _visCamera    = newFadeGroup()

local function anyTokenActive(types)
  for _, t in ipairs(types) do
    if Token.count(t) > 0 or not Token.allDone(t) then return true end
  end
  return false
end

-- drawToHand/drawToDtor share the deck, so they share one draw-count cap too.
local MAX_DRAW_TOKENS   = 5
local MAX_MSG_DURATION  = 1.5
local _drawCount    = 0
local _maxMsgTimer  = 0

local function showMaxDrawMessage()
  message.text          = "MAX REACHED"
  message.subtitle      = "CLEAR TO ADD MORE"
  message.textColor     = Palette.warning
  message.current.scale = 6
  message.target.scale  = 1.0
  message.current.alpha = 1.0
  message.target.alpha  = 1.0
  _maxMsgTimer = MAX_MSG_DURATION
end

local function containsPoint(btn, px, py)
  return px >= btn.x and px <= btn.x + btn.w
     and py >= btn.y and py <= btn.y + btn.h
end

local function panelRows()
  return math.ceil(#TOKEN_TYPES / COLS)
end

local function panelWidth()
  return BTN_SIZE * COLS + COL_GAP * (COLS - 1)
end

-- Adds one card to the shared deck so the drawToHand/drawToDtor tokens
-- (which deal from it the moment they settle — see Token.registerImmediateSettle
-- in core/newSequences.lua) always have supply to consume.
local function addCardToDeck()
  if not _deck then return end
  -- Cosmetic set-dressing for the pre-run sandbox scene; deliberately
  -- pinned to "original" rather than reflecting the last-played deck.
  local card = Card.new(_deck.x, _deck.y, CardData.startingDecks.original.deck[1])
  _deck:add(card)
end

-- These settle straight into their terminal effect (see
-- Token.registerImmediateSettle in core/newSequences.lua) via a shared
-- cascade accumulator that only ever counts up — reset it before each
-- sandbox-triggered settle or their start-up delay grows without bound.
local IMMEDIATE_SETTLE_TYPES = { drawToHand = true, drawToDtor = true, nullify = true, shuffle = true }

-- True for the whole drawToDtor lifecycle: initial fling+settle, the terminal
-- attract flight to the deck (both still just live "drawToDtor" tokens), and
-- the camera/laser/shatter/dtor-register sequence once it arrives (tracked via
-- the "terminalArrive" queue, since the token itself is gone by then). Dtor
-- only has one _transitCard slot, so a second drawToDtor landing anywhere in
-- this window stomps the first one's card mid-sequence.
local function scoreIsLocked()
  return events.anyRunning() or Token.anyPopActive()
end

local function isDrawToDtorBusy()
  return Token.count("drawToDtor") > 0
    or not Token.allDone("drawToDtor")
    or events.isRunning("terminalArrive")
end

local function flingFromIcon(btn)
  local dk = areas.desk
  if not dk then return end
  if btn.tokenType == "drawToDtor" and isDrawToDtorBusy() then
    return -- wait for the current drawToDtor sequence to fully finish
  end
  if btn.tokenType == "drawToHand" or btn.tokenType == "drawToDtor" then
    if _drawCount >= MAX_DRAW_TOKENS then
      showMaxDrawMessage()
      return
    end
    _drawCount = _drawCount + 1
    addCardToDeck()
  end
  if IMMEDIATE_SETTLE_TYPES[btn.tokenType] then
    sequences.resetImmediateAcc()
  end
  Token.new_fling(btn.x + btn.w / 2, btn.y + btn.h / 2, dk, {
    type    = btn.tokenType,
    bounces = math.random(0, 2),
    delay   = false,
  })
  _selected = btn.tokenType
  menuScreen.minimize()
  _interacted = true
end

local function newIconButton(x, y, sz, ttype, asset)
  return {
    x = x, y = y, w = sz, h = sz,
    baseX      = x,
    asset      = asset,
    tokenType  = ttype,
    unlocked   = true,
    -- Overwritten by the first sandbox.refreshUnlocks() call (see
    -- sandbox.init()) once a deckId is known; 0 here is a harmless placeholder.
    required   = 0,
    hovered    = false,
    update = function(self, mx, my)
      self.hovered = containsPoint(self, mx, my)
    end,
    draw = function(self)
      local col = self.hovered and Palette.accent
               or (self.unlocked and Palette.primary or { 0.35, 0.35, 0.35, 1 })
      love.graphics.setColor(col)
      love.graphics.setLineWidth(3 * math.max(SCALE_X, SCALE_Y))
      love.graphics.rectangle("line", self.x, self.y, self.w, self.h, 8 * SCALE_X, 8 * SCALE_Y)
      love.graphics.setLineWidth(1)
      if self.asset then
        local iw, ih = self.asset:getDimensions()
        local s = math.min(self.w * 0.70 / iw, self.h * 0.70 / ih)
        love.graphics.setColor(1, 1, 1, self.unlocked and 1 or 0.15)
        love.graphics.draw(self.asset, self.x + self.w / 2, self.y + self.h / 2, 0, s, s, iw / 2, ih / 2)
      end
      if not self.unlocked then
        local lockAsset = Manifest.get("tokens", "lock")
        local liw, lih  = lockAsset:getDimensions()
        local ls = math.min(self.w * 0.55 / liw, self.h * 0.55 / lih)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(lockAsset, self.x + self.w / 2, self.y + self.h / 2, 0, ls, ls, liw / 2, lih / 2)
      end
      love.graphics.setColor(1, 1, 1, 1)
    end,
    mousepressed = function(self, px, py, btn)
      if btn == 1 and self.unlocked and containsPoint(self, px, py) then
        flingFromIcon(self)
        return true
      end
      return false
    end,
    touchpressed = function(self, px, py)
      if self.unlocked and containsPoint(self, px, py) then
        flingFromIcon(self)
        return true
      end
      return false
    end,
  }
end

local function newTabButton()
  local pw = panelWidth()
  local x  = (PANEL_X + pw + TAB_GAP) * SCALE_X
  local y  = PANEL_Y * SCALE_Y
  local w  = TAB_W * SCALE_X
  local h  = BTN_SIZE * SCALE_Y
  return {
    x = x, y = y, w = w, h = h,
    expandedX   = x,
    collapsedX  = TAB_COLLAPSED_X * SCALE_X,
    hovered = false,
    update = function(self, mx, my)
      self.hovered = containsPoint(self, mx, my)
    end,
    draw = function(self)
      local col = self.hovered and Palette.accent or Palette.primary
      love.graphics.setColor(0, 0, 0, 0.55)
      love.graphics.rectangle("fill", self.x, self.y, self.w, self.h, 8 * SCALE_X, 8 * SCALE_Y)
      love.graphics.setColor(col)
      love.graphics.setLineWidth(3 * math.max(SCALE_X, SCALE_Y))
      love.graphics.rectangle("line", self.x, self.y, self.w, self.h, 8 * SCALE_X, 8 * SCALE_Y)
      love.graphics.setLineWidth(1)
      local arrow = Manifest.get("tooltip", "arrow")
      local aw, ah = arrow:getDimensions()
      local s = math.min(self.w * 0.6 / aw, self.h * 0.6 / ah)
      -- Points left (toward the grid) when open/expanded ("close me this way"),
      -- right (away from the grid) when collapsed ("open me this way").
      local rotation = _collapsed and math.pi or 0
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(arrow, self.x + self.w / 2, self.y + self.h / 2, rotation, s, s, aw / 2, ah / 2)
    end,
    mousepressed = function(self, px, py, btn)
      if btn == 1 and containsPoint(self, px, py) then
        _collapsed = not _collapsed
        return true
      end
      return false
    end,
    touchpressed = function(self, px, py)
      if containsPoint(self, px, py) then
        _collapsed = not _collapsed
        return true
      end
      return false
    end,
  }
end

-- Stores refs to the same deck/hand instances main.lua uses for real runs
-- (both already always exist, just not necessarily wired into core.newSequences
-- yet — see main.lua's love.load). Starting a real run replaces these
-- module-locals in main.lua with fresh instances, so nothing here leaks.
function sandbox.setDeckAndHand(deck, hand)
  _deck = deck
  _hand = hand
end

-- Rebuilds the icon grid's unlocked/locked flags against the profile's
-- current highest level reached for the active run's starting deck.
-- Positions are static (every token type is always shown); only lock state
-- can change between menu visits. Sandbox isn't tied to a real run's deck
-- choice, so it previews Run.getDeckType() -- always valid by the time this
-- runs, since Run.newRun("original") happens unconditionally in love.load()
-- before any deck-select UI exists.
function sandbox.refreshUnlocks()
  local deckId = Run.getDeckType() or "original"
  local highestLevel = Profile.getHighestLevelReached(deckId)
  local levels = UnlockLevels[deckId] or UnlockLevels.original or {}
  for _, btn in ipairs(_iconButtons) do
    btn.unlocked = Unlocks.isTokenUnlocked(deckId, btn.tokenType, highestLevel)
    btn.required = levels[btn.tokenType] or 0
  end
end

function sandbox.init()
  Token.clearAll()
  events.loadAll()
  areas.pool.chips = {}

  _collapsed  = false
  _interacted = false
  _selected   = nil
  _drawCount  = 0
  _maxMsgTimer = 0

  _iconButtons = {}
  for i, ttype in ipairs(TOKEN_TYPES) do
    local col = (i - 1) % COLS
    local row = math.floor((i - 1) / COLS)
    local x   = (PANEL_X + col * (BTN_SIZE + COL_GAP)) * SCALE_X
    local y   = (PANEL_Y + row * (BTN_SIZE + ROW_GAP)) * SCALE_Y
    local sz  = BTN_SIZE * SCALE_X
    _iconButtons[#_iconButtons + 1] = newIconButton(x, y, sz, ttype, getTokenAsset(ttype))
  end
  sandbox.refreshUnlocks()

  _tab = newTabButton()

  local clearY = 2160 - BOTTOM_MARGIN - SCORE_CLEAR_H
  local scoreY = clearY - SCORE_CLEAR_GAP - SCORE_CLEAR_H

  _scoreButton = Button.new(
    PANEL_X * SCALE_X, scoreY * SCALE_Y,
    SCORE_CLEAR_W * SCALE_X, SCORE_CLEAR_H * SCALE_Y,
    "Score", 72, function() sequences.score() end
  )
  _clearButton = Button.new(
    PANEL_X * SCALE_X, clearY * SCALE_Y,
    SCORE_CLEAR_W * SCALE_X, SCORE_CLEAR_H * SCALE_Y,
    "Clear", 72, function()
      Token.clearAll()
      Debris.clearAll()
      progressBar.reset()
      threatBar.reset()
      Dtor.reset()
      events.loadAll()   -- cancels any in-flight "terminalArrive"/default sequence
      actionQueue.reset()
      sequences.resetImmediateAcc()
      laser.hide()
      Camera:setIdle()
      if _deck then _deck.cards = {} end
      if _hand then _hand.cards = {} end
      _drawCount = 0
      _maxMsgTimer = 0
      message.text          = ""
      message.subtitle      = ""
      message.current.alpha = 0
      message.target.alpha  = 0
      _visProgress:snapHidden()
      _visThreat:snapHidden()
      _visDtor:snapHidden()
      _visDeck:snapHidden()
      _visHand:snapHidden()
      _visCamera:snapHidden()
    end
  )
end

function sandbox.update(dt, mx, my)
  local tabTargetX = _collapsed and _tab.collapsedX or _tab.expandedX
  _tab.x = animation.expDecay(_tab.x, tabTargetX, TAB_TWEEN_RATE, dt or 0)

  -- The icon grid slides the same distance the tab travels, so the whole
  -- panel reads as one drawer with the tab as its handle.
  _panelShiftX = _tab.expandedX - _tab.x
  for _, btn in ipairs(_iconButtons) do
    btn.x = btn.baseX - _panelShiftX
    btn:update(mx, my)
  end

  _tab:update(mx, my)
  if _interacted and not _collapsed then
    _scoreButton:update(scoreIsLocked() and -9999 or mx, scoreIsLocked() and -9999 or my)
    _clearButton:update(mx, my)
  end

  local drawToDtorActive = isDrawToDtorBusy()
  local handNeeded = anyTokenActive({ "drawToHand" }) or drawToDtorActive

  _visProgress:update(dt, anyTokenActive({ "progress", "progressNegative" }))
  _visThreat:update(dt, anyTokenActive({ "threat", "threatNegative" }))
  _visDtor:update(dt, anyTokenActive({ "nullify", "shuffle", "dtor" }) or drawToDtorActive)
  _visDeck:update(dt, handNeeded)
  _visHand:update(dt, handNeeded)
  _visCamera:update(dt, drawToDtorActive)

  -- Once the hand has fully faded out, drop its cards entirely — nothing
  -- left to hover, and a fresh drawToHand click won't show a stale card.
  if _visHand.justHidden and _hand then
    _hand.cards = {}
  end

  Camera:update(dt, mx, my, areas.scanner)
  laser.update(gameDt)
  if _hand then
    -- Suppress hover while the hand isn't needed (grace period + fade-out)
    -- so a fading-away card doesn't still react to the mouse.
    if handNeeded then
      _hand:update(mx, my)
    else
      _hand:update(-9999, -9999)
    end
  end

  if _maxMsgTimer > 0 then
    _maxMsgTimer = _maxMsgTimer - dt
    if _maxMsgTimer <= 0 then
      message.target.alpha = 0
    end
  end
  message.update(dt)
end

function sandbox.drawScene()
  if _visProgress.alpha > 0.01 then progressBar.draw(_visProgress.alpha) end
  if _visThreat.alpha > 0.01 then threatBar.draw(_visThreat.alpha) end
  if _visDeck.alpha > 0.01 and _deck then _deck:draw(_visDeck.alpha) end
  if _visCamera.alpha > 0.01 then Camera:draw(_visCamera.alpha) end
  if _visHand.alpha > 0.01 and _hand then _hand:draw(_visHand.alpha) end
  if _visDtor.alpha > 0.01 then
    if areas.dtorRow.asset then
      love.graphics.setColor(1, 1, 1, _visDtor.alpha)
      love.graphics.draw(areas.dtorRow.asset, areas.dtorRow.x, areas.dtorRow.y,
        0, SCALE_X, SCALE_Y, areas.dtorRow.asset:getWidth() / 2, areas.dtorRow.asset:getHeight() / 2)
      love.graphics.setColor(1, 1, 1, 1)
    end
    Dtor.drawAll(_visDtor.alpha, true) -- true: skip the front-of-queue effect text
  end
  laser.draw()
  message.draw()
end

function sandbox.collectTooltipRequests()
  if _collapsed then return end
  for _, btn in ipairs(_iconButtons) do
    if btn.hovered then
      if btn.unlocked then
        -- Same {type=...} "effects" format core/cardTooltip.lua and
        -- core/hover.lua use: colored name + token sprite header, wrapped
        -- description body — hoverTooltip.lua builds it for us.
        hoverTooltip.request("sandboxToken_" .. btn.tokenType, {
          effects = { { type = btn.tokenType } },
          anchorX = btn.x + btn.w,
          anchorY = btn.y,
          side    = "right",
          arrowYOffset = 32.5
        })
      else
        hoverTooltip.request("sandboxLock_" .. btn.tokenType, {
          title   = "LOCKED",
          lines   = { "Reach Level " .. tostring(btn.required) },
          anchorX = btn.x + btn.w,
          anchorY = btn.y,
          side    = "right",
          arrowYOffset = 32.5
        })
      end
    end
  end
end

function sandbox.draw()
  local pw = panelWidth()
  local rows = panelRows()
  local panelH = (rows * (BTN_SIZE + ROW_GAP) - ROW_GAP) * SCALE_Y

  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.rectangle("fill",
    (PANEL_X - 5) * SCALE_X - _panelShiftX, (PANEL_Y - 10) * SCALE_Y,
    (pw + 10) * SCALE_X, panelH + 20 * SCALE_Y,
    8 * SCALE_X, 8 * SCALE_Y)
  love.graphics.setColor(1, 1, 1, 1)

  for _, btn in ipairs(_iconButtons) do btn:draw() end

  -- local font = Manifest.getFont(48)
  -- love.graphics.setFont(font)
  -- love.graphics.setColor(Palette.accent)
  -- love.graphics.print("SANDBOX", PANEL_X * SCALE_X, 2 * SCALE_Y)
  love.graphics.setColor(1, 1, 1, 1)

  _tab:draw()

  if _interacted and not _collapsed then
    local scoreAlpha = scoreIsLocked() and 0.35 or 1
    _scoreButton:draw(scoreAlpha)
    _clearButton:draw()
  end
end

function sandbox.mousepressed(x, y, button)
  if _tab:mousepressed(x, y, button) then return true end
  if _interacted and not _collapsed then
    if not scoreIsLocked() and _scoreButton:mousepressed(x, y, button) then return true end
    if _clearButton:mousepressed(x, y, button) then return true end
  end
  if _collapsed then return false end
  for _, btn in ipairs(_iconButtons) do
    if btn:mousepressed(x, y, button) then return true end
  end
  return false
end

function sandbox.touchpressed(x, y)
  if _tab:touchpressed(x, y) then return true end
  if _interacted and not _collapsed then
    if not scoreIsLocked() and _scoreButton:touchpressed(x, y) then return true end
    if _clearButton:touchpressed(x, y) then return true end
  end
  if _collapsed then return false end
  for _, btn in ipairs(_iconButtons) do
    if btn:touchpressed(x, y) then return true end
  end
  return false
end

return sandbox
