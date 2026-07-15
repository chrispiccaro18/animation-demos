local Button      = require("core.button")
local ButtonGroup = require("core.buttonGroup")
local Carousel    = require("core.carousel")
local Slider      = require("core.slider")
local Checkbox    = require("core.checkbox")
local Manifest    = require("assets.manifest")
local Palette     = require("lib.palette")
local config      = require("lib.config")
local Settings    = require("lib.settings")
local WindowMode  = require("lib.windowMode")
local Audio       = require("assets.audio")

local optionsMenu = {}

local _active    = false
local _activeTab = "game"

local _getGlowQuality = nil
local _setGlowQuality = nil

-- Panel dimensions (design units)
local PX    = 720
local PY    = 280
local PW    = 2400
local PH    = 1600
local TAB_H = 140

-- Row layout (design units)
local CONTENT_TOP  = PY + TAB_H + 70
local ROW_MARGIN_X = 300
local ROW_WIDGET_W = PW - 2 * ROW_MARGIN_X
local ROW_WIDGET_H = 130
local CAROUSEL_EXTRA_H = 40  -- must match Carousel's internal dot-strip reservation
local LABEL_H      = 64
local LABEL_GAP    = 28
local ROW_GAP      = 70
local LABEL_FONT_SIZE  = 48
local WIDGET_FONT_SIZE = 72

local TABS       = { "Game", "Video", "Audio" }
local TABS_LOWER = { "game", "video", "audio" }

local PALETTE_DISPLAY = {
  default      = "Default",
  colorblind   = "Colorblind",
  highContrast = "High Contrast",
}

local _tabGroup    = nil
local _closeButton = nil
local _rows        = { game = {}, video = {}, audio = {} }

local TAB_GAP = 30

local function buildTabs()
  _tabGroup = ButtonGroup.new(
    PX * SCALE_X, PY * SCALE_Y, PW * SCALE_X, TAB_H * SCALE_Y,
    TABS, 72, 1,
    function(_, tabKey) _activeTab = tabKey end,
    { values = TABS_LOWER, fillMode = "solid", gap = TAB_GAP * SCALE_X }
  )
end

local function rowX() return (PX + ROW_MARGIN_X) * SCALE_X end
local function rowW() return ROW_WIDGET_W * SCALE_X end
local function panelCenterX() return PX + PW / 2 end

-- Sliders: track is centered under the row label, value readout sits to its
-- right (outside the centered width, using the row's outer margin as slack).
local SLIDER_TRACK_W = 1200
local function sliderX() return (panelCenterX() - SLIDER_TRACK_W / 2) * SCALE_X end
local function sliderW() return SLIDER_TRACK_W * SCALE_X end

local function buildGameTab()
  local y = CONTENT_TOP
  local rows = {}

  -- Speed
  do
    local labelY, widgetY = y, y + LABEL_H + LABEL_GAP
    local options = {}
    for i, preset in ipairs(config.speedPresets) do
      options[i] = { label = preset .. "x", value = preset }
    end
    local carousel = Carousel.new(
      rowX(), widgetY * SCALE_Y, rowW(), ROW_WIDGET_H * SCALE_Y,
      options, config.speedIndex, WIDGET_FONT_SIZE,
      function(i, value)
        config.speedIndex = i
        config.speed      = value
        Settings.save({ speedIndex = i })
      end
    )
    table.insert(rows, { label = "Speed", labelY = labelY, widget = carousel })
    y = widgetY + ROW_WIDGET_H + CAROUSEL_EXTRA_H + ROW_GAP
  end

  -- Play/Discard Action (stored only — no gameplay code reads this yet)
  do
    local labelY, widgetY = y, y + LABEL_H + LABEL_GAP
    local current  = Settings.get().playAction
    local selected = (current == "click") and 1 or 2
    local group = ButtonGroup.new(
      rowX(), widgetY * SCALE_Y, rowW(), ROW_WIDGET_H * SCALE_Y,
      { "Click", "Drag" }, WIDGET_FONT_SIZE, selected,
      function(_, value)
        Settings.save({ playAction = value })
      end,
      { values = { "click", "drag" }, gap = 40 * SCALE_X }
    )
    table.insert(rows, { label = "Play/Discard Action", labelY = labelY, widget = group })
    y = widgetY + ROW_WIDGET_H + ROW_GAP
  end

  -- Color Palette
  do
    local labelY, widgetY = y, y + LABEL_H + LABEL_GAP
    local names  = Palette.variantNames()
    local labels = {}
    for i, name in ipairs(names) do
      labels[i] = PALETTE_DISPLAY[name] or name
    end
    local current  = Palette.getVariant()
    local selected = 1
    for i, name in ipairs(names) do
      if name == current then selected = i break end
    end
    local group = ButtonGroup.new(
      rowX(), widgetY * SCALE_Y, rowW(), ROW_WIDGET_H * SCALE_Y,
      labels, WIDGET_FONT_SIZE, selected,
      function(_, value)
        Palette.setVariant(value)
        Settings.save({ paletteVariant = value })
      end,
      { values = names, gap = 30 * SCALE_X }
    )
    table.insert(rows, { label = "Color Palette", labelY = labelY, widget = group })
    y = widgetY + ROW_WIDGET_H + ROW_GAP
  end

  _rows.game = rows
end

local function buildVideoTab()
  local y = CONTENT_TOP
  local rows = {}
  local settings = Settings.get()

  -- Window Mode
  do
    local labelY, widgetY = y, y + LABEL_H + LABEL_GAP
    local modes  = { "fullscreen", "borderless", "windowed" }
    local labels = { "Fullscreen", "Borderless", "Windowed" }
    local selected = 3
    for i, m in ipairs(modes) do
      if m == settings.windowMode then selected = i break end
    end
    local group = ButtonGroup.new(
      rowX(), widgetY * SCALE_Y, rowW(), ROW_WIDGET_H * SCALE_Y,
      labels, WIDGET_FONT_SIZE, selected,
      function(_, value)
        WindowMode.apply(value, settings.resolutionW, settings.resolutionH)
        Settings.save({ windowMode = value })
      end,
      { values = modes, gap = 30 * SCALE_X }
    )
    table.insert(rows, { label = "Window Mode", labelY = labelY, widget = group })
    y = widgetY + ROW_WIDGET_H + ROW_GAP
  end

  -- Resolution
  do
    local labelY, widgetY = y, y + LABEL_H + LABEL_GAP
    local options = WindowMode.listResolutions()
    local selected = 1
    for i, opt in ipairs(options) do
      if opt.value.w == settings.resolutionW and opt.value.h == settings.resolutionH then
        selected = i
        break
      end
    end
    local carousel = Carousel.new(
      rowX(), widgetY * SCALE_Y, rowW(), ROW_WIDGET_H * SCALE_Y,
      options, selected, WIDGET_FONT_SIZE,
      function(_, value)
        WindowMode.apply(settings.windowMode, value.w, value.h)
        Settings.save({ resolutionW = value.w, resolutionH = value.h })
      end
    )
    table.insert(rows, { label = "Resolution", labelY = labelY, widget = carousel })
    y = widgetY + ROW_WIDGET_H + CAROUSEL_EXTRA_H + ROW_GAP
  end

  -- Vsync
  do
    local labelY, widgetY = y, y + LABEL_H + LABEL_GAP
    local size = 80
    local checkboxX = (panelCenterX() - size / 2) * SCALE_X
    local checkbox = Checkbox.new(
      checkboxX, widgetY * SCALE_Y, size * SCALE_X, settings.vsync,
      function(checked)
        WindowMode.setVsync(checked)
        Settings.save({ vsync = checked })
      end
    )
    table.insert(rows, { label = "Vsync", labelY = labelY, widget = checkbox })
    y = widgetY + size + ROW_GAP
  end

  -- Glow Quality
  do
    local labelY, widgetY = y, y + LABEL_H + LABEL_GAP
    local labels = { "High", "Medium", "Low" }
    local values = { "high", "medium", "low" }
    local current  = _getGlowQuality and _getGlowQuality() or "high"
    local selected = 1
    for i, v in ipairs(values) do
      if v == current then selected = i break end
    end
    local group = ButtonGroup.new(
      rowX(), widgetY * SCALE_Y, rowW(), ROW_WIDGET_H * SCALE_Y,
      labels, WIDGET_FONT_SIZE, selected,
      function(_, value)
        if _setGlowQuality then _setGlowQuality(value) end
        Settings.save({ glowQuality = value })
      end,
      { values = values, gap = 30 * SCALE_X }
    )
    table.insert(rows, { label = "Glow Quality", labelY = labelY, widget = group })
    y = widgetY + ROW_WIDGET_H + ROW_GAP
  end

  _rows.video = rows
end

local function buildAudioTab()
  local y = CONTENT_TOP
  local rows = {}
  local settings = Settings.get()

  -- Master (real: drives love.audio.setVolume)
  do
    local labelY, widgetY = y, y + LABEL_H + LABEL_GAP
    local slider = Slider.new(
      sliderX(), widgetY * SCALE_Y, sliderW(), ROW_WIDGET_H * SCALE_Y,
      love.audio.getVolume(),
      function(value) love.audio.setVolume(value) end,
      function(value) Settings.save({ volume = value }) end,
      WIDGET_FONT_SIZE
    )
    table.insert(rows, { label = "Master", labelY = labelY, widget = slider })
    y = widgetY + ROW_WIDGET_H + ROW_GAP
  end

  -- Music bus (no tracks loaded yet, but the bus itself is live — see
  -- assets/audio/init.lua's Audio.playMusic/Audio.music.tracks)
  do
    local labelY, widgetY = y, y + LABEL_H + LABEL_GAP
    local slider = Slider.new(
      sliderX(), widgetY * SCALE_Y, sliderW(), ROW_WIDGET_H * SCALE_Y,
      settings.musicVolume,
      function(value) Audio.setMusicVolume(value) end,
      function(value) Settings.save({ musicVolume = value }) end,
      WIDGET_FONT_SIZE
    )
    table.insert(rows, { label = "Music", labelY = labelY, widget = slider })
    y = widgetY + ROW_WIDGET_H + ROW_GAP
  end

  -- SFX bus (mousedown/mouseup play a click sfx so the slider previews its
  -- own volume as you drag it)
  do
    local labelY, widgetY = y, y + LABEL_H + LABEL_GAP
    local slider = Slider.new(
      sliderX(), widgetY * SCALE_Y, sliderW(), ROW_WIDGET_H * SCALE_Y,
      settings.sfxVolume,
      function(value) Audio.setSfxVolume(value) end,
      function(value)
        Settings.save({ sfxVolume = value })
        Audio.playClickOut()
      end,
      WIDGET_FONT_SIZE,
      function() Audio.playClickIn() end
    )
    table.insert(rows, { label = "SFX", labelY = labelY, widget = slider })
    y = widgetY + ROW_WIDGET_H + ROW_GAP
  end

  _rows.audio = rows
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
  -- Rebuild rows from current state every time the menu opens: several
  -- values (speed, palette, glow quality) can change from outside the menu
  -- (keyboard shortcuts, touch gestures, debug hotkeys) while it's closed,
  -- and the rows otherwise only reflect whatever was current at load().
  buildGameTab()
  buildVideoTab()
  buildAudioTab()

  _active    = true
  _activeTab = "game"
  if _tabGroup then _tabGroup:setSelected(1) end
end

function optionsMenu.hide()
  _active = false
end

function optionsMenu.isActive()
  return _active
end

function optionsMenu.update(mx, my)
  if not _active then return end
  _tabGroup:update(mx, my)
  _closeButton:update(mx, my)
  for _, row in ipairs(_rows[_activeTab]) do
    row.widget:update(mx, my)
  end
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

  _tabGroup:draw()

  -- Separator line under tabs
  love.graphics.setColor(Palette.primary)
  love.graphics.setLineWidth(2 * SCALE_X)
  love.graphics.line(
    PX * SCALE_X,        (PY + TAB_H) * SCALE_Y,
    (PX + PW) * SCALE_X, (PY + TAB_H) * SCALE_Y)
  love.graphics.setLineWidth(1)

  local font = Manifest.getFont(LABEL_FONT_SIZE)
  love.graphics.setFont(font)
  love.graphics.setColor(Palette.muted)
  for _, row in ipairs(_rows[_activeTab]) do
    love.graphics.printf(row.label, PX * SCALE_X, row.labelY * SCALE_Y, PW * SCALE_X, "center")
  end

  for _, row in ipairs(_rows[_activeTab]) do
    row.widget:draw()
  end

  _closeButton:draw()
  love.graphics.setColor(1, 1, 1, 1)
end

function optionsMenu.mousepressed(x, y, button)
  if not _active then return false end
  if _tabGroup:mousepressed(x, y, button) then return true end
  if _closeButton:mousepressed(x, y, button) then return true end
  for _, row in ipairs(_rows[_activeTab]) do
    if row.widget:mousepressed(x, y, button) then return true end
  end
  return true  -- consume all clicks when open to prevent menu click-through
end

function optionsMenu.touchpressed(x, y)
  return optionsMenu.mousepressed(x, y, 1)
end

return optionsMenu
