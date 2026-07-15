local AssetManifest = require("assets.manifest")
local Palette       = require("lib.palette")
local Button        = require("core.button")
local animation      = require("lib.animation")
local Audio          = require("assets.audio")
local CardData       = require("data.cards")

-- Full-screen celebration shown when a level-complete newly unlocks a
-- starting deck (see main.lua's gameOver == "levelComplete" handling, and
-- core/deckUnlocks.lua's DeckUnlocks.newlyUnlocked). Visually mirrors
-- core/unlockCeremony.lua (the token-unlock version) but shows the tinted
-- card-back art from core/deckSelectScreen.lua instead of token icons, and
-- offers two exits instead of one:
--   MAIN MENU -- abandons the current run (Run.deleteSave()) and returns to
--                the main menu, via the onMainMenu callback given to M.load.
--   CONTINUE  -- resumes play normally (the run keeps going past its
--                designed levels using data/escalation.lua's random
--                fallback -- "endless" is just the player-facing framing,
--                not a distinct game-state flag), via the onContinue
--                callback given to M.show.
--
-- Only fires once per deck (main.lua only calls M.show for deck ids
-- DeckUnlocks.newlyUnlocked() reports as freshly crossed), mirroring
-- unlockCeremony's "newly crossed threshold" trigger.
local M = {}

local TITLE_Y     = 450
local TITLE_SIZE  = 120
local NAME_Y      = 750
local NAME_SIZE   = 48
local CARD_Y            = 1100
local CARD_TARGET_H     = 480
local CARD_GAP          = 380 -- distance between multiple unlocked decks, if more than one at once

local BUTTON_Y   = 1720
local BUTTON_W   = 560
local BUTTON_H   = 180
local BUTTON_GAP = 80

local ICON_IN_RATE   = 10
local ALPHA_RATE     = 6
local FADE_DONE_EPS  = 0.02

local _active      = false
local _phase       = nil -- "showing" | "hiding"
local _onMainMenu  = nil -- set once, at load
local _onContinue  = nil -- set per-show
local _pendingExit = nil -- "menu" | "continue" -- which callback to fire once hidden
local _decks       = {}
local _titleText   = ""
local _titleCurrent = { scale = 6, alpha = 0 }
local _titleTarget  = { scale = 1, alpha = 1 }

local _titleFont  = nil
local _nameFont   = nil
local _cardBackImg = nil

local _menuBtn, _continueBtn = nil, nil
local _menuBtnX, _menuBtnY, _menuBtnW, _menuBtnH = 0, 0, 0, 0
local _continueBtnX, _continueBtnY, _continueBtnW, _continueBtnH = 0, 0, 0, 0

local function beginHide(exit)
  if not _active or _phase == "hiding" then return end
  _phase = "hiding"
  _pendingExit = exit
  _titleTarget.alpha = 0
  for _, deck in ipairs(_decks) do deck.target.alpha = 0 end
end

function M.load(onMainMenu)
  _onMainMenu = onMainMenu

  _titleFont   = AssetManifest.getFont(TITLE_SIZE)
  _nameFont    = AssetManifest.getFont(NAME_SIZE)
  _cardBackImg = AssetManifest.get("card", "back")

  local cw = SCALE_X * 3840
  _menuBtnW = BUTTON_W * SCALE_X
  _menuBtnH = BUTTON_H * SCALE_Y
  _continueBtnW = BUTTON_W * SCALE_X
  _continueBtnH = BUTTON_H * SCALE_Y

  local totalW = _menuBtnW + BUTTON_GAP * SCALE_X + _continueBtnW
  local startX = (cw - totalW) / 2
  _menuBtnX = startX
  _menuBtnY = BUTTON_Y * SCALE_Y
  _continueBtnX = startX + _menuBtnW + BUTTON_GAP * SCALE_X
  _continueBtnY = _menuBtnY

  _menuBtn = Button.new(_menuBtnX, _menuBtnY, _menuBtnW, _menuBtnH, "MAIN MENU", 72, function()
    beginHide("menu")
  end)
  _continueBtn = Button.new(_continueBtnX, _continueBtnY, _continueBtnW, _continueBtnH, "ENDLESS", 72, function()
    beginHide("continue")
  end)
end

local function layoutDecks(deckIds)
  local cw = SCALE_X * 3840
  local n  = #deckIds
  local totalW = (n - 1) * CARD_GAP
  local startX = (cw / SCALE_X - totalW) / 2
  local decks = {}
  for i, deckId in ipairs(deckIds) do
    local deckEntry = CardData.startingDecks[deckId]
    local tint = (deckEntry.tintPalette and Palette[deckEntry.tintPalette]) or Palette.default
    decks[#decks + 1] = {
      deckId  = deckId,
      name    = deckEntry.name or deckId,
      tint    = tint,
      x       = (startX + (i - 1) * CARD_GAP) * SCALE_X,
      y       = CARD_Y * SCALE_Y,
      current = { scale = 0, alpha = 0 },
      target  = { scale = 1, alpha = 1 },
    }
  end
  return decks
end

-- deckIds: array of newly-unlocked starting-deck id strings (see
-- core/deckUnlocks.lua's DeckUnlocks.newlyUnlocked). onContinue: called
-- once the ceremony finishes hiding after CONTINUE is pressed (not called
-- if MAIN MENU is pressed instead -- that fires the onMainMenu callback
-- given to M.load).
function M.show(deckIds, onContinue)
  _active      = true
  _phase       = "showing"
  _onContinue  = onContinue
  _pendingExit = nil
  _decks       = layoutDecks(deckIds)

  _titleText = (#deckIds > 1)
    and (#deckIds .. " DECKS UNLOCKED")
    or "DECK UNLOCKED"
  _titleCurrent.scale = 6
  _titleCurrent.alpha = 0
  _titleTarget.scale  = 1
  _titleTarget.alpha  = 1

  Audio.playSuccess()
end

function M.isActive() return _active end

function M.update(dt, mx, my)
  if not _active then return end

  _titleCurrent.scale = animation.expDecay(_titleCurrent.scale, _titleTarget.scale, ICON_IN_RATE, dt)
  _titleCurrent.alpha = animation.expDecay(_titleCurrent.alpha, _titleTarget.alpha, ALPHA_RATE, dt)

  for _, deck in ipairs(_decks) do
    deck.current.scale = animation.expDecay(deck.current.scale, deck.target.scale, ICON_IN_RATE, dt)
    deck.current.alpha = animation.expDecay(deck.current.alpha, deck.target.alpha, ALPHA_RATE, dt)
  end

  if _phase == "showing" then
    _menuBtn:update(mx, my)
    _continueBtn:update(mx, my)
  end

  if _phase == "hiding" and _titleCurrent.alpha <= FADE_DONE_EPS then
    local exit = _pendingExit
    _active      = false
    _phase       = nil
    _decks       = {}
    _titleText   = ""
    local onContinue = _onContinue
    _onContinue  = nil
    _pendingExit = nil
    if exit == "menu" then
      if _onMainMenu then _onMainMenu() end
    else
      if onContinue then onContinue() end
    end
  end
end

function M.collectGlowRequests(glow)
  if not _active then return end
  for _, deck in ipairs(_decks) do
    if _cardBackImg then
      local iw, ih = _cardBackImg:getDimensions()
      local sc = (CARD_TARGET_H / ih) * SCALE_Y
      glow:request("deckUnlockCeremony-" .. deck.deckId, {
        kind  = "image",
        image = _cardBackImg,
        x     = deck.x,
        y     = deck.y,
        sx    = sc * deck.current.scale,
        sy    = sc * deck.current.scale,
        ox    = iw / 2,
        oy    = ih / 2,
        color = deck.tint,
        alpha = deck.current.alpha * 0.6,
        pulse = { speed = 1.5, min = 0.3, max = 1.0 },
        light = { radius = iw * sc / 2, alpha = deck.current.alpha * 0.35 },
      }, "top")
    end
  end
  if _phase == "showing" then
    glow:request("deckUnlockCeremony-menu", {
      kind  = "rect",
      cx    = _menuBtnX + _menuBtnW * 0.5,
      cy    = _menuBtnY + _menuBtnH * 0.5,
      w     = _menuBtnW,
      h     = _menuBtnH,
      color = Palette.primary,
      alpha = 0.4,
      light = { radius = 50 * SCALE_X, alpha = 0.25 },
    }, "top")
    -- glow:request("deckUnlockCeremony-continue", {
    --   kind  = "rect",
    --   cx    = _continueBtnX + _continueBtnW * 0.5,
    --   cy    = _continueBtnY + _continueBtnH * 0.5,
    --   w     = _continueBtnW,
    --   h     = _continueBtnH,
    --   color = Palette.accent,
    --   alpha = 0.55,
    --   pulse = { speed = 1.5, min = 0.2, max = 1.0 },
    --   light = { radius = 60 * SCALE_X, alpha = 0.4 },
    -- }, "top")
  end
end

-- No hover-inspectable elements on this screen (deck back art only, same
-- as core/deckSelectScreen.lua) -- kept as a no-op so main.lua's dispatch
-- can call it unconditionally, mirroring the sibling screens' module shape.
function M.collectTooltipRequests()
end

function M.draw()
  if not _active then return end

  local cw = SCALE_X * 3840
  local ch = SCALE_Y * 2160

  love.graphics.setColor(Palette.void)
  love.graphics.rectangle("fill", 0, 0, cw, ch)
  love.graphics.setColor(1, 1, 1, 1)

  if _titleFont and _titleText ~= "" then
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(_titleFont)
    local tw = _titleFont:getWidth(_titleText)
    local th = _titleFont:getHeight()
    love.graphics.push()
    love.graphics.translate(cw / 2, TITLE_Y * SCALE_Y + th / 2)
    love.graphics.scale(_titleCurrent.scale, _titleCurrent.scale)
    love.graphics.setColor(Palette.accent[1], Palette.accent[2], Palette.accent[3], _titleCurrent.alpha)
    love.graphics.print(_titleText, -tw / 2, -th / 2)
    love.graphics.pop()
    love.graphics.setFont(prevFont)
    love.graphics.setColor(1, 1, 1, 1)
  end

  for _, deck in ipairs(_decks) do
    local a = deck.current.alpha
    if a > 0.01 and _cardBackImg then
      local iw, ih = _cardBackImg:getDimensions()
      local sc = (CARD_TARGET_H / ih) * SCALE_Y * deck.current.scale
      local t = deck.tint
      love.graphics.setColor(t[1], t[2], t[3], (t[4] or 1) * a)
      love.graphics.draw(_cardBackImg, deck.x, deck.y, 0, sc, sc, iw / 2, ih / 2)
      love.graphics.setColor(1, 1, 1, 1)

      if _nameFont then
        local prevFont = love.graphics.getFont()
        love.graphics.setFont(_nameFont)
        local nw = _nameFont:getWidth(deck.name)
        love.graphics.setColor(1, 1, 1, a)
        love.graphics.print(deck.name, math.floor(deck.x - nw / 2), math.floor(NAME_Y * SCALE_Y))
        love.graphics.setFont(prevFont)
      end
    end
  end

  if _phase == "showing" then
    _menuBtn:draw()
    _continueBtn:draw()
  end

  love.graphics.setColor(1, 1, 1, 1)
end

function M.mousepressed(mx, my, btn)
  if not _active or btn ~= 1 or _phase ~= "showing" then return false end
  if _menuBtn:mousepressed(mx, my, btn) then return true end
  return _continueBtn:mousepressed(mx, my, btn)
end

function M.touchpressed(tx, ty)
  return M.mousepressed(tx, ty, 1)
end

return M
