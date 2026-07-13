local Card        = require("core.card")
local Button      = require("core.button")
local AssetManifest = require("assets.manifest")
local Palette     = require("lib.palette")
local cardTooltip = require("core.cardTooltip")
local message     = require("core.message")
local events      = require("lib.events")
local Run         = require("core.run")
local Profile     = require("core.profile")

local M = {}

-- Design-space constants (pre-SCALE)
local CARD_Y      = 1100   -- vertical center for offer cards
local CARD_X      = { 870 + 200, 1920, 2970 - 200 }
local TITLE_Y     = 450
local CONFIRM_Y   = 1720
local CONFIRM_W   = 560
local CONFIRM_H   = 180
local TITLE_SIZE  = 120
local CARD_HOVER_BUFFER = 20

local _active      = false
local _cards       = {}
local _cardDatas   = {}
local _selected    = nil
local _confirmBtn  = nil
local _confirmBtnX = 0
local _confirmBtnY = 0
local _confirmBtnW = 0
local _confirmBtnH = 0
local _vignette    = nil
local _titleFont   = nil
local _cardBackImg = nil
local _onReset     = nil   -- main.lua resetGame callback

function M.load(onResetGame)
  _onReset      = onResetGame
  _vignette     = AssetManifest.get("board", "fullScreenVignette")
  _titleFont    = AssetManifest.getFont(TITLE_SIZE)
  _cardBackImg  = AssetManifest.get("card", "base")

  local cw = SCALE_X * 3840
  _confirmBtnW = CONFIRM_W * SCALE_X
  _confirmBtnH = CONFIRM_H * SCALE_Y
  _confirmBtnX = (cw - _confirmBtnW) / 2
  _confirmBtnY = CONFIRM_Y * SCALE_Y
  local bx = _confirmBtnX
  local by = _confirmBtnY
  local bw = _confirmBtnW
  local bh = _confirmBtnH
  _confirmBtn = Button.new(bx, by, bw, bh, "CONFIRM", 72, function()
    if not _selected then return end
    local chosen = _cardDatas[_selected]
    _active   = false
    _cards    = {}
    _cardDatas = {}
    _selected = nil

    Run.addCard(chosen)
    Run.nextLevel()
    Profile.reportLevelReached(Run.getLevel())
    _onReset()

    -- Level start message (event queue was reset by resetGame)
    local lvl = Run.getLevel()
    message.text          = "LEVEL " .. lvl .. " START"
    message.textColor     = Palette.accent
    message.current.scale = 6
    message.target.scale  = 1.0
    message.current.alpha = 1.0
    message.target.alpha  = 0.0
    events.push({
      fn = function()
        message.text          = ""
        message.current.alpha = 1.0
        message.target.alpha  = 1.0
      end,
      blocking = false, blockable = false, persistent = false,
      delay = 1.5, type = "before",
    })
  end)
end

function M.show(offerDatas)
  _active   = true
  _selected = nil
  _cards    = {}
  _cardDatas = {}
  for i, cardData in ipairs(offerDatas) do
    local x = CARD_X[i] * SCALE_X
    local y = CARD_Y   * SCALE_Y
    local card = Card.new(x, y, cardData)
    card.target.scale  = card.scales.idle
    card.current.scale = card.scales.idle
    card.hover.can     = false
    card.drag.can      = false
    _cards[i]    = card
    _cardDatas[i] = cardData
  end
end

function M.isActive() return _active end

function M.update(dt, mx, my)
  if not _active then return end
  for i, card in ipairs(_cards) do
    local hw = card.offsetX * card.scales.hover * SCALE_X
    local hh = card.offsetY * card.scales.hover * SCALE_Y
    local isHovered = math.abs(mx - card.current.x) <= hw + CARD_HOVER_BUFFER
                  and math.abs(my - card.current.y) <= hh + CARD_HOVER_BUFFER
    card.hover.is = isHovered
    if isHovered then
      card.mouseX = mx
      card.mouseY = my
    end
    if i == _selected then
      card.target.scale = card.scales.hover
      -- card.target.scale = card.scales.drag
    elseif isHovered then
      card.target.scale = card.scales.hover
    else
      card.target.scale = card.scales.idle
    end
    card:update()
  end
  if _selected then
    _confirmBtn:update(mx, my)
  end
end

function M.collectGlowRequests(glow)
  if not _active or not _selected then return end
  local card = _cards[_selected]
  local iw, ih = _cardBackImg:getDimensions()
  glow:request("cardpick-selected", {
    kind         = "image",
    image        = _cardBackImg,
    x            = card.current.x,
    y            = card.current.y,
    sx           = card.current.scale * SCALE_X,
    sy           = card.current.scale * SCALE_Y,
    ox           = iw / 2,
    oy           = ih / 2,
    color        = { 1, 1, 1 },
    alpha        = 0.2,
    -- luminescence = 1.2,
    -- pulse        = { speed = 1.5, min = 0.3, max = 1.0 },
    light        = { radius = iw * SCALE_X / 2, alpha = 0.2 },
  }, "top")
  glow:request("cardpick-confirm", {
    kind  = "rect",
    cx    = _confirmBtnX + _confirmBtnW * 0.5,
    cy    = _confirmBtnY + _confirmBtnH * 0.5,
    w     = _confirmBtnW,
    h     = _confirmBtnH,
    color = Palette.accent,
    alpha = 0.55,
    pulse = { speed = 1.5, min = 0.2, max = 1.0 },
    light = { radius = 60 * SCALE_X, alpha = 0.4 },
  }, "top")
end

function M.collectTooltipRequests()
  if not _active then return end
  for _, card in ipairs(_cards) do
    if card.hover.is then
      cardTooltip.request(card.id, card, nil)
    end
  end
end

function M.draw()
  if not _active then return end

  local cw = SCALE_X * 3840
  local ch = SCALE_Y * 2160

  -- Dim background
  -- if _vignette then
  --   local vw, vh = _vignette:getDimensions()
  --   love.graphics.setColor(1, 1, 1, 0.45)
  --   love.graphics.draw(_vignette, 0, 0, 0, cw / vw, ch / vh)
  -- else
  -- end
  love.graphics.setColor(0, 0, 0, 0.78)
  love.graphics.rectangle("fill", 0, 0, cw, ch)
  love.graphics.setColor(1, 1, 1, 1)

  -- Title
  if _titleFont then
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(_titleFont)
    local text = "CHOOSE 1"
    local tw   = _titleFont:getWidth(text)
    love.graphics.setColor(Palette.accent)
    love.graphics.print(text, math.floor((cw - tw) / 2), math.floor(TITLE_Y * SCALE_Y))
    love.graphics.setFont(prevFont)
    love.graphics.setColor(1, 1, 1, 1)
  end

  -- Cards + selection highlight
  for _, card in ipairs(_cards) do
    love.graphics.setColor(1, 1, 1, 1)
    card:draw()
  end

  -- Confirm button (after selection)
  if _selected then _confirmBtn:draw() end

  love.graphics.setColor(1, 1, 1, 1)
end

function M.mousepressed(mx, my, btn)
  if not _active or btn ~= 1 then return false end
  if _selected and _confirmBtn:mousepressed(mx, my, btn) then return true end
  for i, card in ipairs(_cards) do
    local hw = card.offsetX * card.scales.hover * SCALE_X
    local hh = card.offsetY * card.scales.hover * SCALE_Y
    if math.abs(mx - card.current.x) <= hw and math.abs(my - card.current.y) <= hh then
      _selected = i
      return true
    end
  end
  return false
end

function M.touchpressed(tx, ty)
  return M.mousepressed(tx, ty, 1)
end

return M
