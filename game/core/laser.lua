local Color = require("lib.color")

local TRAVEL_SPEED = 4
local MAX_FRACTION = 0.85
local BASE_WIDTH = 6
local GLOW2_WIDTH = BASE_WIDTH * 4
local GLOW1_WIDTH = BASE_WIDTH * 2
local BEAM_WIDTH  = BASE_WIDTH

local laser = {
  origin     = { x = 0, y = 0 },
  target     = { x = 0, y = 0 },
  beamColor  = Color("#fcfaf4", 0.3),
  glow1Color = Color("#f4a888", 0.5),
  glow2Color = Color("#b74831", 0.9),
  hidden     = true,
  progress   = 0,
}

function laser.show(originX, originY, targetX, targetY)
  laser.hidden   = false
  laser.progress = 0
  laser.origin.x = originX
  laser.origin.y = originY
  laser.target.x = targetX
  laser.target.y = targetY
end

function laser.hide()
  laser.hidden   = true
  laser.progress = 0
  laser.origin.x = 0
  laser.origin.y = 0
  laser.target.x = 0
  laser.target.y = 0
end

function laser.update(dt)
  if not laser.hidden and laser.progress < 1 + MAX_FRACTION then
    laser.progress = math.min(laser.progress + dt * TRAVEL_SPEED, 1 + MAX_FRACTION)
  end
end

function laser.isDone()
  return not laser.hidden and laser.progress >= 1 + MAX_FRACTION
end

function laser.draw()
  if not laser.hidden then
    local p    = laser.progress
    local tip  = math.min(p, 1)
    local tail = math.max(0, p - MAX_FRACTION)
    local tipX = laser.origin.x + (laser.target.x - laser.origin.x) * tip
    local tipY = laser.origin.y + (laser.target.y - laser.origin.y) * tip
    local tailX = laser.origin.x + (laser.target.x - laser.origin.x) * tail
    local tailY = laser.origin.y + (laser.target.y - laser.origin.y) * tail

    local dx  = laser.target.x - laser.origin.x
    local dy  = laser.target.y - laser.origin.y
    local len = math.sqrt(dx * dx + dy * dy)
    local nx, ny = 0, 0
    if len > 0 then
      nx = -dy / len
      ny =  dx / len
    end

    love.graphics.setColor(laser.glow2Color)
    local hw2 = GLOW2_WIDTH * SCALE_X
    love.graphics.polygon("fill",
      tailX, tailY,
      tipX + nx * hw2, tipY + ny * hw2,
      tipX - nx * hw2, tipY - ny * hw2
    )
    love.graphics.circle("fill", tipX, tipY, hw2)
    love.graphics.circle("fill", tipX, tipY, hw2)

    love.graphics.setColor(laser.glow1Color)
    local hw1 = GLOW1_WIDTH * SCALE_X
    love.graphics.polygon("fill",
      tailX, tailY,
      tipX + nx * hw1, tipY + ny * hw1,
      tipX - nx * hw1, tipY - ny * hw1
    )
    love.graphics.circle("fill", tipX, tipY, hw1)
    love.graphics.circle("fill", tipX, tipY, hw1)


    love.graphics.setColor(laser.beamColor)
    local hw0 = BEAM_WIDTH * SCALE_X
    love.graphics.polygon("fill",
      tailX, tailY,
      tipX + nx * hw0, tipY + ny * hw0,
      tipX - nx * hw0, tipY - ny * hw0
    )
    love.graphics.circle("fill", tipX, tipY, hw0)
  end
  love.graphics.setLineWidth(1)
  love.graphics.setColor(1, 1, 1, 1)
end

return laser
