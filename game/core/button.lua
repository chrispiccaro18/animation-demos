local Palette  = require("lib.palette")
local Manifest = require("assets.manifest")

local CORNER_R = 14
local LINE_W   = 6

local Button = {}
Button.__index = Button

function Button.new(x, y, w, h, label, fontSize, onClick)
  return setmetatable({
    x        = x,
    y        = y,
    w        = w,
    h        = h,
    label    = label,
    fontSize = fontSize or 48,
    onClick  = onClick,
    hovered  = false,
  }, Button)
end

function Button:containsPoint(px, py)
  return px >= self.x and px <= self.x + self.w
     and py >= self.y and py <= self.y + self.h
end

function Button:update(mx, my)
  self.hovered = self:containsPoint(mx, my)
end

function Button:mousepressed(mx, my, btn)
  if btn == 1 and self:containsPoint(mx, my) then
    if self.onClick then self.onClick() end
    return true
  end
  return false
end

function Button:touchpressed(tx, ty)
  if self:containsPoint(tx, ty) then
    if self.onClick then self.onClick() end
    return true
  end
  return false
end

function Button:draw(alphaMul)
  alphaMul = alphaMul or 1

  local bg = self.bgOverride or Palette.background
  love.graphics.setColor(bg[1], bg[2], bg[3], (bg[4] or 1) * alphaMul)
  love.graphics.rectangle("fill", self.x, self.y, self.w, self.h,
    CORNER_R * SCALE_X, CORNER_R * SCALE_Y)

  local highlighted = self.hovered or self.selected
  local borderColor = highlighted and Palette.accent or Palette.primary
  love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], (borderColor[4] or 1) * alphaMul)
  local prevLW = love.graphics.getLineWidth()
  love.graphics.setLineWidth(LINE_W * math.max(SCALE_X, SCALE_Y))
  love.graphics.rectangle("line", self.x, self.y, self.w, self.h,
    CORNER_R * SCALE_X, CORNER_R * SCALE_Y)
  love.graphics.setLineWidth(prevLW)

  local font     = Manifest.getFont(self.fontSize)
  local prevFont = love.graphics.getFont()
  love.graphics.setFont(font)
  local tw  = font:getWidth(self.label)
  local th  = font:getHeight()
  local fontColor = highlighted and Palette.accent or Palette.primary
  love.graphics.setColor(fontColor[1], fontColor[2], fontColor[3], (fontColor[4] or 1) * alphaMul)
  love.graphics.print(self.label,
    math.floor(self.x + (self.w - tw) / 2),
    math.floor(self.y + (self.h - th) / 2))
  love.graphics.setFont(prevFont)
  love.graphics.setColor(1, 1, 1, 1)
end

return Button
