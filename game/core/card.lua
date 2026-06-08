local animation = require("lib.animation")

local stiffness = 80
local damping   = 10
local influence = 0.002
local BUFFER    = 20

local _assets  = {}
local _shaders = {}

local ZONES = {
  topEnergyHoles = { cx = 379, cy = 96  },
  playEffect     = { cx = 382, cy = 288 },
  discardEffect  = { cx = 382, cy = 639 },
  dtorEffect     = { cx = 378, cy = 847 },
  bottomEnergy   = { cx = 378, cy = 858 },
}

local EFFECT_ZONES = {
  { dataKey = "topEnergy",    id = "topEnergyHoles", holeKey = "ramHole"                                       },
  { dataKey = "play",         id = "playEffect",     holeKey = "tokenHole", hasTypedTokens = true              },
  { dataKey = "discard",      id = "discardEffect",  holeKey = "tokenHole", hasTypedTokens = true              },
  { dataKey = "dtor",         id = "dtorEffect",     holeKey = "tokenHole", hasTypedTokens = true              },
  { dataKey = "bottomEnergy", id = "bottomEnergy",   holeKey = "ramHole",   tokenKey = "ramChip", hidden = true },
}

local ENERGY_GAP = 7
local EFFECT_GAP = 8

local STATE_CONFIG = {
  idle = {
    line           = { visible = true,  dy = 0 },
    playLine       = { visible = true,  dy = 0 },
    discardLine    = { visible = true,  dy = 0 },
    topEnergyHoles = { visible = true,  dy = 0 },
    playEffect     = { visible = true,  dy = 0 },
    discardEffect  = { visible = true,  dy = 0 },
    dtorEffect     = { visible = true,  dy = 0 },
    bottomEnergy   = { visible = false, dy = 0 },
  },
  play = {
    line           = { visible = true,  dy = 150,  scale = 1.1  },
    playLine       = { visible = true,  dy = 150,  scale = 1.25 },
    discardLine    = { visible = false, dy = 150  },
    topEnergyHoles = { visible = true,  dy = 0    },
    playEffect     = { visible = true,  dy = 150  },
    discardEffect  = { visible = false, dy = 150  },
    dtorEffect     = { visible = false, dy = 150  },
    bottomEnergy   = { visible = false, dy = 0    },
  },
  discard = {
    line           = { visible = true,  dy = -250, scale = 1.1  },
    playLine       = { visible = false, dy = -250 },
    discardLine    = { visible = true,  dy = -250, scale = 1.25 },
    topEnergyHoles = { visible = false, dy = 0    },
    playEffect     = { visible = false, dy = -200 },
    discardEffect  = { visible = true,  dy = -250 },
    dtorEffect     = { visible = true,  dy = -250 },
    bottomEnergy   = { visible = true,  dy = 0    },
  },
}

local function fitScale(asset, holeW, holeH)
  local w, h = asset:getDimensions()
  return math.min(holeW / w, holeH / h) * 0.85
end

local function buildParts(data)
  local parts = {}

  if _assets.line        then table.insert(parts, { id = "line",        asset = _assets.line,        origin = { x = 107, y = 456 } }) end
  if _assets.playLine    then table.insert(parts, { id = "playLine",    asset = _assets.playLine,    origin = { x = 107, y = 422 } }) end
  if _assets.discardLine then table.insert(parts, { id = "discardLine", asset = _assets.discardLine, origin = { x = 452, y = 469 } }) end

  for _, zone in ipairs(EFFECT_ZONES) do
    local holeAsset       = _assets[zone.holeKey or "tokenHole"]
    local holePW, holePH  = holeAsset:getDimensions()
    local gap             = (zone.holeKey == "ramHole") and ENERGY_GAP or EFFECT_GAP

    local effects = data[zone.dataKey]
    local n
    if type(effects) == "number" then
      n, effects = effects, nil
    else
      n = effects and #effects or 0
    end

    if n > 0 then
      local totalW       = n * holePW + (n - 1) * gap
      local groupOriginX = ZONES[zone.id].cx - totalW / 2
      local groupOriginY = ZONES[zone.id].cy - holePH / 2

      local items       = {}
      local slotCenters = {}
      for i = 1, n do
        local offsetX = (i - 1) * (holePW + gap)
        slotCenters[i] = { dx = offsetX + holePW / 2, dy = holePH / 2 }
        table.insert(items, { asset = holeAsset, offsetX = offsetX, offsetY = 0 })

        if zone.hasTypedTokens and effects then
          local tokenAsset = _assets.tokens and _assets.tokens[effects[i].type]
          if tokenAsset then
            local tw, th = tokenAsset:getDimensions()
            table.insert(items, {
              asset   = tokenAsset,
              offsetX = offsetX + (holePW - tw) / 2,
              offsetY = (holePH - th) / 2,
              scale   = fitScale(tokenAsset, holePW, holePH),
            })
          end
        elseif zone.tokenKey then
          local tokenAsset = _assets[zone.tokenKey]
          if tokenAsset then
            local tw, th = tokenAsset:getDimensions()
            table.insert(items, {
              asset   = tokenAsset,
              offsetX = offsetX + (holePW - tw) / 2,
              offsetY = (holePH - th) / 2,
              scale   = fitScale(tokenAsset, holePW, holePH),
            })
          end
        end
      end

      table.insert(parts, {
        id          = zone.id,
        origin      = { x = groupOriginX, y = groupOriginY },
        items       = items,
        slotCenters = slotCenters,
        hidden      = zone.hidden or false,
      })
    end
  end

  return parts
end

local Card = {}
Card.__index = Card

function Card.load(dissolveShader, tiltShader)
  _shaders.dissolve   = dissolveShader
  _shaders.tilt       = tiltShader
  _assets.base        = love.graphics.newImage("assets/proto/card-base.png",        { mipmaps = true })
  _assets.ramHole     = love.graphics.newImage("assets/proto/ram-hole.png",          { mipmaps = true })
  _assets.tokenHole   = love.graphics.newImage("assets/proto/token-hole.png",        { mipmaps = true })
  _assets.ramChip     = love.graphics.newImage("assets/proto/ram-chip.png",          { mipmaps = true })
  _assets.line        = love.graphics.newImage("assets/proto/card-line2.png",        { mipmaps = true })
  _assets.playLine    = love.graphics.newImage("assets/proto/card-play-line2.png",   { mipmaps = true })
  _assets.discardLine = love.graphics.newImage("assets/proto/card-discard-line.png", { mipmaps = true })
  _assets.tokens = {
    progress = love.graphics.newImage("assets/proto/progress-token.png", { mipmaps = true }),
    threat   = love.graphics.newImage("assets/proto/threat-token.png",   { mipmaps = true }),
    nullify  = love.graphics.newImage("assets/proto/nullify-token.png",  { mipmaps = true }),
    ram      = _assets.ramChip,
    dtor     = love.graphics.newImage("assets/proto/dtor-token.png",     { mipmaps = true }),
  }
end

function Card.new(x, y, data)
  local self      = setmetatable({}, Card)
  local baseAsset = _assets.base
  self.asset      = baseAsset
  self.hover      = { is = false, can = true }
  self.drag       = { is = false, can = true, offsetX = 0, offsetY = 0 }
  self.stationary = true
  self.horizontalVelocity = 0
  self._startX    = x
  self._startY    = y
  self.current    = { x = x, y = y, r = 0, rVel = 0, scale = 0.5 }
  self.target     = { x = x, y = y, r = 0, scale = 0.5 }
  self.w          = baseAsset:getWidth()  * self.current.scale
  self.h          = baseAsset:getHeight() * self.current.scale
  self.offsetX    = baseAsset:getWidth()  / 2
  self.offsetY    = baseAsset:getHeight() / 2
  self.parts      = {}
  self._excluded  = false
  self.shader     = _shaders.dissolve
  self.tiltShader = _shaders.tilt
  self.drawShadow = true
  self.mouseX     = 0
  self.mouseY     = 0
  self._shake     = { trauma = 0, elapsed = 0, intensity = 0, duration = 0 }
  self.dissolveAmount    = 0
  self.dissolveTime      = 0
  self.dissolving        = false
  self.reverseDissolving = false
  self.scales     = { idle = 0.5, hover = 0.65, drag = 0.7 }
  self.data       = data

  self:_setParts(buildParts(data))

  self._slotCounts = {}
  for _, zone in ipairs(EFFECT_ZONES) do
    local effects = data[zone.dataKey]
    self._slotCounts[zone.id] = type(effects) == "number" and effects
                               or (effects and #effects or 0)
  end

  return self
end

function Card:_setParts(config)
  for _, p in ipairs(config) do
    local dx           = p.dx or 0
    local dy           = p.dy or 0
    local dr           = p.dr or 0
    local initialScale = p.scale or 1
    local initialAlpha = p.hidden and 0 or 1
    table.insert(self.parts, {
      id           = p.id,
      asset        = p.asset,
      items        = p.items,
      slotCenters  = p.slotCenters,
      origin       = p.origin or { x = 0, y = 0 },
      initialScale = initialScale,
      current      = { dx = dx,               dy = dy,               dr = dr,               scale = initialScale, alpha = initialAlpha },
      target       = { dx = p.targetDx or dx, dy = p.targetDy or dy, dr = p.targetDr or dr, scale = initialScale, alpha = initialAlpha },
      hidden       = p.hidden or false,
    })
  end
end

function Card:getPartById(id)
  for _, part in ipairs(self.parts) do
    if part.id == id then return part end
  end
  return nil
end

function Card:getPartPositionById(id)
  local part = self:getPartById(id)
  if part then
    local wxs = love.graphics.getWidth()  / 3840
    local wys = love.graphics.getHeight() / 2160
    local cs  = self.current.scale
    local px  = part.origin.x - self.offsetX + part.current.dx
    local py  = part.origin.y - self.offsetY + part.current.dy
    local sx  = px * cs * wxs
    local sy  = py * cs * wys
    local r   = self.current.r
    return {
      x = self.current.x + sx * math.cos(r) - sy * math.sin(r),
      y = self.current.y + sx * math.sin(r) + sy * math.cos(r),
    }
  end
  return { x = nil, y = nil }
end

function Card:getSlotPosition(zone, index)
  local part = self:getPartById(zone)
  if part and part.slotCenters then
    local sc = part.slotCenters[index]
    if sc then
      local wxs = love.graphics.getWidth()  / 3840
      local wys = love.graphics.getHeight() / 2160
      local cs  = self.current.scale
      local px  = part.origin.x - self.offsetX + sc.dx + part.current.dx
      local py  = part.origin.y - self.offsetY + sc.dy + part.current.dy
      local sx  = px * cs * wxs
      local sy  = py * cs * wys
      local r   = self.current.r
      return {
        x = self.current.x + sx * math.cos(r) - sy * math.sin(r),
        y = self.current.y + sx * math.sin(r) + sy * math.cos(r),
      }
    end
  end
  return { x = nil, y = nil }
end

function Card:getTargetSlotPosition(zone, index)
  local part = self:getPartById(zone)
  if part and part.slotCenters then
    local sc = part.slotCenters[index]
    if sc then
      local wxs = love.graphics.getWidth()  / 3840
      local wys = love.graphics.getHeight() / 2160
      local cs  = self.target.scale
      local px  = part.origin.x - self.offsetX + sc.dx + part.target.dx
      local py  = part.origin.y - self.offsetY + sc.dy + part.target.dy
      return {
        x = self.target.x + px * cs * wxs,
        y = self.target.y + py * cs * wys,
      }
    end
  end
  return { x = nil, y = nil }
end

function Card:getZoneSlotPositions(zone)
  local n      = self._slotCounts[zone] or 0
  local result = {}
  for i = 1, n do result[i] = self:getSlotPosition(zone, i) end
  return result
end

function Card:fillZoneWithToken(zone, tokenKey)
  local part = self:getPartById(zone)
  if not part or not part.items then return end
  local zoneConfig
  for _, z in ipairs(EFFECT_ZONES) do
    if z.id == zone then zoneConfig = z; break end
  end
  if not zoneConfig then return end
  local holeAsset = _assets[zoneConfig.holeKey or "tokenHole"]
  local holePW, holePH = holeAsset:getDimensions()
  local gap = (zoneConfig.holeKey == "ramHole") and ENERGY_GAP or EFFECT_GAP
  local tokenAsset = _assets[tokenKey] or (_assets.tokens and _assets.tokens[tokenKey])
  if not tokenAsset then return end
  local tw, th = tokenAsset:getDimensions()
  local n = self._slotCounts[zone] or 0
  for i = 1, n do
    local offsetX = (i - 1) * (holePW + gap)
    table.insert(part.items, {
      asset   = tokenAsset,
      offsetX = offsetX + (holePW - tw) / 2,
      offsetY = (holePH - th) / 2,
      scale   = fitScale(tokenAsset, holePW, holePH),
    })
  end
end

function Card:fadeInPart(id)
  local part = self:getPartById(id)
  if part then
    part.hidden       = false
    part.target.alpha = 1
  end
end

function Card:fadeOutPart(id)
  local part = self:getPartById(id)
  if part then
    part.target.alpha = 0
  end
end

function Card:setZoneState(state)
  local cfg = STATE_CONFIG[state]
  for _, part in ipairs(self.parts) do
    local pc = cfg and cfg[part.id]
    if pc then
      part.target.dx    = 0
      part.target.dy    = pc.dy or 0
      part.target.dr    = 0
      part.target.scale = pc.scale or part.initialScale
      if pc.visible then
        part.hidden       = false
        part.target.alpha = 1
      else
        part.target.alpha = 0
      end
    else
      part.target.dx    = 0
      part.target.dy    = 0
      part.target.dr    = 0
      part.target.scale = part.initialScale
      part.hidden       = false
      part.target.alpha = 1
    end
  end
end

function Card:lock()
  self.hover.can  = false
  self.hover.is   = false
  self.drag.can   = false
  self.drag.is    = false
  self.drawShadow = false
end

function Card:unlock()
  self.hover.can  = true
  self.drag.can   = true
  self.drawShadow = true
end

function Card:isAtTarget(threshold)
  threshold = threshold or 1
  return math.abs(self.current.x - self.target.x) < threshold
     and math.abs(self.current.y - self.target.y) < threshold
end

function Card:getEffects(zone)
  return self.data[zone]
end

function Card:startDissolve()
  self.reverseDissolving = false
  self.dissolving        = true
end

function Card:startReverseDissolve()
  self.dissolving        = false
  self.dissolveAmount    = 1.0
  self.dissolveTime      = 0
  self.reverseDissolving = true
end

function Card:resetDissolve()
  self.dissolving        = false
  self.reverseDissolving = false
  self.dissolveAmount    = 0
  self.dissolveTime      = 0
end

function Card:isDissolving()
  return self.dissolving or self.reverseDissolving
end

function Card:isDissolved()
  return self.dissolveAmount >= 1
end

function Card:containsPoint(x, y)
  local windowScaleX = love.graphics.getWidth()  / 3840
  local windowScaleY = love.graphics.getHeight() / 2160
  local hw = self.offsetX * self.current.scale * windowScaleX + BUFFER * self.current.scale * windowScaleX
  local hh = self.offsetY * self.current.scale * windowScaleY + BUFFER * self.current.scale * windowScaleY
  return x >= self.current.x - hw
     and x <= self.current.x + hw
     and y >= self.current.y - hh
     and y <= self.current.y + hh
end

function Card:update()
  if math.abs(self.current.x - self.target.x) < 0.1 and
     math.abs(self.current.y - self.target.y) < 0.1 then
    self.current.x  = self.target.x
    self.current.y  = self.target.y
    self.stationary = true
  else
    self.stationary = false
  end

  for _, part in ipairs(self.parts) do
    part.current.dx    = animation.expDecay(part.current.dx,    part.target.dx,    12, realDt)
    part.current.dy    = animation.expDecay(part.current.dy,    part.target.dy,    12, realDt)
    part.current.dr    = animation.expDecay(part.current.dr,    part.target.dr,    12, realDt)
    part.current.scale = animation.expDecay(part.current.scale, part.target.scale, 12, realDt)
    part.current.alpha = animation.expDecay(part.current.alpha, part.target.alpha, 12, realDt)
  end

  if not self.stationary then
    self.current.x          = animation.expDecay(self.current.x, self.target.x, 12, realDt)
    self.current.y          = animation.expDecay(self.current.y, self.target.y, 12, realDt)
    self.horizontalVelocity = (self.current.x - self.target.x) / realDt
  end

  local rForce = -self.current.r * stiffness - self.current.rVel * damping
                 + self.horizontalVelocity * -influence
  self.current.rVel = self.current.rVel + rForce * realDt
  self.current.r    = self.current.r    + self.current.rVel * realDt
  if self.current.r >  math.pi / 2 then self.current.r =  math.pi / 2 end
  if self.current.r < -math.pi / 2 then self.current.r = -math.pi / 2 end

  self.current.scale = animation.expDecay(self.current.scale, self.target.scale, 18, realDt)

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

function Card:_applyDissolveUniforms(asset)
  local iw, ih = asset:getDimensions()
  self.shader:send("dissolve",         self.dissolveAmount)
  self.shader:send("time",             self.dissolveTime)
  self.shader:send("texture_details",  { 0, 0, iw, ih })
  self.shader:send("image_details",    { iw, ih })
  self.shader:send("shadow",           false)
  self.shader:send("burn_colour_1",    { 1.0, 0.5, 0.0, 1.0 })
  self.shader:send("burn_colour_2",    { 0.5, 0.5, 1.0, 0.5 })
  self.shader:send("mouse_screen_pos", { 0, 0 })
  self.shader:send("hovering",         0.0)
  self.shader:send("screen_scale",     1.0)
end

function Card:_applyTiltUniforms(includeMouse)
  local windowScaleX = love.graphics.getWidth() / 3840
  local screenCX     = self.current.x
  local screenCY     = self.current.y
  local screenScale  = self.offsetX * self.current.scale * windowScaleX

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

function Card:draw()
  local windowScaleX = love.graphics.getWidth()  / 3840
  local windowScaleY = love.graphics.getHeight() / 2160

  local useShader = self.shader ~= nil and self.dissolveAmount > 0.001
  local useTilt   = self.tiltShader ~= nil

  if self.drawShadow then
    local boost = 1.0
    if self.hover.is then boost = 2.0 end
    if self.drag.is  then boost = 2.0 end
    local dx = 25 * windowScaleX * boost
    local dy = 40 * windowScaleY * boost
    love.graphics.push()
    love.graphics.translate(dx, dy)
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.draw(
      self.asset,
      self.current.x, self.current.y, self.current.r,
      self.current.scale * windowScaleX * (boost * 0.5),
      self.current.scale * windowScaleY * (boost * 0.5),
      self.offsetX, self.offsetY
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
    self.current.x, self.current.y, self.current.r,
    self.current.scale * windowScaleX,
    self.current.scale * windowScaleY,
    self.offsetX, self.offsetY
  )

  if useShader then
    love.graphics.setShader(self.tiltShader)
  end

  if #self.parts > 0 then
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
            part.current.dr, s, s, iw / 2, ih / 2
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
          pw / 2, ph / 2
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

  -- DEBUG: red dots at slot centers
  love.graphics.setShader()
  -- for _, zone in ipairs(EFFECT_ZONES) do
  --   local n = self._slotCounts[zone.id] or 0
  --   for i = 1, n do
  --     local pos = self:getSlotPosition(zone.id, i)
  --     if pos.x then
  --       love.graphics.setColor(1, 0, 0, 1)
  --       love.graphics.circle("fill", pos.x, pos.y, 6)
  --     end
  --   end
  -- end
  love.graphics.setColor(1, 1, 1, 1)
end

return Card
