local animation = require("lib.animation")

local stiffness = 80
local damping = 10
local influence = 0.002

local Card = {}
Card.__index = Card

function Card.new(x, y, defaultAsset, chompedAsset)
  local self = setmetatable({}, Card)
  self.assets = { default = defaultAsset, chomped = chompedAsset }
  self.asset = defaultAsset
  self.hover = { is = false, can = true }
  self.drag = { is = false, can = true, offsetX = 0, offsetY = 0 }
  self.stationary = true
  self.w = 180
  self.h = 270
  self.horizontalVelocity = 0
  self._startX = x
  self._startY = y
  self.current = { x = x, y = y, r = 0, rVel = 0, scale = 0.95 }
  self.target  = { x = x, y = y, r = 0, scale = 0.95 }
  return self
end

function Card:update()
  local dt = realDt
  if not self.stationary then
    self.current.x = animation.expDecay(self.current.x, self.target.x, 10, dt)
    self.current.y = animation.expDecay(self.current.y, self.target.y, 10, dt)
    self.horizontalVelocity = (self.current.x - self.target.x) / dt
  end

  local rForce = -self.current.r * stiffness - self.current.rVel * damping + self.horizontalVelocity * -influence
  self.current.rVel = self.current.rVel + rForce * dt
  self.current.r    = self.current.r + self.current.rVel * dt
  self.current.scale = animation.expDecay(self.current.scale, self.target.scale, 18, dt)

  if math.abs(self.current.x - self.target.x) < 0.1 and math.abs(self.current.y - self.target.y) < 0.1 then
    self.current.x = self.target.x
    self.current.y = self.target.y
    self.stationary = true
  else
    self.stationary = false
  end
end

function Card:draw()
  love.graphics.push()
  love.graphics.translate(self.current.x + self.w / 2, self.current.y + self.h / 2)
  love.graphics.rotate(self.current.r)
  love.graphics.scale(self.current.scale, self.current.scale)
  love.graphics.draw(self.asset, -self.w / 2, -self.h / 2)
  love.graphics.pop()
end

function Card:containsPoint(x, y)
  return x >= self.current.x and x <= self.current.x + self.w
     and y >= self.current.y and y <= self.current.y + self.h
end

return Card
