local Button   = require("core.button")
local Manifest = require("assets.manifest")
local Palette  = require("lib.palette")
local config   = require("lib.config")

local optionsMenu = {}

local _active    = false
local _activeTab = "game"

local _getGlowQuality = nil
local _setGlowQuality = nil

-- Panel dimensions (design units)
local PX    = 820
local PY    = 380
local PW    = 2200
local PH    = 1400
local TAB_H = 140

local _tabButtons     = {}
local _closeButton    = nil
local _speedButtons   = {}
local _qualityButtons = {}
local _volumeButtons  = {}

local TABS       = { "Game", "Video", "Audio" }
local TABS_LOWER = { "game", "video", "audio" }

local LABEL_Y  = PY + TAB_H + 40   -- design units, multiplied at draw time
local BUTTON_Y = PY + TAB_H + 200  -- design units, multiplied at build time

local function buildTabs()
  _tabButtons = {}
  local tw = PW / #TABS
  for i, label in ipairs(TABS) do
    local bx  = (PX + (i - 1) * tw) * SCALE_X
    local by  = PY * SCALE_Y
    local tabKey = TABS_LOWER[i]
    _tabButtons[i] = Button.new(bx, by, tw * SCALE_X, TAB_H * SCALE_Y, label, 72, function()
      _activeTab = tabKey
    end)
  end
end

local function buildGameTab()
  _speedButtons = {}
  local bw     = 500
  local bh     = 130
  local gap    = 40
  local n      = #config.speedPresets
  local totalW = n * bw + (n - 1) * gap
  local startX = 1920 - totalW / 2

  for i, preset in ipairs(config.speedPresets) do
    local bx = (startX + (i - 1) * (bw + gap)) * SCALE_X
    local by = BUTTON_Y * SCALE_Y
    _speedButtons[i] = Button.new(bx, by, bw * SCALE_X, bh * SCALE_Y, preset .. "x", 72, function()
      config.speedIndex = i
      config.speed      = preset
    end)
  end
end

local function buildVideoTab()
  _qualityButtons = {}
  local qualities = {
    { label = "High",   value = "high"   },
    { label = "Medium", value = "medium" },
    { label = "Low",    value = "low"    },
  }
  local bw     = 600
  local bh     = 130
  local gap    = 40
  local totalW = #qualities * bw + (#qualities - 1) * gap
  local startX = 1920 - totalW / 2

  for i, q in ipairs(qualities) do
    local bx = (startX + (i - 1) * (bw + gap)) * SCALE_X
    local by = BUTTON_Y * SCALE_Y
    _qualityButtons[i] = Button.new(bx, by, bw * SCALE_X, bh * SCALE_Y, q.label, 72, function()
      if _setGlowQuality then _setGlowQuality(q.value) end
    end)
    _qualityButtons[i]._value = q.value
  end
end

local function buildAudioTab()
  _volumeButtons = {}
  local presets = { 0, 0.25, 0.5, 0.75, 1.0 }
  local labels  = { "0%", "25%", "50%", "75%", "100%" }
  local bw     = 300
  local bh     = 130
  local gap    = 25
  local totalW = #presets * bw + (#presets - 1) * gap
  local startX = 1920 - totalW / 2

  for i, vol in ipairs(presets) do
    local bx = (startX + (i - 1) * (bw + gap)) * SCALE_X
    local by = BUTTON_Y * SCALE_Y
    _volumeButtons[i] = Button.new(bx, by, bw * SCALE_X, bh * SCALE_Y, labels[i], 72, function()
      love.audio.setVolume(vol)
    end)
    _volumeButtons[i]._volume = vol
  end
end

local function buildClose()
  local bw = 400
  local bh = 110
  local bx = (1920 - bw / 2) * SCALE_X
  local by = (PY + PH - bh - 30) * SCALE_Y
  _closeButton = Button.new(bx, by, bw * SCALE_X, bh * SCALE_Y, "Close", 72, function()
    optionsMenu.hide()
  end)
end

function optionsMenu.load(callbacks)
  _getGlowQuality = callbacks and callbacks.getGlowQuality
  _setGlowQuality = callbacks and callbacks.setGlowQuality
  buildTabs()
  buildGameTab()
  buildVideoTab()
  buildAudioTab()
  buildClose()
end

function optionsMenu.show()
  _active    = true
  _activeTab = "game"
end

function optionsMenu.hide()
  _active = false
end

function optionsMenu.isActive()
  return _active
end

function optionsMenu.update(mx, my)
  if not _active then return end
  for _, btn in ipairs(_tabButtons) do btn:update(mx, my) end
  _closeButton:update(mx, my)
  if _activeTab == "game" then
    for _, btn in ipairs(_speedButtons)   do btn:update(mx, my) end
  elseif _activeTab == "video" then
    for _, btn in ipairs(_qualityButtons) do btn:update(mx, my) end
  elseif _activeTab == "audio" then
    for _, btn in ipairs(_volumeButtons)  do btn:update(mx, my) end
  end
end

local function drawActiveHighlight(btn)
  love.graphics.setColor(Palette.accent[1], Palette.accent[2], Palette.accent[3], 0.25)
  love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 12 * SCALE_X, 12 * SCALE_Y)
end

function optionsMenu.draw()
  if not _active then return end

  -- Dark scrim over the whole canvas
  love.graphics.setColor(0, 0, 0, 0.75)
  love.graphics.rectangle("fill", 0, 0, 3840 * SCALE_X, 2160 * SCALE_Y)

  -- Panel background
  love.graphics.setColor(Palette.background)
  love.graphics.rectangle("fill",
    PX * SCALE_X, PY * SCALE_Y, PW * SCALE_X, PH * SCALE_Y,
    20 * SCALE_X, 20 * SCALE_Y)

  -- Panel border
  love.graphics.setColor(Palette.primary)
  love.graphics.setLineWidth(3 * SCALE_X)
  love.graphics.rectangle("line",
    PX * SCALE_X, PY * SCALE_Y, PW * SCALE_X, PH * SCALE_Y,
    20 * SCALE_X, 20 * SCALE_Y)
  love.graphics.setLineWidth(1)

  -- Active tab background fill
  local tw = PW / #TABS
  for i = 1, #TABS do
    if _activeTab == TABS_LOWER[i] then
      love.graphics.setColor(Palette.primary)
      love.graphics.rectangle("fill",
        (PX + (i - 1) * tw) * SCALE_X, PY * SCALE_Y,
        tw * SCALE_X, TAB_H * SCALE_Y)
      break
    end
  end

  for _, btn in ipairs(_tabButtons) do btn:draw() end

  -- Separator line under tabs
  love.graphics.setColor(Palette.primary)
  love.graphics.setLineWidth(2 * SCALE_X)
  love.graphics.line(
    PX * SCALE_X,        (PY + TAB_H) * SCALE_Y,
    (PX + PW) * SCALE_X, (PY + TAB_H) * SCALE_Y)
  love.graphics.setLineWidth(1)

  local font = Manifest.getFont(72)
  love.graphics.setFont(font)

  if _activeTab == "game" then
    love.graphics.setColor(Palette.muted)
    love.graphics.printf("Game Speed", PX * SCALE_X, LABEL_Y * SCALE_Y, PW * SCALE_X, "center")
    for i, btn in ipairs(_speedButtons) do
      if i == config.speedIndex then drawActiveHighlight(btn) end
      btn:draw()
    end

  elseif _activeTab == "video" then
    love.graphics.setColor(Palette.muted)
    love.graphics.printf("Glow Quality", PX * SCALE_X, LABEL_Y * SCALE_Y, PW * SCALE_X, "center")
    local cur = _getGlowQuality and _getGlowQuality() or ""
    for _, btn in ipairs(_qualityButtons) do
      if btn._value == cur then drawActiveHighlight(btn) end
      btn:draw()
    end

  elseif _activeTab == "audio" then
    love.graphics.setColor(Palette.muted)
    love.graphics.printf("Volume", PX * SCALE_X, LABEL_Y * SCALE_Y, PW * SCALE_X, "center")
    local curVol = love.audio.getVolume()
    for _, btn in ipairs(_volumeButtons) do
      if math.abs(btn._volume - curVol) < 0.01 then drawActiveHighlight(btn) end
      btn:draw()
    end
  end

  _closeButton:draw()
  love.graphics.setColor(1, 1, 1, 1)
end

function optionsMenu.mousepressed(x, y, button)
  if not _active then return false end
  for _, btn in ipairs(_tabButtons) do
    if btn:mousepressed(x, y, button) then return true end
  end
  if _closeButton:mousepressed(x, y, button) then return true end
  if _activeTab == "game" then
    for _, btn in ipairs(_speedButtons) do
      if btn:mousepressed(x, y, button) then return true end
    end
  elseif _activeTab == "video" then
    for _, btn in ipairs(_qualityButtons) do
      if btn:mousepressed(x, y, button) then return true end
    end
  elseif _activeTab == "audio" then
    for _, btn in ipairs(_volumeButtons) do
      if btn:mousepressed(x, y, button) then return true end
    end
  end
  return true  -- consume all clicks when open to prevent menu click-through
end

function optionsMenu.touchpressed(x, y)
  return optionsMenu.mousepressed(x, y, 1)
end

return optionsMenu
