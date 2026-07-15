local Button   = require("core.button")
local Palette  = require("lib.palette")
local Manifest = require("assets.manifest")

local Carousel = {}
Carousel.__index = Carousel

local DOT_R_DESIGN    = 10   -- design units
local DOT_GAP_MULT     = 2.8
local DOT_AREA_DESIGN  = 40  -- design units, vertical space reserved below the value row for dots

-- Carousel.new(x, y, w, h, options, selectedIndex, fontSize, onChange)
-- options: array of { label = "...", value = ... }
function Carousel.new(x, y, w, h, options, selectedIndex, fontSize, onChange)
  local arrowW = h

  local self = setmetatable({
    x             = x,
    y             = y,
    w             = w,
    h             = h,
    options       = options,
    selectedIndex = selectedIndex or 1,
    fontSize      = fontSize or 48,
    onChange      = onChange,
  }, Carousel)

  self.leftArrow = Button.new(x, y, arrowW, h, "<", fontSize, function()
    self:select(self.selectedIndex - 1)
  end)
  self.rightArrow = Button.new(x + w - arrowW, y, arrowW, h, ">", fontSize, function()
    self:select(self.selectedIndex + 1)
  end)

  return self
end

function Carousel:select(i)
  if i < 1 or i > #self.options or i == self.selectedIndex then return end
  self.selectedIndex = i
  if self.onChange then self.onChange(i, self.options[i].value) end
end

-- Set selected index without firing onChange (for syncing to external state).
function Carousel:setSelected(i)
  if i < 1 or i > #self.options then return end
  self.selectedIndex = i
end

function Carousel:getSelected()
  return self.selectedIndex, self.options[self.selectedIndex].value
end

-- Total footprint including the dot strip, for stacked-row layout math.
function Carousel:getHeight()
  return self.h + DOT_AREA_DESIGN * SCALE_Y
end

function Carousel:update(mx, my)
  self.leftArrow:update(mx, my)
  self.rightArrow:update(mx, my)
end

function Carousel:mousepressed(x, y, button)
  if self.leftArrow:mousepressed(x, y, button) then return true end
  if self.rightArrow:mousepressed(x, y, button) then return true end
  return false
end

function Carousel:touchpressed(x, y)
  if self.leftArrow:touchpressed(x, y) then return true end
  if self.rightArrow:touchpressed(x, y) then return true end
  return false
end

function Carousel:draw()
  local atStart = self.selectedIndex <= 1
  local atEnd   = self.selectedIndex >= #self.options
  self.leftArrow:draw(atStart and 0.35 or 1)
  self.rightArrow:draw(atEnd and 0.35 or 1)

  local font     = Manifest.getFont(self.fontSize)
  local prevFont = love.graphics.getFont()
  love.graphics.setFont(font)
  local opt   = self.options[self.selectedIndex]
  local label = opt and opt.label or ""
  local tw = font:getWidth(label)
  local th = font:getHeight()
  love.graphics.setColor(Palette.default)
  love.graphics.print(label,
    math.floor(self.x + (self.w - tw) / 2),
    math.floor(self.y + (self.h - th) / 2))
  love.graphics.setFont(prevFont)

  local n = #self.options
  if n > 1 then
    local dotR = DOT_R_DESIGN * SCALE_X
    local gap  = dotR * DOT_GAP_MULT
    local sx   = self.x + self.w / 2
    local sy   = self.y + self.h + (DOT_AREA_DESIGN * SCALE_Y) / 2
    for i = 1, n do
      local offset = (i - (n + 1) / 2) * gap
      local color  = (i == self.selectedIndex) and Palette.accent or Palette.primary
      love.graphics.setColor(color)
      love.graphics.circle("fill", sx + offset, sy, dotR)
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
end

return Carousel
