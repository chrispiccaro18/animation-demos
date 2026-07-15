local Button  = require("core.button")
local Palette = require("lib.palette")

local ButtonGroup = {}
ButtonGroup.__index = ButtonGroup

local function blend(c1, c2, t)
  return {
    c1[1] + (c2[1] - c1[1]) * t,
    c1[2] + (c2[2] - c1[2]) * t,
    c1[3] + (c2[3] - c1[3]) * t,
    1,
  }
end

-- ButtonGroup.new(x, y, w, h, labels, fontSize, selectedIndex, onSelect, opts)
-- opts.values    -- array parallel to labels; getSelectedValue() returns values[selectedIndex]
-- opts.gap       -- px gap between items (default 0)
-- opts.fillMode  -- "overlay" (default, translucent accent tint) or "solid" (opaque primary fill, tab style)
function ButtonGroup.new(x, y, w, h, labels, fontSize, selectedIndex, onSelect, opts)
  opts = opts or {}
  local gap      = opts.gap or 0
  local values   = opts.values or labels
  local fillMode = opts.fillMode or "overlay"
  local n        = #labels
  local itemW    = (w - gap * (n - 1)) / n

  local self = setmetatable({
    x             = x,
    y             = y,
    w             = w,
    h             = h,
    selectedIndex = selectedIndex or 1,
    onSelect      = onSelect,
    values        = values,
    fillMode      = fillMode,
    buttons       = {},
  }, ButtonGroup)

  for i, label in ipairs(labels) do
    local bx = x + (i - 1) * (itemW + gap)
    self.buttons[i] = Button.new(bx, y, itemW, h, label, fontSize, function()
      self.selectedIndex = i
      if self.onSelect then self.onSelect(i, self.values[i]) end
    end)
  end

  return self
end

function ButtonGroup:setSelected(i)
  self.selectedIndex = i
end

function ButtonGroup:getSelectedValue()
  return self.values[self.selectedIndex]
end

function ButtonGroup:update(mx, my)
  for _, btn in ipairs(self.buttons) do btn:update(mx, my) end
end

function ButtonGroup:mousepressed(x, y, button)
  for _, btn in ipairs(self.buttons) do
    if btn:mousepressed(x, y, button) then return true end
  end
  return false
end

function ButtonGroup:touchpressed(x, y)
  for _, btn in ipairs(self.buttons) do
    if btn:touchpressed(x, y) then return true end
  end
  return false
end

function ButtonGroup:draw()
  for i, btn in ipairs(self.buttons) do
    if i == self.selectedIndex then
      btn.bgOverride = self.fillMode == "solid"
        and Palette.primary
        or blend(Palette.background, Palette.accent, 0.25)
      -- Selected buttons stay readable (accent border/text) even when idle,
      -- since a solid/overlay bg fill would otherwise match the idle text color.
      btn.selected = true
    else
      btn.bgOverride = nil
      btn.selected   = false
    end
    btn:draw()
  end
  love.graphics.setColor(1, 1, 1, 1)
end

return ButtonGroup
