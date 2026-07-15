local Palette = require("lib.palette")

local CORNER_R = 6
local LINE_W   = 5

local Checkbox = {}
Checkbox.__index = Checkbox

-- Checkbox.new(x, y, size, checked, onToggle)
function Checkbox.new(x, y, size, checked, onToggle)
  return setmetatable({
    x        = x,
    y        = y,
    size     = size,
    checked  = checked or false,
    onToggle = onToggle,
    hovered  = false,
  }, Checkbox)
end

function Checkbox:setChecked(v)
  self.checked = v
end

function Checkbox:containsPoint(px, py)
  return px >= self.x and px <= self.x + self.size
     and py >= self.y and py <= self.y + self.size
end

function Checkbox:update(mx, my)
  self.hovered = self:containsPoint(mx, my)
end

function Checkbox:mousepressed(mx, my, button)
  if button == 1 and self:containsPoint(mx, my) then
    self.checked = not self.checked
    if self.onToggle then self.onToggle(self.checked) end
    return true
  end
  return false
end

function Checkbox:touchpressed(tx, ty)
  if self:containsPoint(tx, ty) then
    self.checked = not self.checked
    if self.onToggle then self.onToggle(self.checked) end
    return true
  end
  return false
end

function Checkbox:draw()
  local cr = CORNER_R * SCALE_X

  love.graphics.setColor(Palette.background)
  love.graphics.rectangle("fill", self.x, self.y, self.size, self.size, cr, cr)

  local borderColor = self.hovered and Palette.accent or Palette.primary
  love.graphics.setColor(borderColor)
  local prevLW = love.graphics.getLineWidth()
  love.graphics.setLineWidth(LINE_W * math.max(SCALE_X, SCALE_Y))
  love.graphics.rectangle("line", self.x, self.y, self.size, self.size, cr, cr)
  love.graphics.setLineWidth(prevLW)

  if self.checked then
    local inset = self.size * 0.22
    love.graphics.setColor(Palette.accent)
    love.graphics.rectangle("fill",
      self.x + inset, self.y + inset,
      self.size - inset * 2, self.size - inset * 2,
      cr * 0.5, cr * 0.5)
  end

  love.graphics.setColor(1, 1, 1, 1)
end

return Checkbox
