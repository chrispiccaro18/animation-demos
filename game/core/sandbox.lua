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
local Unlocks      = require("core.unlocks")
local UnlockLevels = require("data.unlocks")
local hoverTooltip = require("core.hoverTooltip")
local menuScreen   = require("core.menuScreen")
local animation    = require("lib.animation")

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

local function flingFromIcon(btn)
  local dk = areas.desk
  if not dk then return end
  Token.new_fling(btn.x + btn.w / 2, btn.y + btn.h / 2, dk, {
    type    = btn.tokenType,
    bounces = math.random(0, 2),
    delay   = false,
  })
  _selected = btn.tokenType
  if not _interacted then
    _interacted = true
    menuScreen.minimize()
  end
end

local function newIconButton(x, y, sz, ttype, asset)
  local requiredLevel = UnlockLevels[ttype] or 0
  return {
    x = x, y = y, w = sz, h = sz,
    baseX      = x,
    asset      = asset,
    tokenType  = ttype,
    unlocked   = true,
    required   = requiredLevel,
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

-- Rebuilds the icon grid's unlocked/locked flags against the profile's
-- current highest level reached. Positions are static (every token type is
-- always shown); only lock state can change between menu visits.
function sandbox.refreshUnlocks()
  local highestLevel = Profile.getHighestLevelReached()
  for _, btn in ipairs(_iconButtons) do
    btn.unlocked = Unlocks.isTokenUnlocked(btn.tokenType, highestLevel)
  end
end

function sandbox.init()
  Token.clearAll()
  events.loadAll()
  areas.pool.chips = {}

  _collapsed  = false
  _interacted = false
  _selected   = nil

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

  local sequences = require("core.newSequences")
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
      progressBar.reset()
      threatBar.reset()
      Dtor.reset()
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
  if _interacted then
    _scoreButton:update(mx, my)
    _clearButton:update(mx, my)
  end
end

function sandbox.collectTooltipRequests()
  if _collapsed then return end
  for _, btn in ipairs(_iconButtons) do
    if btn.hovered and not btn.unlocked then
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

  if _interacted then
    _scoreButton:draw()
    _clearButton:draw()
  end
end

function sandbox.mousepressed(x, y, button)
  if _tab:mousepressed(x, y, button) then return true end
  if _interacted then
    if _scoreButton:mousepressed(x, y, button) then return true end
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
  if _interacted then
    if _scoreButton:touchpressed(x, y) then return true end
    if _clearButton:touchpressed(x, y) then return true end
  end
  if _collapsed then return false end
  for _, btn in ipairs(_iconButtons) do
    if btn:touchpressed(x, y) then return true end
  end
  return false
end

return sandbox
