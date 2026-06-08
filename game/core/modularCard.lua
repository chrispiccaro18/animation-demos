local NewCard = require("core.newCard")

local ZONES = {
  topEnergyHoles = { cx = 379, cy = 96  },
  playEffect     = { cx = 382, cy = 288 },
  discardEffect  = { cx = 382, cy = 639 },
  dtorEffect     = { cx = 378, cy = 847 },
  bottomEnergy   = { cx = 378, cy = 858 },
}

-- holeKey:        asset key for the slot background
-- tokenKey:       fixed asset key for the slot face (no per-slot type lookup)
-- hasTypedTokens: look up assets.tokens[effect.type] per slot
-- hidden:         group starts hidden
local EFFECT_ZONES = {
  { dataKey = "topEnergy",    id = "topEnergyHoles", holeKey = "ramHole"                                    },
  { dataKey = "play",         id = "playEffect",     holeKey = "tokenHole", hasTypedTokens = true           },
  { dataKey = "discard",      id = "discardEffect",  holeKey = "tokenHole", hasTypedTokens = true           },
  { dataKey = "dtor",         id = "dtorEffect",     holeKey = "tokenHole", hasTypedTokens = true           },
  { dataKey = "bottomEnergy", id = "bottomEnergy",   holeKey = "ramHole",   tokenKey = "ramChip", hidden = true },
}

local ENERGY_GAP = 7
local EFFECT_GAP = 8

local function fitScale(asset, holeW, holeH)
  local w, h = asset:getDimensions()
  return math.min(holeW / w, holeH / h) * 0.85
end

local function buildParts(data, assets)
  local parts = {}

  if assets.line        then table.insert(parts, { id = "line",        asset = assets.line,        origin = { x = 107, y = 456 } }) end
  if assets.playLine    then table.insert(parts, { id = "playLine",    asset = assets.playLine,    origin = { x = 107, y = 422 } }) end
  if assets.discardLine then table.insert(parts, { id = "discardLine", asset = assets.discardLine, origin = { x = 452, y = 469 } }) end

  for _, zone in ipairs(EFFECT_ZONES) do
    local holeAsset = assets[zone.holeKey or "tokenHole"]
    local holePW, holePH = holeAsset:getDimensions()
    local gap = (zone.holeKey == "ramHole") and ENERGY_GAP or EFFECT_GAP

    local effects = data[zone.dataKey]
    local n
    if type(effects) == "number" then
      n, effects = effects, nil
    else
      n = effects and #effects or 0
    end

    if n > 0 then
      local totalW      = n * holePW + (n - 1) * gap
      local groupOriginX = ZONES[zone.id].cx - totalW / 2
      local groupOriginY = ZONES[zone.id].cy - holePH / 2

      local items       = {}
      local slotCenters = {}
      for i = 1, n do
        local offsetX = (i - 1) * (holePW + gap)
        local cx = offsetX + holePW / 2
        local cy = holePH / 2
        slotCenters[i] = { dx = cx, dy = cy }
        table.insert(items, { asset = holeAsset, offsetX = cx, offsetY = cy })

        if zone.hasTypedTokens and effects then
          local tokenAsset = assets.tokens and assets.tokens[effects[i].type]
          if tokenAsset then
            table.insert(items, { asset = tokenAsset, offsetX = cx, offsetY = cy, scale = fitScale(tokenAsset, holePW, holePH) })
          end
        elseif zone.tokenKey then
          local tokenAsset = assets[zone.tokenKey]
          if tokenAsset then
            table.insert(items, { asset = tokenAsset, offsetX = cx, offsetY = cy, scale = fitScale(tokenAsset, holePW, holePH) })
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

local ModularCard = {}

function ModularCard.new(x, y, baseAsset, data, assets)
  local card = NewCard.new(x, y, baseAsset)
  card:setParts(buildParts(data, assets))
  card.data = data

  card._slotCounts = {}
  for _, zone in ipairs(EFFECT_ZONES) do
    local effects = data[zone.dataKey]
    card._slotCounts[zone.id] = type(effects) == "number" and effects or (effects and #effects or 0)
  end

  function card:getSlotPosition(zone, index)
    local part = self:getPartById(zone)
    if part and part.slotCenters then
      local sc = part.slotCenters[index]
      if sc then
        return {
          x = self.current.x + part.origin.x + sc.dx + part.current.dx,
          y = self.current.y + part.origin.y + sc.dy + part.current.dy,
        }
      end
    end
    return { x = nil, y = nil }
  end

  function card:getZoneSlotPositions(zone)
    local n = self._slotCounts[zone] or 0
    local result = {}
    for i = 1, n do result[i] = self:getSlotPosition(zone, i) end
    return result
  end

  -- local _baseDraw = card.draw
  -- function card:draw()
  --   _baseDraw(self)
  --   local windowScaleX = love.graphics.getWidth() / 3840
  --   local windowScaleY = love.graphics.getHeight() / 2160
  --   love.graphics.setShader()
  --   for _, zone in ipairs(EFFECT_ZONES) do
  --     local n = self._slotCounts[zone.id] or 0
  --     for i = 1, n do
  --       local pos = self:getSlotPosition(zone.id, i)
  --       if pos.x then
  --         love.graphics.setColor(1, 0, 0, 1)
  --         love.graphics.circle("fill", pos.x, pos.y, 6)
  --       end
  --     end
  --   end
  --   love.graphics.setColor(1, 1, 1, 1)
  -- end

  return card
end

return ModularCard
