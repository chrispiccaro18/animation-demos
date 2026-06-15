local config = require("lib.config")
local Color  = require("lib.color")

local speedControl = {}
local spaceHeld = false

-- fixed screen-pixel sizes, independent of game resolution
local X0      = 16
local Y0      = 16
local BTN_W   = 52
local BTN_H   = 36
local GAP     = 8
local CORNER  = 5
local FONT_SZ = 16
local HINT_SZ = 12

local font     = nil
local hintFont = nil

local function totalW()
  local n = #config.speedPresets
  return n * BTN_W + (n - 1) * GAP
end

function speedControl.load()
  font     = love.graphics.newFont("assets/NotoSans-Medium.ttf", FONT_SZ)
  hintFont = love.graphics.newFont("assets/NotoSans-Medium.ttf", HINT_SZ)
end

function speedControl.setSpaceHeld(held)
  spaceHeld = held
end

function speedControl.mousepressed(x, y, button)
  if button ~= 1 or spaceHeld then return false end
  for i = 1, #config.speedPresets do
    local bx = X0 + (i - 1) * (BTN_W + GAP)
    if x >= bx and x <= bx + BTN_W and y >= Y0 and y <= Y0 + BTN_H then
      config.speedIndex = i
      config.speed      = config.speedPresets[i]
      return true
    end
  end
  return false
end

function speedControl.draw()
  love.graphics.push("all")

  local tw   = totalW()
  local hintY = Y0 + BTN_H + 4

  if spaceHeld then
    love.graphics.setColor(1, 0.82, 0.18, 1)
    love.graphics.rectangle("fill", X0, Y0, tw, BTN_H, CORNER, CORNER)

    love.graphics.setColor(0.08, 0.06, 0.01, 1)
    love.graphics.setFont(font)
    local label = "3x  (SPACE)"
    local lw = font:getWidth(label)
    local lh = font:getHeight()
    love.graphics.print(label, X0 + (tw - lw) / 2, Y0 + (BTN_H - lh) / 2)

    love.graphics.setFont(hintFont)
    love.graphics.setColor(1, 0.82, 0.18, 0.6)
    local sub = "release for " .. config.speedPresets[config.speedIndex] .. "x"
    love.graphics.print(sub, X0, hintY)
  else
    for i, preset in ipairs(config.speedPresets) do
      local bx     = X0 + (i - 1) * (BTN_W + GAP)
      local active = (i == config.speedIndex)

      if active then
        love.graphics.setColor(Color("#6ED59E"))
      else
        love.graphics.setColor(0.13, 0.13, 0.18, 0.88)
      end
      love.graphics.rectangle("fill", bx, Y0, BTN_W, BTN_H, CORNER, CORNER)

      if active then
        love.graphics.setColor(0.04, 0.1, 0.06, 1)
      else
        love.graphics.setColor(0.65, 0.65, 0.7, 1)
      end
      love.graphics.setFont(font)
      local label = preset .. "x"
      local lw    = font:getWidth(label)
      local lh    = font:getHeight()
      love.graphics.print(label, bx + (BTN_W - lw) / 2, Y0 + (BTN_H - lh) / 2)
    end

    love.graphics.setFont(hintFont)
    love.graphics.setColor(0.45, 0.45, 0.5, 1)
    love.graphics.print("TAB cycles  |  hold SPACE for 3x", X0, hintY)
  end

  love.graphics.pop()
end

return speedControl
