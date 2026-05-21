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
  self.parts = nil
  self.partAssets = nil
  self._excluded = false
  self.shader = nil
  self.tiltShader = nil
  self.drawShadow = true
  self.mouseX = 0
  self.mouseY = 0
  self._shake = { trauma = 0, elapsed = 0, intensity = 0, duration = 0 }
  self.dissolveAmount = 0
  self.dissolveTime = 0
  self.dissolving = false
  self.reverseDissolving = false
  return self
end

function Card:setParts(config)
  self.parts = {}
  for _, p in ipairs(config) do
    local dx = p.dx or 0
    local dy = p.dy or 0
    local dr = p.dr or 0
    table.insert(self.parts, {
      id      = p.id,
      asset   = p.asset,
      yOffset = p.yOffset or 0,
      xOffset = p.xOffset or 0,
      origin  = p.origin or { x = 0, y = 0 },
      current = { dx = dx, dy = dy, dr = dr },
      target  = { dx = p.targetDx or dx, dy = p.targetDy or dy, dr = p.targetDr or dr },
    })
  end
end

function Card:clearParts()
  self.parts = nil
end

function Card:snapParts()
  if not self.parts then return end
  for _, part in ipairs(self.parts) do
    part.current.dx = 0  part.target.dx = 0
    part.current.dy = 0  part.target.dy = 0
    part.current.dr = 0  part.target.dr = 0
  end
end

function Card:convergeParts()
  if not self.parts then return end
  for _, part in ipairs(self.parts) do
    part.target.dx = 0
    part.target.dy = 0
    part.target.dr = 0
  end
end

function Card:shake(intensity, duration)
  self._shake.intensity = intensity or 8
  self._shake.duration  = duration  or 0.3
  self._shake.trauma    = 1
  self._shake.elapsed   = 0
end

function Card:startDissolve()
  self.reverseDissolving = false
  self.dissolving = true
end

function Card:startReverseDissolve()
  self.dissolving = false
  self.dissolveAmount = 1.0
  self.dissolveTime = 0
  self.reverseDissolving = true
end

function Card:resetDissolve()
  self.dissolving = false
  self.reverseDissolving = false
  self.dissolveAmount = 0
  self.dissolveTime = 0
end

function Card:isDissolving()
  return self.dissolving or self.reverseDissolving
end

function Card:partsSettled()
  if not self.parts then return true end
  for _, part in ipairs(self.parts) do
    if math.abs(part.current.dx) > 0.5
    or math.abs(part.current.dy) > 0.5
    or math.abs(part.current.dr) > 0.01 then
      return false
    end
  end
  return true
end

function Card:removePart(id)
  if not self.parts then return end
  for i, part in ipairs(self.parts) do
    if part.id == id then
      table.remove(self.parts, i)
      return
    end
  end
end

function Card:updatePartById(id, targetDx, targetDy, targetDr)
  if not self.parts then return end
  for _, part in ipairs(self.parts) do
    if part.id == id then
      part.target.dx = targetDx or part.target.dx
      part.target.dy = targetDy or part.target.dy
      part.target.dr = targetDr or part.target.dr
      return
    end
  end
end

function Card:update()
  local dt = realDt
  if not self.stationary then
    self.current.x = animation.expDecay(self.current.x, self.target.x, 12, dt)
    self.current.y = animation.expDecay(self.current.y, self.target.y, 12, dt)
    self.horizontalVelocity = (self.current.x - self.target.x) / dt
  end

  local rForce = -self.current.r * stiffness - self.current.rVel * damping + self.horizontalVelocity * -influence
  self.current.rVel = self.current.rVel + rForce * dt
  self.current.r    = self.current.r + self.current.rVel * dt
  -- let's cap r at 90 and -90 to avoid weird flipping issues
  if self.current.r > math.pi / 2 then
    self.current.r = math.pi / 2
    -- self.current.rVel = 0
  elseif self.current.r < -math.pi / 2 then
    self.current.r = -math.pi / 2
    -- self.current.rVel = 0
  end
  self.current.scale = animation.expDecay(self.current.scale, self.target.scale, 18, dt)

  if math.abs(self.current.x - self.target.x) < 0.1 and math.abs(self.current.y - self.target.y) < 0.1 then
    self.current.x = self.target.x
    self.current.y = self.target.y
    self.stationary = true
  else
    self.stationary = false
  end

  if self.parts then
    for _, part in ipairs(self.parts) do
      part.current.dx = animation.expDecay(part.current.dx, part.target.dx, 12, dt)
      part.current.dy = animation.expDecay(part.current.dy, part.target.dy, 12, dt)
      part.current.dr = animation.expDecay(part.current.dr, part.target.dr, 12, dt)
    end
  end

  local sk = self._shake
  if sk.trauma > 0 then
    sk.elapsed = sk.elapsed + dt
    sk.trauma  = math.max(0, 1 - sk.elapsed / sk.duration)
  end

  if self.dissolving then
    self.dissolveTime   = self.dissolveTime + dt
    self.dissolveAmount = math.min(self.dissolveAmount + dt * 0.9, 1)
  end

  if self.reverseDissolving then
    self.dissolveTime   = self.dissolveTime + dt
    self.dissolveAmount = math.max(self.dissolveAmount - dt * 0.9, 0)
    if self.dissolveAmount <= 0 then
      self.reverseDissolving = false
    end
  end
end

function Card:_applyDissolveUniforms(asset)
  local iw, ih = asset:getDimensions()
  self.shader:send("dissolve",        self.dissolveAmount)
  self.shader:send("time",            self.dissolveTime)
  self.shader:send("texture_details", { 0, 0, iw, ih })
  self.shader:send("image_details",   { iw, ih })
  self.shader:send("shadow",          false)
  self.shader:send("burn_colour_1",   { 1.0, 0.5, 0.0, 1.0 })
  self.shader:send("burn_colour_2",   { 0.5, 0.5, 1.0, 0.5 })
  -- self.shader:send("burn_colour_2",   { 0.6, 0.1, 0.0, 1.0 })
  self.shader:send("mouse_screen_pos",{ 0, 0 })
  self.shader:send("hovering",        0.0)
  self.shader:send("screen_scale",    1.0)
end

function Card:_applyTiltUniforms(includeMouse)
  if includeMouse then
    self.tiltShader:send("mouse_screen_pos", { self.mouseX, self.mouseY })
  else
    self.tiltShader:send("mouse_screen_pos", { self.current.x + self.w / 2, self.current.y + self.h / 2 })
  end
  self.tiltShader:send("hovering",         1.0)
  self.tiltShader:send("screen_scale",     self.w * 0.75)
  self.tiltShader:send("card_angle",       self.current.r)
  self.tiltShader:send("card_center_x",    self.current.x + self.w / 2)
  self.tiltShader:send("card_center_y", self.current.y + self.h / 2)
end

function Card:draw()
  local useShader = self.shader ~= nil and self.dissolveAmount > 0.001
  -- local useTilt = self.tiltShader ~= nil and self.hover.is
  local useTilt = self.tiltShader ~= nil
  -- local useTilt = self.tiltShader ~= nil and (self.hover.is or self.drag.is)

  local skox, skoy = 0, 0
  local sk = self._shake
  if sk.trauma > 0 then
    skox = sk.intensity * sk.trauma * math.sin(sk.elapsed * 50)
    skoy = sk.intensity * sk.trauma * math.sin(sk.elapsed * 50 * 1.6180339887)
  end

  if self.drawShadow then
    local shadowAsset = self.asset
    if self.parts then
      for _, p in ipairs(self.parts) do
        if p.id == "base" then shadowAsset = p.asset; break end
      end
    end
    local winCX  = love.graphics.getWidth() / 2
    local winCY  = love.graphics.getHeight() / 2
    local cardCX = self.current.x + self.w / 2
    local cardCY = self.current.y + self.h / 2
    local boost  = (self.hover.is or self.drag.is) and 2.0 or 1.0
    local shadowDX = (cardCX - winCX) * 0.02 * boost
    -- local shadowDY = -10 * boost
    local shadowDY = ((cardCY - winCY) * 0.02 + 10) * boost
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.push()
    love.graphics.translate(cardCX - shadowDX + skox, cardCY + shadowDY + skoy)
    -- love.graphics.translate(cardCX + shadowDX, cardCY + shadowDY)
    love.graphics.rotate(self.current.r)
    -- if we have an angle let's make the shadow a bit thinner
    -- but only reduce it by up to 20%
    local scaleX = self.current.scale * math.max(0.9, math.cos(self.current.r))
    love.graphics.scale(scaleX, self.current.scale)
    love.graphics.draw(shadowAsset, -self.w / 2, -self.h / 2)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
  end

  if useTilt then
    self:_applyTiltUniforms(self.hover.is or self.drag.is)
    love.graphics.setShader(self.tiltShader)
  end

  love.graphics.push()
  love.graphics.translate(self.current.x + self.w / 2 + skox, self.current.y + self.h / 2 + skoy)
  love.graphics.rotate(self.current.r)
  love.graphics.scale(self.current.scale, self.current.scale)
  if self.parts then
    for _, part in ipairs(self.parts) do
      if useShader and part.id == "base" then
        self:_applyDissolveUniforms(part.asset)
        love.graphics.setShader(self.shader)
      end
      local px = -self.w / 2 + part.xOffset + part.current.dx
      local py = -self.h / 2 + part.yOffset + part.current.dy
      local ox = part.origin.x
      local oy = part.origin.y
      love.graphics.draw(part.asset, px + ox, py + oy, part.current.dr, 1, 1, ox, oy)
    end
  else
    if useShader then
      self:_applyDissolveUniforms(self.asset)
      love.graphics.setShader(self.shader)
    end
    love.graphics.draw(self.asset, -self.w / 2, -self.h / 2)
  end
  love.graphics.pop()

  if useTilt or useShader then
    love.graphics.setShader()
  end
end

local BUFFER = 7
function Card:containsPoint(x, y)
  return x >= self.current.x - BUFFER * self.current.scale and x <= self.current.x + self.w + BUFFER * self.current.scale
     and y >= self.current.y - BUFFER * self.current.scale and y <= self.current.y + self.h + BUFFER * self.current.scale
end

return Card
