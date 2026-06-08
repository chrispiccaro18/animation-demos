local animation = require("lib.animation")

local stiffness = 80
local damping = 10
local influence = 0.002

local NewCard = {}
NewCard.__index = NewCard

-- local BUFFER = 0
local BUFFER = 20
function NewCard:containsPoint(x, y)
  local windowScaleX = love.graphics.getWidth() / 3840
  local windowScaleY = love.graphics.getHeight() / 2160
  local hw = self.offsetX * self.current.scale * windowScaleX + BUFFER * self.current.scale * windowScaleX
  local hh = self.offsetY * self.current.scale * windowScaleY + BUFFER * self.current.scale * windowScaleY
  return x >= self.current.x - hw
    and x <= self.current.x + hw
    and y >= self.current.y - hh
    and y <= self.current.y + hh
end

function NewCard.new(x, y, baseAsset)
  local self = setmetatable({}, NewCard)
  self.assets = { default = baseAsset }
  self.asset = baseAsset
  self.hover = { is = false, can = true }
  self.drag = { is = false, can = true, offsetX = 0, offsetY = 0 }
  self.stationary = true
  self.horizontalVelocity = 0
  self._startX = x
  self._startY = y
  self.current = { x = x, y = y, r = 0, rVel = 0, scale = 0.5 }
  self.target  = { x = x, y = y, r = 0, scale = 0.5 }
  self.w = baseAsset:getWidth() * self.current.scale
  self.h = baseAsset:getHeight() * self.current.scale
  self.offsetX = baseAsset:getWidth() / 2
  self.offsetY = baseAsset:getHeight() / 2
  self.parts = {}
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
  self.scales = {
    idle = 0.5,
    hover = 0.65,
    drag = 0.7
  }
  return self
end

function NewCard:setParts(config)
  -- self.parts = config.parts
  for _, p in ipairs(config) do
    local dx = p.dx or 0
    local dy = p.dy or 0
    local dr = p.dr or 0
    local initialScale = p.scale or 1
    local initialAlpha = (p.hidden and 0 or 1)
    table.insert(self.parts, {
      id          = p.id,
      asset       = p.asset,
      items       = p.items,
      slotCenters = p.slotCenters,
      origin      = p.origin or { x = 0, y = 0 },
      initialScale = initialScale,
      current = {
        dx = dx,
        dy = dy,
        dr = dr,
        scale = initialScale,
        alpha = initialAlpha
      },
      target  = {
        dx = p.targetDx or dx,
        dy = p.targetDy or dy,
        dr = p.targetDr or dr,
        scale = initialScale,
        alpha = initialAlpha
      },
      hidden  = p.hidden or false,
    })
  end
end

function NewCard:getPartById(id)
  for _, part in ipairs(self.parts) do
    if part.id == id then return part end
  end
  return nil
end

function NewCard:getPartPositionById(id)
  local part = self:getPartById(id)
  if part then
    return {
      x = self.current.x + part.origin.x + part.current.dx,
      y = self.current.y + part.origin.y + part.current.dy
    }
  end
  return {x = nil, y = nil}
end

function NewCard:returnPartsToOrigin()
  for _, part in ipairs(self.parts) do
    part.target.dx = 0
    part.target.dy = 0
    part.target.dr = 0
    part.target.scale = part.initialScale
  end
end

function NewCard:revealAllParts()
  for _, part in ipairs(self.parts) do
    if part.id == "bottomEnergy" then
      part.hidden = true
      part.current.alpha = 0
      part.target.alpha = 0
    elseif part.current.alpha < 1 then
      part.hidden = false
      part.target.alpha = 1
    else
      part.hidden = false
      part.current.alpha = 1
      part.target.alpha = 1
    end
  end
end

function NewCard:returnToIdle()
  self:returnPartsToOrigin()
  self:revealAllParts()
end

function NewCard:fadeInPart(id)
  local part = self:getPartById(id)
  if part then
    part.hidden = false
    part.target.alpha = 1
  end
end

function NewCard:fadeOutPart(id)
  local part = self:getPartById(id)
  if part then
    part.target.alpha = 0
  end
end

function NewCard:startDissolve()
  self.reverseDissolving = false
  self.dissolving = true
end

function NewCard:startReverseDissolve()
  self.dissolving = false
  self.dissolveAmount = 1.0
  self.dissolveTime = 0
  self.reverseDissolving = true
end

function NewCard:resetDissolve()
  self.dissolving = false
  self.reverseDissolving = false
  self.dissolveAmount = 0
  self.dissolveTime = 0
end

function NewCard:isDissolving()
  return self.dissolving or self.reverseDissolving
end

function NewCard:moveToDiscard()
  local linePart = self:getPartById("line")
  local playLinePart = self:getPartById("playLine")
  local discardLinePart = self:getPartById("discardLine")
  local topEnergyHolesPart = self:getPartById("topEnergyHoles")
  local bottomEnergyPart = self:getPartById("bottomEnergy")
  local playEffectPart = self:getPartById("playEffect")
  local discardEffectPart = self:getPartById("discardEffect")
  local dtorEffectPart = self:getPartById("dtorEffect")
  if linePart then
    linePart.target.dy = -250
    linePart.target.scale = 1.1
  end
  if playLinePart then
    -- playLinePart.hidden = true
    -- playLinePart.current.alpha = 0
    -- playLinePart.target.alpha = 0
    self:fadeOutPart("playLine")
    playLinePart.target.dy = -250
  end
  if playEffectPart then
    -- playEffectPart.hidden = true
    -- playEffectPart.current.alpha = 0
    -- playEffectPart.target.alpha = 0
    self:fadeOutPart("playEffect")
    playEffectPart.target.dy = -200
  end
  if discardLinePart then
    discardLinePart.hidden = false
    discardLinePart.current.alpha = 1
    discardLinePart.target.alpha = 1
    discardLinePart.target.dy = -250
    discardLinePart.target.scale = 1.25
  end
  if discardEffectPart then
    discardEffectPart.hidden = false
    discardEffectPart.current.alpha = 1
    discardEffectPart.target.alpha = 1
    discardEffectPart.target.dy = -250
  end
  if dtorEffectPart then
    dtorEffectPart.hidden = false
    dtorEffectPart.current.alpha = 1
    dtorEffectPart.target.alpha = 1
    dtorEffectPart.target.dy = -250
  end
  if topEnergyHolesPart then
    -- topEnergyHolesPart.hidden = true
    -- topEnergyHolesPart.current.alpha = 0
    -- topEnergyHolesPart.target.alpha = 0
      self:fadeOutPart("topEnergyHoles")
    -- topEnergyHolesPart.target.dy = -250
  end
  if bottomEnergyPart then
    -- bottomEnergyPart.hidden = false
    -- bottomEnergyPart.current.alpha = 1
    -- bottomEnergyPart.target.alpha = 1
    self:fadeInPart("bottomEnergy")
    -- bottomEnergyPart.target.dy = -250
  end
end

function NewCard:moveToPlay()
  local linePart = self:getPartById("line")
  local playLinePart = self:getPartById("playLine")
  local discardLinePart = self:getPartById("discardLine")
  local topEnergyHolesPart = self:getPartById("topEnergyHoles")
  local bottomEnergyPart = self:getPartById("bottomEnergy")
  local playEffectPart = self:getPartById("playEffect")
  local discardEffectPart = self:getPartById("discardEffect")
  local dtorEffectPart = self:getPartById("dtorEffect")
  if linePart then
    linePart.target.dy = 150
    linePart.target.scale = 1.1
  end
  if playLinePart then
    playLinePart.hidden = false
    playLinePart.current.alpha = 1
    playLinePart.target.alpha = 1
    playLinePart.target.dy = 150
    playLinePart.target.scale = 1.25
  end
  if playEffectPart then
    playEffectPart.hidden = false
    playEffectPart.current.alpha = 1
    playEffectPart.target.alpha = 1
    playEffectPart.target.dy = 150
  end
  if discardLinePart then
    -- discardLinePart.hidden = true
    -- discardLinePart.current.alpha = 0
    -- discardLinePart.target.alpha = 0
    self:fadeOutPart("discardLine")

    discardLinePart.target.dy = 150
  end
  if discardEffectPart then
    -- discardEffectPart.hidden = true
    -- discardEffectPart.current.alpha = 0
    -- discardEffectPart.target.alpha = 0
      self:fadeOutPart("discardEffect")
    discardEffectPart.target.dy = 150
  end
  if dtorEffectPart then
    dtorEffectPart.hidden = true
    dtorEffectPart.current.alpha = 0
    dtorEffectPart.target.alpha = 0
    dtorEffectPart.target.dy = 150
  end
  if topEnergyHolesPart then
    topEnergyHolesPart.hidden = false
    topEnergyHolesPart.current.alpha = 1
    topEnergyHolesPart.target.alpha = 1
    -- topEnergyHolesPart.target.dy = 150
  end
  if bottomEnergyPart then
    bottomEnergyPart.hidden = true
    bottomEnergyPart.current.alpha = 0
    bottomEnergyPart.target.alpha = 0
    -- bottomEnergyPart.target.dy = 150
  end
end

function NewCard:update()

  if math.abs(self.current.x - self.target.x) < 0.1 and math.abs(self.current.y - self.target.y) < 0.1 then
    self.current.x = self.target.x
    self.current.y = self.target.y
    self.stationary = true
  else
    self.stationary = false
  end

  if self.parts then
    for _, part in ipairs(self.parts) do
      part.current.dx    = animation.expDecay(part.current.dx,    part.target.dx,    12, realDt)
      part.current.dy    = animation.expDecay(part.current.dy,    part.target.dy,    12, realDt)
      part.current.dr    = animation.expDecay(part.current.dr,    part.target.dr,    12, realDt)
      part.current.scale = animation.expDecay(part.current.scale, part.target.scale, 12, realDt)
      part.current.alpha = animation.expDecay(part.current.alpha, part.target.alpha, 12, realDt)
    end
  end

  if not self.stationary then
    self.current.x = animation.expDecay(self.current.x, self.target.x, 12, realDt)
    self.current.y = animation.expDecay(self.current.y, self.target.y, 12, realDt)
    self.horizontalVelocity = (self.current.x - self.target.x) / realDt
  end

  local rForce = -self.current.r * stiffness - self.current.rVel * damping + self.horizontalVelocity * -influence
  self.current.rVel = self.current.rVel + rForce * realDt
  self.current.r    = self.current.r + self.current.rVel * realDt
  -- let's cap r at 90 and -90 to avoid weird flipping issues
  if self.current.r > math.pi / 2 then
    self.current.r = math.pi / 2
    -- self.current.rVel = 0
  elseif self.current.r < -math.pi / 2 then
    self.current.r = -math.pi / 2
    -- self.current.rVel = 0
  end

  -- drag and hover logic
  -- can only be hovered if not dragging, and can only be dragged if hovering or already dragging
  -- if self.drag.is and love.mouse.isDown(1) then
  --   self.target.x = mouseX + self.drag.offsetX
  --   self.target.y = mouseY + self.drag.offsetY
  -- elseif self.drag.is and not love.mouse.isDown(1) then
  --   self.drag.is = false
  --   self.drag.can = true
  --   self.hover.can = true
  -- elseif self.hover.is and love.mouse.isDown(1) then
  --   self.drag.is = true
  --   self.drag.can = false
  --   self.hover.is = false
  --   self.hover.can = false
  --   self.target.scale = 1.0
  --   -- calculate the offsetX and offsetY based on where the mouse is relative to the card's center
  --   self.drag.offsetX = self.current.x - mouseX
  --   self.drag.offsetY = self.current.y - mouseY
  -- elseif self.hover.can and self:containsPoint(mouseX, mouseY) then
  --   self.hover.is = true
  --   self.target.scale = 0.85
  -- else
  --   self.hover.is = false
  --   self.target.scale = 0.5
  -- end

  self.current.scale = animation.expDecay(self.current.scale, self.target.scale, 18, realDt)

  -- if areas.mouseInPlay(mouseX, mouseY) and self.drag.is then
  --   areas.play.color = { 0.5, 0.5, 1, 1 }
  --   -- self:moveToPlay()
  -- elseif self.drag.is and areas.cardInPlay(self) then
  --   -- areas.play.color = { 0.5, 0.5, 0.5, 1 }
  --   areas.play.color = {1, 1, 1, 1}
  -- elseif areas.mouseInPlay(mouseX, mouseY) then
  --   -- areas.play.color = { 0.5, 0.5, 0.5, 1 }
  --   areas.play.color = {0, 1, 0, 1}
  -- else
  --   areas.play.color = { 0.5, 0.5, 0.5, 1 }
  -- end

  -- if areas.mouseInDiscard(mouseX, mouseY) and self.drag.is then
  --   areas.discard.color = { 0.5, 0.5, 1, 1 }
  --   -- self:moveToDiscard()
  -- elseif self.drag.is and areas.cardInDiscard(self) then
  --   -- areas.discard.color = { 0.5, 0.5, 0.5, 1 }
  --   areas.discard.color = {1, 1, 1, 1}
  -- elseif areas.mouseInDiscard(mouseX, mouseY) then
  --   areas.discard.color = { 1, 0, 0.5, 1 }
  --   -- areas.discard.color = {0.5, 1, 0.5, 1}
  -- else
  --   areas.discard.color = { 0.5, 0.5, 0.5, 1 }
  -- end

  local sk = self._shake
  if sk.trauma > 0 then
    sk.elapsed = sk.elapsed + realDt
    sk.trauma  = math.max(0, 1 - sk.elapsed / sk.duration)
  end

  if self.dissolving then
    self.dissolveTime   = self.dissolveTime + realDt
    self.dissolveAmount = math.min(self.dissolveAmount + realDt * 0.9, 1)
  end

  if self.reverseDissolving then
    self.dissolveTime   = self.dissolveTime + realDt
    self.dissolveAmount = math.max(self.dissolveAmount - realDt * 0.9, 0)
    if self.dissolveAmount <= 0 then
      self.reverseDissolving = false
    end
  end
end

function NewCard:isDissolved()
  return self.dissolveAmount >= 1
end

function NewCard:_applyDissolveUniforms(asset)
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

function NewCard:_applyTiltUniforms(includeMouse)
  local windowScaleX = love.graphics.getWidth() / 3840
  local screenCX = self.current.x
  local screenCY = self.current.y
  local screenScale = self.offsetX * self.current.scale * windowScaleX

  if includeMouse then
    self.tiltShader:send("mouse_screen_pos", { self.mouseX, self.mouseY })
  else
    self.tiltShader:send("mouse_screen_pos", { screenCX, screenCY })
  end
  self.tiltShader:send("hovering",      1.0)
  self.tiltShader:send("screen_scale",  screenScale)
  self.tiltShader:send("card_angle",    self.current.r)
  self.tiltShader:send("card_center_x", screenCX)
  self.tiltShader:send("card_center_y", screenCY)
end

function NewCard:draw()
  local windowScaleX = love.graphics.getWidth() / 3840
  local windowScaleY = love.graphics.getHeight() / 2160

  local useShader = self.shader ~= nil and self.dissolveAmount > 0.001
  local useTilt = self.tiltShader ~= nil

  if self.drawShadow then
    local boost = 1.0
    if self.hover.is then boost = 2.0 end
    if self.drag.is then boost = 2.0 end

    local winCX  = love.graphics.getWidth() / 2
    local winCY  = love.graphics.getHeight() / 2
    local cardCX = self.current.x
    local cardCY = self.current.y
    local dx = 25 * windowScaleX * boost
    local dy = 40 * windowScaleY * boost
    -- local dx = (cardCX - winCX) * 0.05 * boost
    -- local dy = (cardCY - winCY) * 0.05 * boost
    love.graphics.push()
    love.graphics.translate(dx, dy)
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.draw(
      self.asset,
      self.current.x,
      self.current.y,
      self.current.r,
      self.current.scale * windowScaleX * (boost * 0.5),
      self.current.scale * windowScaleY * (boost * 0.5),
      self.offsetX,
      self.offsetY
    )
    love.graphics.pop()
  end

  if useTilt then
    self:_applyTiltUniforms(self.hover.is or self.drag.is)
    love.graphics.setShader(self.tiltShader)
  end

  if useShader then
    self:_applyDissolveUniforms(self.asset)
    love.graphics.setShader(self.shader)
  end

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(
    self.asset,
    self.current.x,
    self.current.y,
    self.current.r,
    self.current.scale * windowScaleX,
    self.current.scale * windowScaleY,
    self.offsetX,
    self.offsetY
  )

  if useShader then
    love.graphics.setShader(self.tiltShader)
  end

  if self.parts then
    love.graphics.push()
    love.graphics.translate(self.current.x, self.current.y)
    love.graphics.rotate(self.current.r)
    love.graphics.scale(self.current.scale * windowScaleX, self.current.scale * windowScaleY)

    for _, part in ipairs(self.parts) do
      local partAlpha = part.hidden and 0 or part.current.alpha
      love.graphics.setColor(1, 1, 1, partAlpha)

      if part.items then
        for _, item in ipairs(part.items) do
          if partAlpha > 0.001 and useShader then
            self:_applyDissolveUniforms(item.asset)
            love.graphics.setShader(self.shader)
          end
          local iw, ih = item.asset:getDimensions()
          local s = (item.scale or 1) * part.current.scale
          love.graphics.draw(
            item.asset,
            part.origin.x - self.offsetX + item.offsetX + iw / 2 + part.current.dx,
            part.origin.y - self.offsetY + item.offsetY + ih / 2 + part.current.dy,
            part.current.dr,
            s, s,
            iw / 2,
            ih / 2
          )
          if useShader and partAlpha > 0.001 then
            love.graphics.setShader(self.tiltShader)
          end
        end
      else
        if partAlpha > 0.001 and useShader then
          self:_applyDissolveUniforms(part.asset)
          love.graphics.setShader(self.shader)
        end
        local pw = part.asset:getWidth()
        local ph = part.asset:getHeight()
        love.graphics.draw(
          part.asset,
          part.origin.x - self.offsetX + pw / 2 + part.current.dx,
          part.origin.y - self.offsetY + ph / 2 + part.current.dy,
          part.current.dr,
          part.current.scale, part.current.scale,
          pw / 2,
          ph / 2
        )
        if useShader and partAlpha > 0.001 then
          love.graphics.setShader(self.tiltShader)
        end
      end
    end
    love.graphics.pop()
  end

  if useTilt or useShader then
    love.graphics.setShader()
  end
end

return NewCard


