local Color = require("lib.color")

local Camera = {}
Camera.__index = Camera

function Camera.load()
  local self = setmetatable({}, Camera)
  local baseAsset = love.graphics.newImage("assets/proto/camera-base.png", { mipmaps = true })
  local lensAsset = love.graphics.newImage("assets/proto/camera-lens.png", { mipmaps = true })
  local ringAsset = love.graphics.newImage("assets/proto/camera-ring.png", { mipmaps = true })
  self.x = love.graphics.getWidth() / 2
  self.y = baseAsset:getHeight() / 2 - 300
  -- self.y = 75
  self.scale = 1
  self.parts = {
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
      color = Color("#FFFFFF"),
      -- color = Color("#9C2B2B"),
      -- color = Color("#6ED59E"),
      -- color = Color("#D56E6E"),
    }
  }
  self.offsetX = baseAsset:getWidth() / 2
  self.offsetY = baseAsset:getHeight() / 2
  return self
end

function Camera:setColor(color)
  self.parts.ring.color = color
end

function Camera:getLensPosition()
  local windowScaleX = love.graphics.getWidth() / (3840 * 2)
  local windowScaleY = love.graphics.getHeight() / (2160 * 2)
  return self.x +
      self.parts.lens.offsetX * self.scale * windowScaleX +
      self.parts.lens.originalPosition.x * self.scale * windowScaleX
      - self.offsetX * windowScaleX / 2,
    self.y * windowScaleY
      + self.parts.lens.offsetY * self.scale * windowScaleY
      + self.parts.lens.originalPosition.y * self.scale * windowScaleY
      - self.offsetY * windowScaleY / 2
end

function Camera:update(dt, mouseX, mouseY)
  local distanceFromScreenCenterX = mouseX - love.graphics.getWidth() / 2
  local distanceFromScreenCenterY = mouseY - love.graphics.getHeight() / 2
  -- normalize for any screen size
  local offsetX = distanceFromScreenCenterX / love.graphics.getWidth()
  local offsetY = distanceFromScreenCenterY / love.graphics.getHeight()
  local targetOffsetX = offsetX * 200
  local targetOffsetY = offsetY * 50

  self.parts.lens.offsetX = self.parts.lens.offsetX +
    (targetOffsetX - self.parts.lens.offsetX) * 0.2
  self.parts.lens.offsetY = self.parts.lens.offsetY +
    (targetOffsetY - self.parts.lens.offsetY) * 0.15
  self.parts.ring.offsetX = self.parts.ring.offsetX +
    (targetOffsetX - self.parts.ring.offsetX) * 0.2
  self.parts.ring.offsetY = self.parts.ring.offsetY +
    (targetOffsetY - self.parts.ring.offsetY) * 0.15
end

function Camera:draw()
  local windowScaleX = love.graphics.getWidth() / (3840 * 2)
  local windowScaleY = love.graphics.getHeight() / (2160 * 2)
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
end

return Camera
