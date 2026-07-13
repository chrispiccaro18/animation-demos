local Button   = require("core.button")
local Token    = require("core.token")
local Manifest = require("assets.manifest")
local Palette  = require("lib.palette")
local areas    = require("core.areas")
local events   = require("lib.events")
local progressBar = require("core.progressBar")
local threatBar   = require("core.threatBar")
local Dtor        = require("core.dtor")
local Profile     = require("core.profile")
local Unlocks     = require("core.unlocks")

local sandbox = {}

local TOKEN_TYPES = {
  "progress",
  "threat",
  "multiplyProgress",
  "flip",
  "nullify",
  "drawToHand",
  "drawToDtor",
  "shuffle",

  "progressNegative",
  "threatNegative",
  "multiplyThreat",
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

local _onBack      = nil
local _selected    = TOKEN_TYPES[1]
local _scoreButton = nil
local _clearButton = nil
local _backButton  = nil
local _iconButtons = {}

local function containsPoint(btn, px, py)
  return px >= btn.x and px <= btn.x + btn.w
     and py >= btn.y and py <= btn.y + btn.h
end

local function newIconButton(x, y, sz, ttype, asset)
  return {
    x = x, y = y, w = sz, h = sz,
    asset     = asset,
    tokenType = ttype,
    hovered   = false,
    update = function(self, mx, my)
      self.hovered = containsPoint(self, mx, my)
    end,
    draw = function(self)
      local sel = (self.tokenType == _selected)
      if sel then
        love.graphics.setColor(Palette.accent[1], Palette.accent[2], Palette.accent[3], 0.3)
        love.graphics.rectangle("fill", self.x, self.y, self.w, self.h, 8 * SCALE_X, 8 * SCALE_Y)
      end
      local col = sel and Palette.accent
               or (self.hovered and Palette.primary or { 0.35, 0.35, 0.35, 1 })
      love.graphics.setColor(col)
      love.graphics.setLineWidth(3 * math.max(SCALE_X, SCALE_Y))
      love.graphics.rectangle("line", self.x, self.y, self.w, self.h, 8 * SCALE_X, 8 * SCALE_Y)
      love.graphics.setLineWidth(1)
      if self.asset then
        local iw, ih = self.asset:getDimensions()
        local s = math.min(self.w * 0.70 / iw, self.h * 0.70 / ih)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.asset, self.x + self.w / 2, self.y + self.h / 2, 0, s, s, iw / 2, ih / 2)
      end
      love.graphics.setColor(1, 1, 1, 1)
    end,
    mousepressed = function(self, px, py, btn)
      if btn == 1 and containsPoint(self, px, py) then
        _selected = self.tokenType
        return true
      end
      return false
    end,
    touchpressed = function(self, px, py)
      if containsPoint(self, px, py) then
        _selected = self.tokenType
        return true
      end
      return false
    end,
  }
end

function sandbox.init(onBack)
  _onBack   = onBack
  Token.clearAll()
  events.loadAll()
  areas.pool.chips = {}

  local highestLevel = Profile.getHighestLevelReached()
  local available = {}
  for _, ttype in ipairs(TOKEN_TYPES) do
    if Unlocks.isTokenUnlocked(ttype, highestLevel) then
      available[#available + 1] = ttype
    end
  end
  _selected = available[1]

  _iconButtons = {}
  for i, ttype in ipairs(available) do
    local col = (i <= 8) and 0 or 1
    local row = (i <= 8) and (i - 1) or (i - 9)
    local x   = (PANEL_X + col * (BTN_SIZE + COL_GAP)) * SCALE_X
    local y   = (PANEL_Y + row * (BTN_SIZE + ROW_GAP)) * SCALE_Y
    local sz  = BTN_SIZE * SCALE_X
    _iconButtons[#_iconButtons + 1] = newIconButton(x, y, sz, ttype, getTokenAsset(ttype))
  end

  -- Tallest column is 8 rows
  local pickerBottom = PANEL_Y + 8 * (BTN_SIZE + ROW_GAP) - ROW_GAP
  local btnY = pickerBottom + 20

  local sequences = require("core.newSequences")
  _scoreButton = Button.new(
    PANEL_X * SCALE_X, btnY * SCALE_Y,
    (BTN_SIZE * 2 + COL_GAP) * SCALE_X, 200 * SCALE_Y,
    "Score", 72, function() sequences.score() end
  )
  _clearButton = Button.new(
    PANEL_X * SCALE_X, (btnY + 220) * SCALE_Y,
    (BTN_SIZE * 2 + COL_GAP) * SCALE_X, 200 * SCALE_Y,
    "Clear", 72, function()
      Token.clearAll()
      progressBar.reset()
      threatBar.reset()
      Dtor.reset()
      end
  )
  _backButton = Button.new(
    PANEL_X * SCALE_X, (btnY + 440) * SCALE_Y,
    (BTN_SIZE * 2 + COL_GAP) * SCALE_X, 200 * SCALE_Y,
    "Back", 72,
    function()
      Token.clearAll()
      if _onBack then _onBack() end
    end
  )
end

function sandbox.update(dt, mx, my)
  for _, btn in ipairs(_iconButtons) do btn:update(mx, my) end
  _scoreButton:update(mx, my)
  _clearButton:update(mx, my)
  _backButton:update(mx, my)
end

function sandbox.draw()
  local pickerBottom = PANEL_Y + 8 * (BTN_SIZE + ROW_GAP) - ROW_GAP
  local btnY         = pickerBottom + 20
  local panelH       = (btnY + 360 - (PANEL_Y - 10)) * SCALE_Y

  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.rectangle("fill",
    (PANEL_X - 5) * SCALE_X, (PANEL_Y - 10) * SCALE_Y,
    (BTN_SIZE * 2 + COL_GAP + 10) * SCALE_X, panelH,
    8 * SCALE_X, 8 * SCALE_Y)
  love.graphics.setColor(1, 1, 1, 1)

  for _, btn in ipairs(_iconButtons) do btn:draw() end
  _scoreButton:draw()
  _clearButton:draw()
  _backButton:draw()

  local font = Manifest.getFont(48)
  love.graphics.setFont(font)
  love.graphics.setColor(Palette.accent)
  love.graphics.print("SANDBOX", PANEL_X * SCALE_X, 2 * SCALE_Y)
  love.graphics.setColor(1, 1, 1, 1)
end

local function spawnAt(x, y)
  if not _selected then return end
  local dk = areas.desk
  if not dk then return end
  Token.new_fling(x, y, dk, {
    type    = _selected,
    bounces = math.random(0, 2),
    delay   = false,
  })
end

function sandbox.mousepressed(x, y, button)
  for _, btn in ipairs(_iconButtons) do
    if btn:mousepressed(x, y, button) then return end
  end
  if _scoreButton:mousepressed(x, y, button) then return end
  if _clearButton:mousepressed(x, y, button) then return end
  if _backButton:mousepressed(x, y, button)  then return end
  if button == 1 then spawnAt(x, y) end
end

function sandbox.touchpressed(x, y)
  for _, btn in ipairs(_iconButtons) do
    if btn:touchpressed(x, y) then return end
  end
  if _scoreButton:touchpressed(x, y) then return end
  if _clearButton:touchpressed(x, y) then return end
  if _backButton:touchpressed(x, y)  then return end
  spawnAt(x, y)
end

return sandbox
