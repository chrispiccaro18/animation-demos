local Button       = require("core.button")
local Manifest     = require("assets.manifest")
local Palette      = require("lib.palette")
local CardData     = require("data.cards")
local DeckUnlocks  = require("core.deckUnlocks")

-- "New Run" deck picker: shows every entry in CardData.startingDeckOrder as
-- a slot with a card-back visual (tinted per deck via data/cards.lua's
-- tintPalette). Locked decks (per core/deckUnlocks.lua) are greyed out with
-- an always-visible requirement line rather than a hover tooltip -- this is
-- a deliberate, low-frequency screen where always-on clarity beats an
-- interaction-gated reveal.
--
-- No separate "deck unlocked!" ceremony: a locked slot simply flips to
-- unlocked the next time this screen is shown (M.show() re-evaluates
-- DeckUnlocks.isUnlocked() fresh every call), the same way the sandbox
-- token palette silently reflects newly-unlocked tokens on next menu visit.
local M = {}

-- Design-space constants (pre-SCALE)
local TITLE_Y       = 450
local TITLE_SIZE    = 120
local NAME_Y        = 750
local NAME_SIZE     = 48
local CARD_Y        = 1100
local CARD_TARGET_H = 480  -- design-space height the card-back art is scaled to
local SLOT_GAP      = 1040 -- distance between deck slot centers
local SLOT_W        = 760
local SLOT_TOP_Y    = 640
local SLOT_BOTTOM_Y = 1560
local REQ_Y         = 1460
local REQ_SIZE      = 32
local LOCKED_ALPHA  = 0.15

local CONFIRM_Y = 1720
local CONFIRM_W = 560
local CONFIRM_H = 180

local BACK_X = 150
local BACK_Y = 150
local BACK_W = 280
local BACK_H = 120

local _active     = false
local _slots      = {}
local _selected   = nil -- deckId
local _onConfirm  = nil
local _onBack     = nil

local _titleFont  = nil
local _nameFont   = nil
local _reqFont    = nil
local _cardBackImg = nil

local _confirmBtn  = nil
local _confirmBtnX, _confirmBtnY, _confirmBtnW, _confirmBtnH = 0, 0, 0, 0
local _backBtn      = nil

local function slotCenterX(i, n)
  local cw = SCALE_X * 3840
  local totalW = (n - 1) * SLOT_GAP
  local startX = (cw / SCALE_X - totalW) / 2
  return (startX + (i - 1) * SLOT_GAP) * SCALE_X
end

function M.load(onConfirm, onBack)
  _onConfirm = onConfirm
  _onBack    = onBack

  _titleFont   = Manifest.getFont(TITLE_SIZE)
  _nameFont    = Manifest.getFont(NAME_SIZE)
  _reqFont     = Manifest.getFont(REQ_SIZE)
  _cardBackImg = Manifest.get("card", "back")

  local cw = SCALE_X * 3840
  _confirmBtnW = CONFIRM_W * SCALE_X
  _confirmBtnH = CONFIRM_H * SCALE_Y
  _confirmBtnX = (cw - _confirmBtnW) / 2
  _confirmBtnY = CONFIRM_Y * SCALE_Y
  _confirmBtn = Button.new(_confirmBtnX, _confirmBtnY, _confirmBtnW, _confirmBtnH, "CONFIRM", 72, function()
    if not _selected then return end
    if _onConfirm then _onConfirm(_selected) end
  end)

  _backBtn = Button.new(BACK_X * SCALE_X, BACK_Y * SCALE_Y, BACK_W * SCALE_X, BACK_H * SCALE_Y, "BACK", 48, function()
    if _onBack then _onBack() end
  end)
end

function M.show()
  _active   = true
  _selected = nil
  _slots    = {}

  local order = CardData.startingDeckOrder
  local n     = #order
  for i, deckId in ipairs(order) do
    local deckEntry = CardData.startingDecks[deckId]
    local unlocked  = DeckUnlocks.isUnlocked(deckId)
    local tint      = (deckEntry.tintPalette and Palette[deckEntry.tintPalette]) or Palette.default

    _slots[#_slots + 1] = {
      deckId          = deckId,
      name             = deckEntry.name or deckId,
      unlocked         = unlocked,
      requirementText  = not unlocked and DeckUnlocks.requirementText(deckId) or nil,
      tint             = tint,
      hovered          = false,
      x                = slotCenterX(i, n),
      y                = CARD_Y * SCALE_Y,
    }
  end
end

function M.hide()
  _active   = false
  _selected = nil
  _slots    = {}
end

function M.isActive() return _active end

local function slotBounds(slot)
  local hw = (SLOT_W / 2) * SCALE_X
  local top = SLOT_TOP_Y * SCALE_Y
  local bottom = SLOT_BOTTOM_Y * SCALE_Y
  return slot.x - hw, top, slot.x + hw, bottom
end

function M.update(dt, mx, my)
  if not _active then return end
  for _, slot in ipairs(_slots) do
    local x1, y1, x2, y2 = slotBounds(slot)
    slot.hovered = slot.unlocked and mx >= x1 and mx <= x2 and my >= y1 and my <= y2
  end
  if _selected then
    _confirmBtn:update(mx, my)
  end
  _backBtn:update(mx, my)
end

function M.collectGlowRequests(glow)
  if not _active then return end
  if _selected then
    glow:request("deckselect-confirm", {
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
end

-- No individual cards to inspect on this screen (deck back art only), so
-- there's nothing to request a hover tooltip for. Kept as a no-op so
-- main.lua's menu-branch update loop can call it unconditionally, mirroring
-- cardPickScreen/sandbox's module shape.
function M.collectTooltipRequests()
end

function M.draw()
  if not _active then return end

  local cw = SCALE_X * 3840
  local ch = SCALE_Y * 2160

  love.graphics.setColor(Palette.void)
  love.graphics.rectangle("fill", 0, 0, cw, ch)
  love.graphics.setColor(1, 1, 1, 1)

  if _titleFont then
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(_titleFont)
    local text = "CHOOSE YOUR DECK"
    local tw   = _titleFont:getWidth(text)
    love.graphics.setColor(Palette.accent)
    love.graphics.print(text, math.floor((cw - tw) / 2), math.floor(TITLE_Y * SCALE_Y))
    love.graphics.setFont(prevFont)
    love.graphics.setColor(1, 1, 1, 1)
  end

  for _, slot in ipairs(_slots) do
    local x1, y1, x2, y2 = slotBounds(slot)
    local selected = slot.deckId == _selected
    local borderColor = slot.unlocked
      and ((selected or slot.hovered) and Palette.accent or Palette.primary)
      or { 0.35, 0.35, 0.35, 1 }

    love.graphics.setColor(borderColor)
    love.graphics.setLineWidth(3 * math.max(SCALE_X, SCALE_Y))
    love.graphics.rectangle("line", x1, y1, x2 - x1, y2 - y1, 12 * SCALE_X, 12 * SCALE_Y)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)

    if _nameFont then
      local prevFont = love.graphics.getFont()
      love.graphics.setFont(_nameFont)
      local nw = _nameFont:getWidth(slot.name)
      love.graphics.setColor(slot.unlocked and Palette.default or Palette.muted)
      love.graphics.print(slot.name, math.floor(slot.x - nw / 2), math.floor(NAME_Y * SCALE_Y))
      love.graphics.setFont(prevFont)
      love.graphics.setColor(1, 1, 1, 1)
    end

    if _cardBackImg then
      local iw, ih = _cardBackImg:getDimensions()
      local sc = (CARD_TARGET_H / ih) * SCALE_Y
      local alphaMul = slot.unlocked and 1 or LOCKED_ALPHA
      local t = slot.tint
      love.graphics.setColor(t[1], t[2], t[3], (t[4] or 1) * alphaMul)
      love.graphics.draw(_cardBackImg, slot.x, slot.y, 0, sc, sc, iw / 2, ih / 2)
      love.graphics.setColor(1, 1, 1, 1)
    end

    if not slot.unlocked then
      local lockAsset = Manifest.get("tokens", "lock")
      if lockAsset then
        local liw, lih = lockAsset:getDimensions()
        local ls = math.min(120 * SCALE_X / liw, 120 * SCALE_Y / lih)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(lockAsset, slot.x, slot.y, 0, ls, ls, liw / 2, lih / 2)
      end

      if _reqFont and slot.requirementText then
        local prevFont = love.graphics.getFont()
        love.graphics.setFont(_reqFont)
        local rw = _reqFont:getWidth(slot.requirementText)
        love.graphics.setColor(Palette.muted)
        love.graphics.print(slot.requirementText, math.floor(slot.x - rw / 2), math.floor(REQ_Y * SCALE_Y))
        love.graphics.setFont(prevFont)
        love.graphics.setColor(1, 1, 1, 1)
      end
    end
  end

  if _selected then _confirmBtn:draw() end
  _backBtn:draw()

  love.graphics.setColor(1, 1, 1, 1)
end

function M.mousepressed(mx, my, btn)
  if not _active or btn ~= 1 then return false end
  if _backBtn:mousepressed(mx, my, btn) then return true end
  if _selected and _confirmBtn:mousepressed(mx, my, btn) then return true end
  for _, slot in ipairs(_slots) do
    if slot.unlocked then
      local x1, y1, x2, y2 = slotBounds(slot)
      if mx >= x1 and mx <= x2 and my >= y1 and my <= y2 then
        _selected = slot.deckId
        return true
      end
    end
  end
  return false
end

function M.touchpressed(tx, ty)
  return M.mousepressed(tx, ty, 1)
end

return M
