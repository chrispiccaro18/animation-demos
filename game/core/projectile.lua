local animation = require("lib.animation")

local Projectile = {}
Projectile.__index = Projectile

-- config: { asset = img, text = "str", font = font }
-- asset OR text provides the visual body; font is used for both text rendering and label overlay.
function Projectile.new(config)
  local self = setmetatable({}, Projectile)
  self.asset   = config.asset
  self.text    = config.text
  self.font    = config.font
  self._animationExponent = config.animationExp or 6
  self.animationExp = config.animationExp or 6
  self.fontColor = config.fontColor or {0, 0, 0, 1}
  self.label   = ""
  self.visible = false
  self.current = { x = 0, y = 0 }
  self.target  = { x = 0, y = 0 }
  if self.asset then
    self.w = self.asset:getWidth()
    self.h = self.asset:getHeight()
  elseif self.font and self.text then
    self.w = self.font:getWidth(self.text)
    self.h = self.font:getHeight()
  else
    self.w, self.h = 0, 0
  end
  return self
end

function Projectile:launch(fromX, fromY, toX, toY, label, animationExp)
  self.current.x = fromX
  self.current.y = fromY
  self.target.x  = toX
  self.target.y  = toY
  self.label     = label or ""
  self.animationExp = animationExp or self._animationExponent
  self.visible   = true
end

function Projectile:hide()
  self.visible = false
  self.animationExp = self._animationExponent
end

function Projectile:isNearTarget(threshold)
  threshold = threshold or 2
  return math.abs(self.current.x - self.target.x) < threshold
     and math.abs(self.current.y - self.target.y) < threshold
end

function Projectile:update()
  if not self.visible then return end
  self.current.x = animation.expDecay(self.current.x, self.target.x, self.animationExp, realDt)
  self.current.y = animation.expDecay(self.current.y, self.target.y, self.animationExp, realDt)
end

function Projectile:draw()
  if not self.visible then return end
  local px = self.current.x - self.w / 2
  local py = self.current.y - self.h / 2
  love.graphics.setColor(1, 1, 1, 1)
  if self.asset then
    love.graphics.draw(self.asset, px, py)
  elseif self.text and self.font then
    local prev = love.graphics.getFont()
    love.graphics.setFont(self.font)
    love.graphics.print(self.text, px, py)
    love.graphics.setFont(prev)
  end
  if self.label ~= "" and self.font then
    local prev = love.graphics.getFont()
    love.graphics.setFont(self.font)
    love.graphics.setColor(self.fontColor)
    love.graphics.printf(self.label, px, py + (self.h - self.font:getHeight()) / 2, self.w, "center")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(prev)
  end
end

return Projectile
