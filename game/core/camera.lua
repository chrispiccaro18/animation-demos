local AssetManifest = require("assets.manifest")
local Glow          = require("lib.glow.Glow")
local Color = require("lib.color")

local Camera = {}

function Camera.load()
  local baseAsset = AssetManifest.get("camera", "base")
  local lensAsset = AssetManifest.get("camera", "lens")
  local ringAsset = AssetManifest.get("camera", "ring")
  Camera.x = SCALE_X * 1920
  Camera.y = baseAsset:getHeight() / 2 - 300
  -- Camera.y = 75
  Camera.scale = 1
  Camera.parts = {
    base = {
      asset = baseAsset
    },
    lens = {
      asset = lensAsset,
      originalPosition = { x = 417, y = 690 },
      offsetX = 0,
      offsetY = 0,
    },
    ring = {
      asset = ringAsset,
      originalPosition = { x = 325, y = 597 },
      offsetX = 0,
      offsetY = 0,
      -- color = Color("#FFFFFF"),
      color = Color("#88EDFF"),
      -- color = Color("#9C2B2B"),
      -- color = Color("#6ED59E"),
      -- color = Color("#D56E6E"),
    }
  }
  Camera.offsetX = baseAsset:getWidth() / 2
  Camera.offsetY = baseAsset:getHeight() / 2
  Camera.state = "followMouse"
  Camera.stateData = { time = 0, targetCard = nil }
  return Camera
end

function Camera:setColor(color)
  self.parts.ring.color = color
end

function Camera:followMouse(color)
  self.state = "followMouse"
  if color then self:setColor(color) end
end

function Camera:setIdle(color)
  self.state = "idle"
  -- Seed time so the oscillation starts near the current lens position
  local clampedX = math.max(-1, math.min(1, self.parts.lens.offsetX / 60))
  self.stateData.time = math.asin(clampedX) / 0.4
  if color then
    self:setColor(color)
  else
    self:setColor(Color("#88EDFF"))
  end
end

function Camera:lookAt(card, color)
  self.state = "lookAt"
  self.stateData.targetCard = card
  if color then self:setColor(color) end
end

function Camera:getLensPosition()
  local windowScaleX = SCALE_X / 2
  local windowScaleY = SCALE_Y / 2
  return self.x +
      self.parts.lens.offsetX * self.scale * windowScaleX +
      self.parts.lens.originalPosition.x * self.scale * windowScaleX
      - self.offsetX * windowScaleX / 2,
    self.y * windowScaleY
      + self.parts.lens.offsetY * self.scale * windowScaleY
      + self.parts.lens.originalPosition.y * self.scale * windowScaleY
      - self.offsetY * windowScaleY / 2
end

function Camera:_applyOffsets(dt, targetOffsetX, targetOffsetY)
  self.parts.lens.offsetX = self.parts.lens.offsetX +
    (targetOffsetX - self.parts.lens.offsetX) * 0.2
  self.parts.lens.offsetY = self.parts.lens.offsetY +
    (targetOffsetY - self.parts.lens.offsetY) * 0.15
  self.parts.ring.offsetX = self.parts.ring.offsetX +
    (targetOffsetX - self.parts.ring.offsetX) * 0.2
  self.parts.ring.offsetY = self.parts.ring.offsetY +
    (targetOffsetY - self.parts.ring.offsetY) * 0.15
end

function Camera:update(dt, mouseX, mouseY, scanners)
  local targetOffsetX, targetOffsetY

  if self.state == "followMouse" then
    local distanceFromScreenCenterX = mouseX - SCALE_X * 1920
    local distanceFromScreenCenterY = mouseY - SCALE_Y * 1080
    -- normalize for any screen size
    local offsetX = distanceFromScreenCenterX / (SCALE_X * 3840)
    local offsetY = distanceFromScreenCenterY / (SCALE_Y * 2160)
    targetOffsetX = offsetX * 200
    targetOffsetY = offsetY * 50

  elseif self.state == "idle" then
    -- Wrap at 20π (the joint period of both sine frequencies 0.4 and 0.7)
    self.stateData.time = math.fmod(self.stateData.time + dt * 2, math.pi * 20)
    local t = self.stateData.time
    targetOffsetX = math.sin(t * 0.5) * 80
    targetOffsetY = math.abs(math.cos(t * 0.5)) * 20

  elseif self.state == "lookAt" then
    local card = self.stateData.targetCard
    local distanceFromScreenCenterX = card.current.x - SCALE_X * 1920
    local distanceFromScreenCenterY = card.current.y - SCALE_Y * 1080
    local offsetX = distanceFromScreenCenterX / (SCALE_X * 3840)
    local offsetY = distanceFromScreenCenterY / (SCALE_Y * 2160)
    targetOffsetX = offsetX * 200
    targetOffsetY = offsetY * 50
  end

  if scanners then
    for _, s in pairs(scanners) do
      if s.active then
        local scanOffsetY = (s.y - SCALE_Y * 1080) / (SCALE_Y * 2160)
        targetOffsetY = scanOffsetY * 50
        break
      end
    end
  end

  self:_applyOffsets(dt, targetOffsetX, targetOffsetY)
end

local function lineXAtY(line, y)
  local t = (y - line.y1) / (line.y2 - line.y1)
  t = math.max(0, math.min(1, t))
  return line.x1 + t * (line.x2 - line.x1)
end

function Camera:drawScannerLines(scanners)
  local lensX, lensY = self:getLensPosition()
  for _, s in pairs(scanners) do
    if s.active then
      local x1 = s.boundSide == "x1" and lineXAtY(s.boundLine, s.y) or s.x1
      local x2 = s.boundSide == "x2" and lineXAtY(s.boundLine, s.y) or s.x2
      love.graphics.setColor(s.color[1], s.color[2], s.color[3], 0.4)
      love.graphics.setLineWidth(1.5)
      love.graphics.line(lensX, lensY, x1, s.y)
      love.graphics.line(lensX, lensY, x2, s.y)
      for _ = 1, 4 do
        local rx = x1 + math.random() * (x2 - x1)
        love.graphics.setColor(s.color[1], s.color[2], s.color[3], math.random() * 0.25)
        love.graphics.line(lensX, lensY, rx, s.y)
      end
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setLineWidth(1)
end

function Camera:draw()
  local windowScaleX = SCALE_X / 2
  local windowScaleY = SCALE_Y / 2
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(
    self.parts.base.asset,
    self.x,
    self.y * windowScaleY,
    -- self.y,
    0,
    self.scale * windowScaleX,
    self.scale * windowScaleY,
    self.offsetX,
    self.offsetY
  )
  love.graphics.draw(
    self.parts.lens.asset,
    self.x +
      self.parts.lens.offsetX * self.scale * windowScaleX +
      self.parts.lens.originalPosition.x * self.scale * windowScaleX,
    self.y * windowScaleY
      + self.parts.lens.offsetY * self.scale * windowScaleY
      + self.parts.lens.originalPosition.y * self.scale * windowScaleY,
    -- self.y,
    0,
    self.scale * windowScaleX,
    self.scale * windowScaleY,
    self.offsetX,
    self.offsetY
  )
  love.graphics.setColor(self.parts.ring.color)
  love.graphics.draw(
    self.parts.ring.asset,
    self.x
      + self.parts.ring.offsetX * self.scale * windowScaleX
      + self.parts.ring.originalPosition.x * self.scale * windowScaleX,
    self.y * windowScaleY
      + self.parts.ring.offsetY * self.scale * windowScaleY
      + self.parts.ring.originalPosition.y * self.scale * windowScaleY,
    -- self.y,
    0,
    self.scale * windowScaleX,
    self.scale * windowScaleY,
    self.offsetX,
    self.offsetY
  )
  love.graphics.setColor(1, 1, 1, 1)
  local glow = Glow.get()
  local luminescence = self.state == "idle" and 0.5 or 1.0

    glow:request("camera-ring", {
      kind  = "image",
      image = self.parts.ring.asset,
      x = self.x
      + self.parts.ring.offsetX * self.scale * windowScaleX
        + self.parts.ring.originalPosition.x * self.scale * windowScaleX,
      y = self.y * windowScaleY
      + self.parts.ring.offsetY * self.scale * windowScaleY
        + self.parts.ring.originalPosition.y * self.scale * windowScaleY,
      sx = (self.scale) * windowScaleX,
      sy = (self.scale) * windowScaleY,
      ox = self.offsetX,
      oy = self.offsetY,
      color = self.parts.ring.color,
      luminescence = luminescence,
      alpha = 0.8,
    })
end

return Camera
