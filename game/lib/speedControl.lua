local config       = require("lib.config")
local Color        = require("lib.color")
local AssetManifest = require("assets.manifest")

local speedControl = {}
local spaceHeld = false

-- Sizes and canvas dims are set in load() relative to SCALE_X/Y (reference: 3840×2160).
local BTN_W   = 0
local BTN_H   = 0
local GAP     = 0
local RADIUS  = 0
local CANVAS_W = 0
local CANVAS_H = 0
local font     = nil
local hintFont = nil

-- Switch corner by changing POSITION.corner:
--   "top-left" | "top-right" | "bottom-left" | "bottom-right"
local POSITION = {
  corner = "bottom-left",
  margin = 0,  -- set in load()
}

local function totalW()
  local n = #config.speedPresets
  return n * BTN_W + (n - 1) * GAP
end

-- Always uses the fixed canvas coordinate space so draw and mousepressed agree.
local function getOrigin()
  local m = POSITION.margin
  local c = POSITION.corner
  local x = (c == "top-left" or c == "bottom-left") and m or (CANVAS_W - m - totalW())
  local y = (c == "top-left" or c == "top-right")   and m or (CANVAS_H - m - BTN_H)
  return x, y
end

function speedControl.load()
  CANVAS_W        = math.floor(3840 * SCALE_X)
  CANVAS_H        = math.floor(2160 * SCALE_Y)
  local BASE = 8
  BTN_W           = math.floor(BASE * 18 * SCALE_X)
  BTN_H           = math.floor(BASE * 12 * SCALE_Y)
  GAP             = math.floor(BASE * 4 * SCALE_X)
  RADIUS          = math.floor(BASE * SCALE_X)
  POSITION.margin = math.floor(BASE * 8 * SCALE_X)
  font     = AssetManifest.getFont(72)
  hintFont = AssetManifest.getFont(48)
end

function speedControl.setSpaceHeld(held)
  spaceHeld = held
end

function speedControl.mousepressed(x, y, button)
  if button ~= 1 or spaceHeld then return false end
  local x0, y0 = getOrigin()
  for i = 1, #config.speedPresets do
    local bx = x0 + (i - 1) * (BTN_W + GAP)
    if x >= bx and x <= bx + BTN_W and y >= y0 and y <= y0 + BTN_H then
      config.speedIndex = i
      config.speed      = config.speedPresets[i]
      return true
    end
  end
  return false
end

function speedControl.draw()
  love.graphics.push("all")

  local x0, y0 = getOrigin()
  local tw      = totalW()
  local isBottom = POSITION.corner:sub(1, 6) == "bottom"
  local hintH   = hintFont:getHeight() * 2 + hintFont:getLineHeight()
  local hintY   = isBottom and (y0 - hintH - 4) or (y0 + BTN_H + 4)

  if spaceHeld then
    love.graphics.setColor(1, 0.82, 0.18, 1)
    love.graphics.rectangle("fill", x0, y0, tw, BTN_H, RADIUS, RADIUS)

    love.graphics.setColor(0.08, 0.06, 0.01, 1)
    love.graphics.setFont(font)
    local label = "3x  (SPACE)"
    local lw = font:getWidth(label)
    local lh = font:getHeight()
    love.graphics.print(label, x0 + (tw - lw) / 2, y0 + (BTN_H - lh) / 2)

    love.graphics.setFont(hintFont)
    love.graphics.setColor(1, 0.82, 0.18, 0.6)
    local sub = "release for " .. config.speedPresets[config.speedIndex] .. "x"
    love.graphics.print(sub, x0, hintY)
  else
    for i, preset in ipairs(config.speedPresets) do
      local bx     = x0 + (i - 1) * (BTN_W + GAP)
      local active = (i == config.speedIndex)

      if active then
        love.graphics.setColor(Color("#6ED59E"))
      else
        love.graphics.setColor(0.13, 0.13, 0.18, 0.88)
      end
      love.graphics.rectangle("fill", bx, y0, BTN_W, BTN_H, RADIUS, RADIUS)

      if active then
        love.graphics.setColor(0.04, 0.1, 0.06, 1)
      else
        love.graphics.setColor(0.65, 0.65, 0.7, 1)
      end
      love.graphics.setFont(font)
      local label = preset .. "x"
      local lw    = font:getWidth(label)
      local lh    = font:getHeight()
      love.graphics.print(label, bx + (BTN_W - lw) / 2, y0 + (BTN_H - lh) / 2)
    end

    love.graphics.setFont(hintFont)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("TAB cycles\nHold SPACE for 3x", x0, hintY)
  end

  love.graphics.pop()
end

return speedControl
