---@class overlayStats
---A performance monitoring overlay module for LÖVE games
---@field isActive boolean Whether the overlay is currently visible
---@field sampleSize number Maximum number of samples to keep for metrics
---@field vsyncEnabled boolean Current VSync state
local name, version, vendor, device = love.graphics.getRendererInfo()
local overlayStats = {
  isActive = false,
  gameCanvas = nil,
  sampleSize = 60,
  vsyncEnabled = nil,
  lastControllerCheck = 0,
  CONTROLLER_COOLDOWN = 0.2,
  -- Store active particle systems
  particleSystems = {},
  renderInfo = {
    name = name,
    version = version,
    vendor = vendor,
    device = device,
  },
  sysInfo = {
    arch = love.system.getOS() ~= "Web" and require("ffi").arch or "Web",
    os = love.system.getOS(),
    cpuCount = love.system.getProcessorCount(),
  },
  supportedFeatures = {
    glsl3 = false,
    pixelShaderHighp = false,
  },
  metrics = {
    canvases = {},
    canvasSwitches = {},
    drawCalls = {},
    drawCallsBatched = {},
    frameTime = {},
    imageCount = {},
    memoryUsage = {},
    shaderSwitches = {},
    textureMemory = {},
    particleCount = {},
  },
  currentSample = 0,
  -- Touch activation parameters
  touch = {
    cornerSize = 80, -- Size of the activation area in pixels
    lastTapTime = 0, -- Time of the last tap
    doubleTapThreshold = 0.5, -- Maximum time between taps to register as double-tap
    overlayArea = {x = 10, y = 10, width = 280, height = 340}, -- Will be updated in draw
  },
}

-- Private functions

---Calculates averages for all performance metrics
---@return table averages Table of averaged metric values
local function getAverages()
  if not overlayStats.isActive then
    return {}
  end

  local averages = {}
  for metric, samples in pairs(overlayStats.metrics) do
    local sum = 0
    local count = 0
    for _, value in ipairs(samples) do
      sum = sum + value
      count = count + 1
    end
    averages[metric] = count > 0 and sum / count or 0
  end
  return averages
end

---Checks and processes controller input for toggling the overlay
---Called from update() function
local function handleController()
  -- Controller input with cooldown
  local currentTime = love.timer.getTime()
  if currentTime - overlayStats.lastControllerCheck < overlayStats.CONTROLLER_COOLDOWN then
    return
  end

  local joysticks = love.joystick.getJoysticks()
  for _, joystick in ipairs(joysticks) do
    if joystick:isGamepadDown("back") then
      if joystick:isGamepadDown("a") then
        toggleOverlay()
        overlayStats.lastControllerCheck = currentTime
      elseif joystick:isGamepadDown("b") then
        toggleVSync()
        overlayStats.lastControllerCheck = currentTime
      end
    end
  end
end

---Toggles the visibility of the overlay
---Resets all metrics on activation
local function toggleOverlay()
  overlayStats.isActive = not overlayStats.isActive
  -- Reset metrics when toggling
  for k, _ in pairs(overlayStats.metrics) do
    overlayStats.metrics[k] = {}
  end
  overlayStats.currentSample = 0
  print(string.format("Overlay %s", overlayStats.isActive and "enabled" or "disabled"))
end

---Toggles the VSync state in LÖVE
---Only functions when the overlay is active
local function toggleVSync()
  if not overlayStats.isActive then
    return
  end
  overlayStats.vsyncEnabled = not overlayStats.vsyncEnabled
  love.window.setVSync(overlayStats.vsyncEnabled and 1 or 0)
  print(string.format("VSync %s", overlayStats.vsyncEnabled and "enabled" or "disabled"))
end

---Checks if the given touch position is in the top-right corner activation area
---@param x number The x-coordinate of the touch
---@param y number The y-coordinate of the touch
---@return boolean inCorner True if touch is in the activation area
local function isTouchInCorner(x, y)
  local w, h = love.graphics.getDimensions()
  return x >= w - overlayStats.touch.cornerSize and y <= overlayStats.touch.cornerSize
end

---Checks if the given touch position is inside the overlay area
---@param x number The x-coordinate of the touch
---@param y number The y-coordinate of the touch
---@return boolean insideOverlay True if touch is inside the overlay area
local function isTouchInsideOverlay(x, y)
  local area = overlayStats.touch.overlayArea
  return x >= area.x and x <= area.x + area.width and
         y >= area.y and y <= area.y + area.height
end

---Processes touch input for the overlay toggle
---@param x number The x-coordinate of the touch
---@param y number The y-coordinate of the touch
---@return nil
local function handleTouch(x, y)
  local currentTime = love.timer.getTime()
  local timeSinceLastTap = currentTime - overlayStats.touch.lastTapTime

  if overlayStats.isActive and isTouchInsideOverlay(x, y) then
    -- Handle touches inside the active overlay
    if timeSinceLastTap <= overlayStats.touch.doubleTapThreshold then
      -- Double tap inside overlay - toggle VSync
      toggleVSync()
      overlayStats.touch.lastTapTime = 0
    else
      overlayStats.touch.lastTapTime = currentTime
    end
  elseif isTouchInCorner(x, y) then
    -- Original behavior for corner taps to toggle overlay
    if timeSinceLastTap <= overlayStats.touch.doubleTapThreshold then
      toggleOverlay()
      overlayStats.touch.lastTapTime = 0
    else
      overlayStats.touch.lastTapTime = currentTime
    end
  end
end

-- Public API

-- Font and scale set in load() once canvas size is known
local _font = nil
local _s    = 1  -- overlay scale: canvasH / 1080

---Initializes the overlay stats module
---@return nil
function overlayStats.load()
  -- Scale overlay to canvas height so it's readable at any resolution
  _s    = math.max(SCALE_Y * 2, 0.5)   -- SCALE_Y*2 = canvasH/1080; floor at 50%
  _font = love.graphics.newFont(math.max(math.floor(16 * _s), 8))

  -- Initialize moving averages
  for k, _ in pairs(overlayStats.metrics) do
    overlayStats.metrics[k] = {}
  end
  -- Get initial vsync state from LÖVE config
  overlayStats.vsyncEnabled = love.window.getVSync() == 1

  -- Get graphics feature support information
  local supported = love.graphics.getSupported()
  overlayStats.supportedFeatures.glsl3 = supported.glsl3
  overlayStats.supportedFeatures.pixelShaderHighp = supported.pixelshaderhighp
end

---Draws the performance overlay when active
---@return nil
function overlayStats.draw()
  if not overlayStats.isActive then
    return
  end

  local averages = getAverages()

  love.graphics.push("all")
  love.graphics.setFont(_font)

  local lh  = math.floor(20 * _s)   -- normal line height
  local lhL = math.floor(30 * _s)   -- large gap (section breaks)
  local ox  = math.floor(10 * _s)   -- left/top margin of box
  local tx  = math.floor(20 * _s)   -- text x
  local padding = math.floor(20 * _s)
  local baseWidth = math.floor(280 * _s)

  -- Calculate dynamic width
  local versionTextWidth  = _font:getWidth(string.format("%s", overlayStats.renderInfo.version))
  local rendererInfoWidth = _font:getWidth(
    string.format("Renderer: %s (%s)", overlayStats.renderInfo.name, overlayStats.renderInfo.vendor)
  )
  local systemInfoWidth = _font:getWidth(
    overlayStats.sysInfo.os .. " " .. overlayStats.sysInfo.arch .. ": " .. overlayStats.sysInfo.cpuCount .. "x CPU"
  )
  local rectW = math.max(versionTextWidth, rendererInfoWidth, systemInfoWidth, baseWidth) + padding

  -- First pass: count total height so the background rect is sized correctly
  local totalLines = 18  -- number of print() calls below
  local totalH = lh * totalLines + lhL * 3 + lh  -- approximate; +padding
  totalH = totalH + math.floor(20 * _s)

  overlayStats.touch.overlayArea = { x = ox, y = ox, width = rectW, height = totalH }
  love.graphics.setColor(0, 0, 0, 0.8)
  love.graphics.rectangle("fill", ox, ox, rectW, totalH)

  local y = math.floor(20 * _s)

  -- Display / viewport info
  local winW, winH = love.graphics.getDimensions()
  local dpiScale = love.window.getDPIScale()
  love.graphics.setColor(1, 1, 0.4, 1)
  love.graphics.print(string.format("Window: %dx%d", winW, winH), tx, y);                                                               y = y + lh
  love.graphics.print(string.format("Physical: %dx%d  DPI: %.2f", math.floor(winW * dpiScale), math.floor(winH * dpiScale), dpiScale), tx, y); y = y + lh
  local gc = overlayStats.gameCanvas
  love.graphics.print(gc and string.format("Canvas: %dx%d", gc:getWidth(), gc:getHeight()) or "Canvas: none", tx, y)
  y = y + lhL

  -- System info
  love.graphics.setColor(0.678, 0.847, 0.902, 1)
  love.graphics.print(overlayStats.sysInfo.os .. " " .. overlayStats.sysInfo.arch .. ": " .. overlayStats.sysInfo.cpuCount .. "x CPU", tx, y); y = y + lhL
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print(string.format("Renderer: %s (%s)", overlayStats.renderInfo.name, overlayStats.renderInfo.vendor), tx, y); y = y + lh
  love.graphics.print(string.format("%s", overlayStats.renderInfo.version), tx, y);                                                      y = y + lhL

  -- Performance
  local stats = love.graphics.getStats()
  local frameTime = averages.frameTime or 0
  local fps = frameTime > 0 and (1 / frameTime) or 0
  love.graphics.setColor(0, 1, 0, 1)
  love.graphics.print(string.format("FPS: %.1f (%.1fms)", fps, frameTime * 1000), tx, y);                                               y = y + lh
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print(string.format("Draw Calls: %d (%d batched)", stats.drawcalls, stats.drawcallsbatched), tx, y);                    y = y + lh
  love.graphics.print(string.format("Shader Switches: %d", stats.shaderswitches), tx, y);                                               y = y + lh
  love.graphics.print(string.format("Canvas Switches: %d", stats.canvasswitches), tx, y);                                               y = y + lh
  love.graphics.print(string.format("Canvases: %d", stats.canvases), tx, y);                                                            y = y + lh
  love.graphics.print(string.format("RAM: %.1f MB", averages.memoryUsage / 1024), tx, y);                                               y = y + lh
  love.graphics.print(string.format("VRAM: %.1f MB", stats.texturememory / (1024 * 1024)), tx, y);                                      y = y + lh
  love.graphics.print(string.format("Images: %d", stats.images), tx, y);                                                                y = y + lh
  love.graphics.print(string.format("Particles: %d", math.floor(averages.particleCount or 0)), tx, y);                                  y = y + lh

  love.graphics.setColor(overlayStats.supportedFeatures.glsl3 and {0,1,0,1} or {1,0,0,1})
  love.graphics.print(string.format("GLSL 3: %s", overlayStats.supportedFeatures.glsl3 and "Yes" or "No"), tx, y);                     y = y + lh
  love.graphics.setColor(overlayStats.supportedFeatures.pixelShaderHighp and {0,1,0,1} or {1,0,0,1})
  love.graphics.print(string.format("Pixel Shader highp: %s", overlayStats.supportedFeatures.pixelShaderHighp and "Yes" or "No"), tx, y); y = y + lh
  love.graphics.setColor(overlayStats.vsyncEnabled and {0,1,0,1} or {1,0,0,1})
  love.graphics.print(string.format("VSync: %s", overlayStats.vsyncEnabled and "ON" or "OFF"), tx, y)

  love.graphics.pop()
end

---Updates performance metrics and handles controller input
---@param dt number Delta time since the last frame
---@return nil
function overlayStats.update(dt)
  handleController()

  if not overlayStats.isActive then
    return
  end
  overlayStats.currentSample = overlayStats.currentSample + 1
  if overlayStats.currentSample > overlayStats.sampleSize then
    overlayStats.currentSample = 1
  end

  -- Get draw call stats before any drawing occurs
  local stats = love.graphics.getStats()
  overlayStats.metrics.canvases[overlayStats.currentSample] = stats.canvasses
  overlayStats.metrics.canvasSwitches[overlayStats.currentSample] = stats.canvasswitches
  overlayStats.metrics.drawCalls[overlayStats.currentSample] = stats.drawcalls
  overlayStats.metrics.drawCallsBatched[overlayStats.currentSample] = stats.drawcallsbatched
  overlayStats.metrics.imageCount[overlayStats.currentSample] = stats.images
  overlayStats.metrics.shaderSwitches[overlayStats.currentSample] = stats.shaderswitches
  overlayStats.metrics.textureMemory[overlayStats.currentSample] = stats.texturememory / (1024 * 1024)
  overlayStats.metrics.memoryUsage[overlayStats.currentSample] = collectgarbage("count")
  overlayStats.metrics.frameTime[overlayStats.currentSample] = dt

  -- Calculate total particle count from all registered systems
  local totalParticles = 0
  for ps, _ in pairs(overlayStats.particleSystems) do
    if ps:isActive() then
      totalParticles = totalParticles + ps:getCount()
    end
  end
  overlayStats.metrics.particleCount[overlayStats.currentSample] = totalParticles
end

---Processes keyboard input for the overlay
---@param key string The key that was pressed
---@return nil
function overlayStats.handleKeyboard(key)
  if key == "f3" then
    toggleOverlay()
  elseif key == "f5" then
    toggleVSync()
  end
end

---Handles touch press events for toggling the overlay
---@param id any Touch ID from LÖVE
---@param x number The x-coordinate of the touch
---@param y number The y-coordinate of the touch
---@param dx number The horizontal component of the touch press
---@param dy number The vertical component of the touch press
---@param pressure number The pressure of the touch
---@return nil
function overlayStats.handleTouch(id, x, y, dx, dy, pressure)
  handleTouch(x, y)
end

---Register a particle system to be tracked
---@param particleSystem love.ParticleSystem The particle system to register
---@return nil
function overlayStats.registerParticleSystem(particleSystem)
  overlayStats.particleSystems[particleSystem] = true
end

---Unregister a particle system from tracking
---@param particleSystem love.ParticleSystem The particle system to unregister
---@return nil
function overlayStats.unregisterParticleSystem(particleSystem)
  overlayStats.particleSystems[particleSystem] = nil
end

---Set the main game canvas to display its dimensions in the overlay
---@param canvas love.Canvas The game canvas
---@return nil
function overlayStats.setGameCanvas(canvas)
  overlayStats.gameCanvas = canvas
end

return overlayStats
