local AssetManifest = require("assets.manifest")
local animation = require("lib.animation")
local Token     = require("core.token")
local Color      = require("lib.color")

local stiffness = 80
local damping   = 10
local influence = 0.001
local BUFFER    = 20

local nextId = (function()
  local id = 0
  return function()
    id = id + 1
    return id
  end
end)()

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
  { dataKey = "topEnergy",    id = "topEnergyHoles", holeKey = "ramHole"                                                              },
  { dataKey = "play",         id = "playEffect",     holeKey = "tokenHole", hasTypedTokens = true                                     },
  { dataKey = "discard",      id = "discardEffect",  holeKey = "tokenHole", hasTypedTokens = true                                     },
  { dataKey = "dtor",         id = "dtorEffect",     holeKey = "dtorSlot",  hasTypedTokens = true, singleBackground = true, fixedCount = 3, flingAsUnit = "dtor" },
  { dataKey = "bottomEnergy", id = "bottomEnergy",   holeKey = "ramHole",   tokenKey = "ramChip", hidden = true                       },
}

local ENERGY_GAP = 16
local EFFECT_GAP = 20
local DTOR_CENTERED_CY = 700  -- cy for dtor zone when no discard section present

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

local function fitScale(asset, holeW, holeH, zoneId)
  local w, h = asset:getDimensions()
  local scalePercent = 0.75
  if zoneId == "topEnergyHoles" or zoneId == "bottomEnergy" then
    scalePercent = 1.0
  end
  return math.min(holeW / w, holeH / h) * scalePercent
end

local function buildParts(data)
  local parts = {}

  if _assets.line        then table.insert(parts, { id = "line",        asset = _assets.line,        origin = { x = 107, y = 456 } }) end
  if _assets.playLine    then table.insert(parts, { id = "playLine",    asset = _assets.playLine,    origin = { x = 107, y = 422 } }) end
  if _assets.discardLine then table.insert(parts, { id = "discardLine", asset = _assets.discardLine, origin = { x = 452, y = 469 } }) end

  local hasDiscard = type(data.discard) == "table"  and #data.discard  > 0
                  or type(data.discard) == "number" and data.discard   > 0

  for _, zone in ipairs(EFFECT_ZONES) do
    local holeAsset       = _assets[zone.holeKey or "tokenHole"]
    local holePW, holePH  = holeAsset:getDimensions()
    local gap             = (zone.holeKey == "ramHole") and ENERGY_GAP or EFFECT_GAP

    local effects = data[zone.dataKey]
    local n
    if zone.singleSlot then
      n = 1
    elseif type(effects) == "number" then
      n, effects = effects, nil
    else
      n = effects and #effects or 0
    end

    if n > 0 then
      local items        = {}
      local slotCenters  = {}
      local groupOriginX, groupOriginY
      local tokenSlotW, tokenSlotH
      local bgW, bgH

      local zoneCy = (zone.id == "dtorEffect" and not hasDiscard) and DTOR_CENTERED_CY or ZONES[zone.id].cy

      if zone.singleBackground then
        groupOriginX = ZONES[zone.id].cx - holePW / 2
        groupOriginY = zoneCy - holePH / 2
        table.insert(items, { asset = holeAsset, offsetX = 0, offsetY = 0 })
        local slotW = holePW / n
        tokenSlotW  = holePW / (zone.fixedCount or n)
        tokenSlotH  = holePH
        for i = 1, n do
          slotCenters[i] = { dx = (i - 0.5) * slotW, dy = holePH / 2 }
        end
        bgW = holePW
        bgH = holePH
      else
        local totalW = n * holePW + (n - 1) * gap
        groupOriginX = ZONES[zone.id].cx - totalW / 2
        groupOriginY = zoneCy - holePH / 2
        tokenSlotW   = holePW
        tokenSlotH   = holePH
        for i = 1, n do
          local offsetX = (i - 1) * (holePW + gap)
          slotCenters[i] = { dx = offsetX + holePW / 2, dy = holePH / 2 }
          table.insert(items, { asset = holeAsset, offsetX = offsetX, offsetY = 0 })
        end
      end

      table.insert(parts, {
        id          = zone.id,
        origin      = { x = groupOriginX, y = groupOriginY },
        items       = items,
        slotCenters = slotCenters,
        tokenSlotW  = tokenSlotW,
        tokenSlotH  = tokenSlotH,
        bgW         = bgW,
        bgH         = bgH,
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
  _assets.base        = AssetManifest.get("card", "base")
  _assets.ramHole     = AssetManifest.get("card", "ramHole")
  _assets.tokenHole   = AssetManifest.get("card", "tokenHole")
  _assets.ramChip     = AssetManifest.get("tokens", "ram")
  _assets.dtorSlot    = AssetManifest.get("card", "dtorSlot")
  _assets.line        = AssetManifest.get("card", "line")
  _assets.playLine    = AssetManifest.get("card", "playLine")
  _assets.discardLine = AssetManifest.get("card", "discardLine")
  _assets.tokens = {
    progress = AssetManifest.get("tokens", "progress"),
    threat   = AssetManifest.get("tokens", "threat"),
    nullify  = AssetManifest.get("tokens", "nullify"),
    ram      = _assets.ramChip,
    dtor     = AssetManifest.get("tokens", "dtor"),
    progressNegative = AssetManifest.get("tokens", "progressNegative"),
    threatNegative = AssetManifest.get("tokens", "threatNegative"),
    shuffle         = AssetManifest.get("tokens", "shuffle"),
    drawToDtor      = AssetManifest.get("tokens", "drawToDtor"),
    drawToHand      = AssetManifest.get("tokens", "drawToHand"),
  }
end

function Card:_initState(x, y, data)
  local baseAsset = _assets.base
  self.hover      = { is = false, can = true }
  self.drag       = { is = false, can = true, offsetX = 0, offsetY = 0, isTouch = false }
  self.stationary = true
  self.horizontalVelocity = 0
  self._startX    = x
  self._startY    = y
  self.current    = { x = x, y = y, r = 0, rVel = 0, scale = 0.5 }
  self.target     = { x = x, y = y, r = 0, scale = 0.5 }
  self.w          = baseAsset:getWidth()  * self.current.scale
  self.h          = baseAsset:getHeight() * self.current.scale
  self.parts      = {}
  self.zoneState  = "idle"
  self._excluded  = false
  self.drawShadow = true
  self.mouseX     = 0
  self.mouseY     = 0
  self._shake     = { trauma = 0, elapsed = 0, intensity = 0, duration = 0 }
  self.slotEdgeY  = nil
  self.dissolveAmount    = 0
  self.dissolveTime      = 0
  self.dissolving        = false
  self.reverseDissolving = false
  self.data       = data
  self.energy     = data.topEnergy or 0
  self.decay      = data.decay or 12

  self:_setParts(buildParts(data))

  self._slots = {}
  for _, zone in ipairs(EFFECT_ZONES) do
    local effects = data[zone.dataKey]
    local n
    if zone.singleSlot then
      n = 1
    else
      n = type(effects) == "number" and effects or (effects and #effects or 0)
    end
    if n > 0 then
      self._slots[zone.id] = {}
      for i = 1, n do
        self._slots[zone.id][i] = { token = nil, alpha = 0, targetAlpha = 0 }
      end
      if zone.hasTypedTokens and type(effects) == "table" then
        for i, effect in ipairs(effects) do
          self:fillSlot(zone.id, i, effect.type, true)
        end
      elseif zone.tokenKey then
        local tokenType = (zone.tokenKey == "ramChip") and "ram" or zone.tokenKey
        for i = 1, n do
          self:fillSlot(zone.id, i, tokenType, true)
        end
      end
    end
  end

  self._slotCounts = {}
  for _, zone in ipairs(EFFECT_ZONES) do
    if zone.singleSlot then
      self._slotCounts[zone.id] = 1
    else
      local effects = data[zone.dataKey]
      self._slotCounts[zone.id] = type(effects) == "number" and effects
                                 or (effects and #effects or 0)
    end
  end
end

function Card.new(x, y, data)
  local self      = setmetatable({}, Card)
  local baseAsset = _assets.base
  self.id         = nextId()
  self.asset      = baseAsset
  self.offsetX    = baseAsset:getWidth()  / 2
  self.offsetY    = baseAsset:getHeight() / 2
  self.shader     = _shaders.dissolve
  self.tiltShader = _shaders.tilt
  self.scales     = { idle = 0.55, hover = 0.75, drag = 0.9 }
  -- self.scales     = { idle = 0.5, hover = 0.65, drag = 0.7 }
  self:_initState(x, y, data)
  return self
end

function Card:resetToInitial(x, y)
  self:_initState(x or self.current.x, y or self.current.y, self.data)
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
      tokenSlotW   = p.tokenSlotW,
      tokenSlotH   = p.tokenSlotH,
      bgW          = p.bgW,
      bgH          = p.bgH,
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
    local wxs = SCALE_X
    local wys = SCALE_Y
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
      local wxs = SCALE_X
      local wys = SCALE_Y
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
      local wxs = SCALE_X
      local wys = SCALE_Y
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

function Card:getSlotCanvasRect(zone, index)
  local part = self:getPartById(zone)
  if not part or not part.slotCenters then return nil end
  local sc = part.slotCenters[index]
  if not sc then return nil end

  local wxs = SCALE_X
  local wys = SCALE_Y
  local cs  = self.current.scale
  local px  = part.origin.x - self.offsetX + sc.dx + part.current.dx
  local py  = part.origin.y - self.offsetY + sc.dy + part.current.dy
  local sx  = px * cs * wxs
  local sy  = py * cs * wys
  local r   = self.current.r

  local holePW = part.tokenSlotW or _assets.tokenHole:getWidth()
  local holePH = part.tokenSlotH or _assets.tokenHole:getHeight()

  return {
    cx = self.current.x + sx * math.cos(r) - sy * math.sin(r),
    cy = self.current.y + sx * math.sin(r) + sy * math.cos(r),
    w  = holePW * cs * wxs,
    h  = holePH * cs * wys,
  }
end

-- Returns world-space center + full dimensions for a singleBackground zone (e.g. dtorEffect).
-- Returns nil if the zone doesn't exist or has no bgW stored.
function Card:getZoneCanvasRect(zone)
  local part = self:getPartById(zone)
  if not part or not part.bgW then return nil end
  local wxs = SCALE_X
  local wys = SCALE_Y
  local cs  = self.current.scale
  local px  = part.origin.x - self.offsetX + part.bgW / 2 + part.current.dx
  local py  = part.origin.y - self.offsetY + part.bgH / 2 + part.current.dy
  local sx  = px * cs * wxs
  local sy  = py * cs * wys
  local r   = self.current.r
  return {
    cx = self.current.x + sx * math.cos(r) - sy * math.sin(r),
    cy = self.current.y + sx * math.sin(r) + sy * math.cos(r),
    w  = part.bgW * cs * wxs,
    h  = part.bgH * cs * wys,
  }
end

function Card:fillSlot(zone, index, tokenType, instant)
  local zoneSlots = self._slots[zone]
  if zoneSlots and zoneSlots[index] then
    local slot = zoneSlots[index]
    slot.token       = { token_type = tokenType }
    slot.targetAlpha = 1
    if instant then slot.alpha = 1 end
  end
end

function Card:clearSlot(zone, index)
  local zoneSlots = self._slots[zone]
  if zoneSlots and zoneSlots[index] then
    local slot = zoneSlots[index]
    slot.token       = nil
    slot.targetAlpha = 0
  end
end

function Card:clearZone(zone)
  local zoneSlots = self._slots[zone]
  if zoneSlots then
    for i in pairs(zoneSlots) do self:clearSlot(zone, i) end
  end
end

function Card:getSlotToken(zone, index)
  local zoneSlots = self._slots[zone]
  if zoneSlots and zoneSlots[index] then
    local slot = zoneSlots[index]
    return slot.token and slot.token.token_type or nil
  end
  return nil
end

function Card:flingZone(zone, rect, options)
  local zoneSlots = self._slots[zone]
  if not zoneSlots then return end

  local zoneCfg
  for _, z in ipairs(EFFECT_ZONES) do
    if z.id == zone then zoneCfg = z; break end
  end

  if zoneCfg and zoneCfg.flingAsUnit then
    local n = #zoneSlots
    local pos
    if n <= 1 then
      pos = self:getSlotPosition(zone, 1)
    else
      local p1 = self:getSlotPosition(zone, 1)
      local pn = self:getSlotPosition(zone, n)
      pos = { x = (p1.x + pn.x) / 2, y = (p1.y + pn.y) / 2 }
    end
    if pos.x then
      local flingOpts = {}
      for k, v in pairs(options or {}) do flingOpts[k] = v end
      flingOpts.type = zoneCfg.flingAsUnit
      local subTokens = {}
      for i = 1, #zoneSlots do
        local slot = zoneSlots[i]
        if slot and slot.token then
          table.insert(subTokens, slot.token.token_type)
        end
      end
      if #subTokens > 0 then flingOpts.subTokens = subTokens end
      Token.new_fling(pos.x, pos.y, rect, flingOpts)
    end
    for i in pairs(zoneSlots) do
      zoneSlots[i].token       = nil
      zoneSlots[i].targetAlpha = 0
    end
    return
  end

  local acc = options and options.cascade_step and Token.makeCascadeAccumulator(options.cascade_step) or nil
  for i, slot in pairs(zoneSlots) do
    if slot.token then
      if slot.token.flingFromSlot then
        slot.token:flingFromSlot(rect, options)
      else
        local pos = self:getSlotPosition(zone, i)
        local flingOpts = {}
        for k, v in pairs(options or {}) do flingOpts[k] = v end
        flingOpts.type = slot.token.token_type
        if acc then flingOpts = acc:next(flingOpts) end
        Token.new_fling(pos.x, pos.y, rect, flingOpts)
        slot.token       = nil
        slot.targetAlpha = 0
      end
    end
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
  self.zoneState = state
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

function Card:isAtTargetHeight(threshold)
  threshold = threshold or 1
  return math.abs(self.current.y - self.target.y) < threshold
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

function Card:enterSlot(edgeY)
  local wys = SCALE_Y
  -- default: use the card's current top edge so the full card is visible at entry
  self.slotEdgeY = edgeY or (self.current.y - self.offsetY * self.current.scale * wys)
end

function Card:exitSlot()
  self.slotEdgeY = nil
end

function Card:restoreAllSlots()
  for _, zone in ipairs(EFFECT_ZONES) do
    local effects = self.data[zone.dataKey]
    local n
    if zone.singleSlot then
      n = 1
    else
      n = type(effects) == "number" and effects or (effects and #effects or 0)
    end
    if n > 0 and self._slots[zone.id] then
      if zone.hasTypedTokens and type(effects) == "table" then
        for i, effect in ipairs(effects) do
          self:fillSlot(zone.id, i, effect.type)
        end
      elseif zone.tokenKey then
        local tokenType = (zone.tokenKey == "ramChip") and "ram" or zone.tokenKey
        for i = 1, n do
          self:fillSlot(zone.id, i, tokenType)
        end
      end
    end
  end
end

function Card:isDissolving()
  return self.dissolving or self.reverseDissolving
end

function Card:isDissolved()
  return self.dissolveAmount >= 1
end

function Card:containsPoint(x, y)
  local windowScaleX = SCALE_X
  local windowScaleY = SCALE_Y
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

  for _, zoneSlots in pairs(self._slots) do
    for _, slot in pairs(zoneSlots) do
      slot.alpha = animation.expDecay(slot.alpha, slot.targetAlpha, 12, realDt)
    end
  end

  if not self.stationary then
    self.current.x          = animation.expDecay(self.current.x, self.target.x, self.decay, realDt)
    self.current.y          = animation.expDecay(self.current.y, self.target.y, self.decay, realDt)
    self.horizontalVelocity = (self.current.x - self.target.x) / (realDt * SCALE_X)
    -- self.horizontalVelocity = (self.current.x - self.target.x) / realDt
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
    if self.dissolveAmount >= 1 then
      self.dissolving = false
    end
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
  -- self.shader:send("burn_colour_2",    Color("#556998", 1))
  -- self.shader:send("burn_colour_1",    Color("#c9736f", 0.5))
  self.shader:send("burn_colour_1",    { 1.0, 0.5, 0.0, 0.5 })
  self.shader:send("burn_colour_2",    { 0.5, 0.5, 1.0, 0.5 })
  self.shader:send("mouse_screen_pos", { 0, 0 })
  self.shader:send("hovering",         0.0)
  self.shader:send("screen_scale",     1.0)
end

function Card:_applyTiltUniforms(includeMouse)
  local windowScaleX = SCALE_X
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
  local windowScaleX = SCALE_X
  local windowScaleY = SCALE_Y
  local W = SCALE_X * 3840
  local H = SCALE_Y * 2160

  -- Slot entry: clip below slot edge (hide the portion inside the slot)
  if self.slotEdgeY then
    love.graphics.setScissor(0, self.slotEdgeY, W, H - self.slotEdgeY)
  end

  -- Slot entry foreshortening: perspective trapezoid via tilt shader
  local slotDepth = 0.0
  if self.slotEdgeY then
    local halfH   = self.offsetY * self.current.scale * windowScaleY
    local cardTop = self.current.y - halfH
    if cardTop < self.slotEdgeY then
      -- depth: 0 = top just touching edge, 1 = bottom at edge (fully in)
      slotDepth = math.min((self.slotEdgeY - cardTop) / (2 * halfH), 1)
    end
  end

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
    self.tiltShader:send("slot_depth", slotDepth)
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

    -- Draw slot token occupants
    for _, zone in ipairs(EFFECT_ZONES) do
      local zoneSlots = self._slots[zone.id]
      if zoneSlots then
        local part = self:getPartById(zone.id)
        if part then
          local holeAsset      = _assets[zone.holeKey or "tokenHole"]
          local holePW, holePH = holeAsset:getDimensions()
          local fitW = part.tokenSlotW or holePW
          local fitH = part.tokenSlotH or holePH
          local partAlpha = part.hidden and 0 or part.current.alpha
          for i, slot in pairs(zoneSlots) do
            if slot.token and slot.alpha > 0.001 then
              local tokenType  = slot.token.token_type
              local tokenAsset = _assets[tokenType] or (_assets.tokens and _assets.tokens[tokenType])
              if tokenAsset then
                local sc = part.slotCenters and part.slotCenters[i]
                if sc then
                  local cx = part.origin.x - self.offsetX + sc.dx + part.current.dx
                  local cy = part.origin.y - self.offsetY + sc.dy + part.current.dy
                  local iw, ih = tokenAsset:getDimensions()
                  local s = fitScale(tokenAsset, fitW, fitH, zone.id) * part.current.scale
                  if partAlpha > 0.001 and useShader then
                    self:_applyDissolveUniforms(tokenAsset)
                    love.graphics.setShader(self.shader)
                  end
                  love.graphics.setColor(1, 1, 1, slot.alpha * partAlpha)
                  love.graphics.draw(tokenAsset, cx, cy, 0, s, s, iw / 2, ih / 2)
                  if useShader and partAlpha > 0.001 then
                    love.graphics.setShader(self.tiltShader)
                  end
                end
              end
            end
          end
        end
      end
    end

    love.graphics.pop()
  end

  if useTilt or useShader then
    love.graphics.setShader()
  end

  love.graphics.setShader()
  love.graphics.setColor(1, 1, 1, 1)

  if self.slotEdgeY then love.graphics.setScissor() end
end

return Card
