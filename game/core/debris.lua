local areas     = require("core.areas")
local animation = require("lib.animation")
local Palette   = require("lib.palette")

local Debris = {}

local MAX_DEBRIS = 20
local DRAG       = 0.9   -- per-frame @ 60fps

-- Game-unit constants (multiplied by SCALE_X/Y at runtime)
local SPEED_MIN  = 3600
local SPEED_MAX  = 8600
local SIZE_MIN   = 40
local SIZE_MAX   = 90
local MIN_SPEED  = 80    -- game u/s; below this a piece comes to rest

local ATTRACT_SPEED_START = 300
local ATTRACT_SPEED_MAX   = 7000
local ATTRACT_K           = 5
local ARRIVE_DIST         = 10  -- canvas px
local FADE_DIST           = 90  -- canvas px; start fading when this close to target

local CLICK_RADIUS        = 100  -- canvas px; resting pieces within this get flung
local FLING_SPEED         = SPEED_MAX - SPEED_MIN  -- game u/s
-- local FLING_SPEED         = 4500  -- game u/s

local instances = {}
local _nextId   = 0

local COLORS = {
  Palette.primary,
  -- { 0.70, 0.66, 0.62, 0.85 },
  -- { 0.60, 0.56, 0.52, 0.80 },
  -- { 0.90, 0.85, 0.70, 0.85 },
  -- { 0.76, 0.71, 0.82, 0.80 },
}

local function newPiece(x, y)
  _nextId = _nextId + 1
  local speed = (SPEED_MIN + math.random() * (SPEED_MAX - SPEED_MIN)) * SCALE_X
  local angle = math.random() * math.pi * 2
  local size  = (SIZE_MIN  + math.random() * (SIZE_MAX  - SIZE_MIN))  * SCALE_X
  return {
    id         = _nextId,
    x          = x,
    y          = y,
    vx         = math.cos(angle) * speed,
    vy         = math.sin(angle) * speed - speed * 0.25,  -- slight upward burst
    size       = size,
    shape      = math.random(2) == 1 and "circle" or "square",
    color      = COLORS[math.random(#COLORS)],
    rotation   = math.random() * math.pi * 2,
    angVel     = (math.random() - 0.5) * 10,
    alpha      = 1,
    done       = false,
    attracting = false,
  }
end

function Debris.spawn(x, y, count)
  count = count or 5
  for _ = 1, count do
    table.insert(instances, newPiece(x, y))
  end
  while #instances > MAX_DEBRIS do
    table.remove(instances, 1)  -- cull oldest
  end
end

function Debris.attractAll(targetX, targetY)
  for _, p in ipairs(instances) do
    p.attracting   = true
    p.done         = false
    p.attractSpeed = ATTRACT_SPEED_START * SCALE_X
    p.targetX      = targetX
    p.targetY      = targetY
  end
end

function Debris.updateAll(dt)
  local rect      = areas.desk
  local remaining = {}

  for _, p in ipairs(instances) do
    if p.attracting then
      p.attractSpeed = animation.expDecay(
        p.attractSpeed, ATTRACT_SPEED_MAX * SCALE_X, ATTRACT_K, dt
      )
      local dx   = p.targetX - p.x
      local dy   = p.targetY - p.y
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist > ARRIVE_DIST then
        local step = math.min(p.attractSpeed * dt, dist)
        p.x        = p.x + (dx / dist) * step
        p.y        = p.y + (dy / dist) * step
        p.rotation = p.rotation + p.angVel * dt
        p.alpha    = dist < FADE_DIST and (dist / FADE_DIST) or 1
        table.insert(remaining, p)
      end
      -- else: arrived — drop the piece

    elseif not p.done then
      p.x = p.x + p.vx * dt
      p.y = p.y + p.vy * dt

      if p.x < rect.x then
        p.x  = rect.x
        p.vx = math.abs(p.vx) * 0.55
      elseif p.x > rect.x + rect.w then
        p.x  = rect.x + rect.w
        p.vx = -math.abs(p.vx) * 0.55
      end
      if p.y < rect.y then
        p.y  = rect.y
        p.vy = math.abs(p.vy) * 0.55
      elseif p.y > rect.y + rect.h then
        p.y  = rect.y + rect.h
        p.vy = -math.abs(p.vy) * 0.55
      end

      local frame_drag = DRAG ^ (dt * 60)
      p.vx     = p.vx    * frame_drag
      p.vy     = p.vy    * frame_drag
      p.angVel = p.angVel * frame_drag
      p.rotation = p.rotation + p.angVel * dt

      local speed = math.sqrt(p.vx * p.vx + p.vy * p.vy)
      if speed < MIN_SPEED * SCALE_X then
        p.vx    = 0
        p.vy    = 0
        p.angVel = 0
        p.done  = true
      end

      table.insert(remaining, p)
    else
      table.insert(remaining, p)  -- resting; persist
    end
  end

  instances = remaining
end

function Debris.drawAll()
  for _, p in ipairs(instances) do
    local c = p.color
    love.graphics.setColor(c[1], c[2], c[3], c[4] * (p.alpha or 1))
    love.graphics.push()
    love.graphics.translate(p.x, p.y)
    love.graphics.rotate(p.rotation)
    local s = p.size
    if p.shape == "circle" then
      love.graphics.circle("fill", 0, 0, s * 0.5)
    else
      love.graphics.rectangle("fill", -s * 0.5, -s * 0.5, s, s)
    end
    love.graphics.pop()
  end
  love.graphics.setColor(1, 1, 1, 1)
end

function Debris.mousePressed(mx, my, button)
  if button ~= 1 then return end
  for _, p in ipairs(instances) do
    if p.done then
      local dx   = p.x - mx
      local dy   = p.y - my
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist < CLICK_RADIUS then
        local nx, ny
        if dist < 1 then
          nx, ny = 0, -1
        else
          nx, ny = dx / dist, dy / dist
        end
        local speed  = FLING_SPEED * SCALE_X
        p.vx         = nx * speed
        p.vy         = ny * speed
        p.angVel     = (math.random() - 0.5) * 15
        p.done       = false
        p.attracting = false
        p.alpha      = 1
      end
    end
  end
end

function Debris.clearAll()
  instances = {}
  _nextId   = 0
end

return Debris
