local Palette  = require("lib.palette")
local Manifest = require("assets.manifest")

local Slider = {}
Slider.__index = Slider

-- Rounds to 4 decimal places so persisted/applied volumes aren't full-precision
-- floats derived straight from pixel math.
local function round4(v)
  return math.floor(v * 10000 + 0.5) / 10000
end

-- Slider.new(x, y, w, h, value, onChange, onRelease, fontSize, onPress)
-- value in [0,1]. onChange(value) fires continuously while dragging (live feedback);
-- onRelease(value) fires once when the drag ends (persistence point).
-- onPress(value) fires once when the drag begins (e.g. for an audible preview).
-- (x,y,w,h) describe the track itself; the value readout is drawn just past
-- its right edge, so callers should leave room to the right of a centered track.
function Slider.new(x, y, w, h, value, onChange, onRelease, fontSize, onPress)
  return setmetatable({
    x        = x,
    y        = y,
    w        = w,
    h        = h,
    trackW   = w,
    gap      = h * 0.4,
    value    = round4(value or 0),
    onChange = onChange,
    onRelease = onRelease,
    onPress  = onPress,
    fontSize = fontSize or 48,
    handleR  = h * 0.55,
    _dragging = false,
    _hovered  = false,
  }, Slider)
end

function Slider:setValue(v)
  self.value = round4(math.max(0, math.min(1, v)))
end

function Slider:getValue()
  return self.value
end

function Slider:_setFromX(mx)
  local t = (mx - self.x) / self.trackW
  t = round4(math.max(0, math.min(1, t)))
  self.value = t
  if self.onChange then self.onChange(t) end
end

function Slider:_inBounds(px, py)
  return px >= self.x and px <= self.x + self.trackW
     and py >= self.y and py <= self.y + self.h
end

function Slider:update(mx, my)
  if self._dragging then
    if love.mouse.isDown(1) then
      self:_setFromX(mx)
    else
      self._dragging = false
      if self.onRelease then self.onRelease(self.value) end
    end
    self._hovered = true
  else
    self._hovered = self:_inBounds(mx, my)
  end
end

function Slider:mousepressed(mx, my, button)
  if button == 1 and self:_inBounds(mx, my) then
    self._dragging = true
    self:_setFromX(mx)
    if self.onPress then self.onPress(self.value) end
    return true
  end
  return false
end

function Slider:touchpressed(tx, ty)
  if self:_inBounds(tx, ty) then
    self._dragging = true
    self:_setFromX(tx)
    if self.onPress then self.onPress(self.value) end
    return true
  end
  return false
end

function Slider:draw()
  local trackY = self.y + self.h / 2
  local lineW  = math.max(4, self.h * 0.15)
  local prevLW = love.graphics.getLineWidth()

  love.graphics.setLineWidth(lineW)
  love.graphics.setColor(Palette.primary)
  love.graphics.line(self.x, trackY, self.x + self.trackW, trackY)

  love.graphics.setColor(Palette.accent)
  local fillX = self.x + self.value * self.trackW
  love.graphics.line(self.x, trackY, fillX, trackY)
  love.graphics.setLineWidth(prevLW)

  local handleColor = (self._hovered or self._dragging) and Palette.accent or Palette.primary
  love.graphics.setColor(handleColor)
  love.graphics.circle("fill", fillX, trackY, self.handleR)

  local font     = Manifest.getFont(self.fontSize)
  local prevFont = love.graphics.getFont()
  love.graphics.setFont(font)
  local pct = string.format("%d%%", math.floor(self.value * 100 + 0.5))
  love.graphics.setColor(Palette.muted)
  love.graphics.print(pct,
    math.floor(self.x + self.trackW + self.gap),
    math.floor(self.y + (self.h - font:getHeight()) / 2))
  love.graphics.setFont(prevFont)

  love.graphics.setColor(1, 1, 1, 1)
end

return Slider
