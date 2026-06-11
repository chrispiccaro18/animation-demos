-- token_projectile.lua
-- Two modes: fling (derived or targeted) and attract (homing)

local Token = {}
Token.__index = Token

local instances = {}

local DRAG        = 0.85   -- per-frame velocity multiplier (tune for feel)
local RESTITUTION = 0.85    -- energy kept on wall bounce
local MIN_SPEED   = 2       -- px/s below which we snap to rest
local ARC_SCALE   = 1.5    -- max scale delta at arc peak
local SPIN_SCALE  = 0.012   -- rotation rate relative to horizontal speed (rad/px)

local SPEED = 2000
local TOP_SPEED = 100000
local ACCEL = 5000

local DEFAULT_DELAY = 0.2

local function defaultDelay()
    return math.min(0.5, math.random() + DEFAULT_DELAY)
end

------------------------------------------------------------------------
-- Returns a stateful accumulator for cascading delays across a loop of
-- new_attract / new_fling calls. Call acc:next(opts) per iteration.
-- step (optional number): fixed step size; omit for random increments.
------------------------------------------------------------------------
function Token.makeCascadeAccumulator(step)
    local running = 0
    local function advance()
        local d = running
        running = running + (step or defaultDelay())
        return d
    end
    return {
        next = function(self, opts)
            opts = opts or {}
            local merged = {}
            for k, v in pairs(opts) do merged[k] = v end
            merged.delay = advance()
            return merged
        end,
        nextDelay = function(self)
            return advance()
        end,
    }
end

local ramAsset = nil
local progressAsset = nil
local threatAsset = nil
local dtorAsset = nil
local nullifyAsset = nil
local emptyNullifyDtorAsset = nil

------------------------------------------------------------------------
-- Internal: reflect a point across a rect wall
-- wall: "left"|"right"|"top"|"bottom", rect: {x,y,w,h}
------------------------------------------------------------------------
local function reflect_point(px, py, wall, rect)
    if wall == "right"  then return 2*(rect.x+rect.w) - px, py end
    if wall == "left"   then return 2*rect.x - px,           py end
    if wall == "bottom" then return px, 2*(rect.y+rect.h) - py end
    if wall == "top"    then return px, 2*rect.y - py           end
end

------------------------------------------------------------------------
-- Internal: given origin, bounce wall sequence, and destination,
-- unfold destination and return {angle, path_length, bounce_points}
------------------------------------------------------------------------
local function solve_unfolded(ox, oy, dest_x, dest_y, walls, rect)
    -- mirror destination through each wall in reverse order
    local mx, my = dest_x, dest_y
    for i = #walls, 1, -1 do
        mx, my = reflect_point(mx, my, walls[i], rect)
    end

    local dx    = mx - ox
    local dy    = my - oy
    local angle = math.atan2(dy, dx)
    local dist  = math.sqrt(dx*dx + dy*dy)

    return angle, dist
end

------------------------------------------------------------------------
-- Internal: trace a ray forward to find actual bounce points
-- Returns list of {x, y} waypoints including the final landing
------------------------------------------------------------------------
local function trace_ray(ox, oy, angle, total_dist, walls, rect)
    local waypoints = {}
    local px, py = ox, oy
    local remaining = total_dist
    local vx = math.cos(angle)
    local vy = math.sin(angle)

    for _, wall in ipairs(walls) do
        -- find distance to this wall along current direction
        local t
        if wall == "right"  then t = (rect.x + rect.w - px) / vx end
        if wall == "left"   then t = (rect.x - px)           / vx end
        if wall == "bottom" then t = (rect.y + rect.h - py) / vy end
        if wall == "top"    then t = (rect.y - py)           / vy end

        if t and t > 0 then
            local bx = px + vx * t
            local by = py + vy * t
            table.insert(waypoints, {x = bx, y = by, dist = t})
            px, py = bx, by
            remaining = remaining - t
            -- reflect velocity
            if wall == "left" or wall == "right" then vx = -vx end
            if wall == "top"  or wall == "bottom" then vy = -vy end
        end
    end

    -- final destination
    table.insert(waypoints, {
        x    = px + vx * remaining,
        y    = py + vy * remaining,
        dist = remaining
    })

    return waypoints
end

------------------------------------------------------------------------
-- Pick a random wall sequence for N bounces
-- Ensures consecutive bounces are on perpendicular walls
-- (same wall twice = token going backwards, looks bad)
------------------------------------------------------------------------
local function random_wall_sequence(n)
    local h_walls = {"left", "right"}
    local v_walls = {"top",  "bottom"}
    local walls   = {}
    local last_axis = math.random(2) == 1 and "h" or "v"

    for i = 1, n do
        if last_axis == "h" then
            table.insert(walls, v_walls[math.random(2)])
            last_axis = "v"
        else
            table.insert(walls, h_walls[math.random(2)])
            last_axis = "h"
        end
    end
    return walls
end

------------------------------------------------------------------------
-- Internal: return an adjusted 'to' angle such that (to - from) is the
-- shortest angular delta, i.e. always in (-π, π].
------------------------------------------------------------------------
local function shortest_rotation_target(from, to)
    local diff = (to - from) % (2 * math.pi)
    if diff > math.pi then diff = diff - 2 * math.pi end
    return from + diff
end

local function resolveAsset(token_type)
  if token_type == "ram"      then return ramAsset
  elseif token_type == "progress" then return progressAsset
  elseif token_type == "threat"   then return threatAsset
  elseif token_type == "dtor"     then return dtorAsset
  elseif token_type == "nullify"   then return nullifyAsset
  elseif token_type == "dtor_null" then return emptyNullifyDtorAsset
  end
end

local function applyFlingPhysics(self, rect, options)
  local drag      = options and options.drag or DRAG
  local n_bounces = options and options.bounces or math.random(0, 3)

  local dest_x, dest_y
  if options and options.target then
    dest_x, dest_y = options.target.x, options.target.y
  elseif options and options.target_rect then
    dest_x = options.target_rect.x + math.random() * options.target_rect.w
    dest_y = options.target_rect.y + math.random() * options.target_rect.h
  else
    dest_x = rect.x + math.random() * rect.w
    dest_y = rect.y + math.random() * rect.h
  end

  local walls = n_bounces > 0 and random_wall_sequence(n_bounces) or {}
  local angle, total_dist = solve_unfolded(self.x, self.y, dest_x, dest_y, walls, rect)
  local v0 = total_dist * (1 - drag) * 60

  self.vx          = math.cos(angle) * v0
  self.vy          = math.sin(angle) * v0
  self.v0          = v0
  self.rect        = rect
  self.mode        = "fling"
  self.done        = false
  self.scale       = self.base_scale
  self.waypoints   = trace_ray(self.x, self.y, angle, total_dist, walls, rect)
  self.total_dist  = total_dist
  self.dist_so_far = 0
  self.wp_index    = 1
  self.seg_start   = { x = self.x, y = self.y }
end

function Token.load()
  ramAsset = love.graphics.newImage("assets/proto/ram-chip.png", { mipmaps = true })
  progressAsset = love.graphics.newImage("assets/proto/progress-token.png", { mipmaps = true })
  threatAsset = love.graphics.newImage("assets/proto/threat-token.png", { mipmaps = true })
  dtorAsset = love.graphics.newImage("assets/proto/dtor-slot.png", { mipmaps = true })
  nullifyAsset = love.graphics.newImage("assets/proto/nullify-token.png", { mipmaps = true })
  emptyNullifyDtorAsset = love.graphics.newImage("assets/proto/empty-nullify-dtor.png", { mipmaps = true })
end

------------------------------------------------------------------------
-- Constructor: fling mode
-- rect    = {x, y, w, h} bounding area
-- options = {
--   target    = {x,y} (optional; if nil, lands at random point in rect)
--   bounces   = int 0-3 (optional; random if nil)
--   drag      = float (overrides DRAG)
--   base_scale = float
-- }
------------------------------------------------------------------------
function Token.new_fling(start_x, start_y, rect, options)
    options = options or {}
    local self = setmetatable({}, Token)

    self.x          = start_x
    self.y          = start_y
    self.base_scale = options.base_scale or 1
    self.rotation   = 0
    self.done       = false
    if options.delay == false then
        self.delay = 0
    elseif options.delay then
        self.delay = options.delay
    else
        self.delay = defaultDelay()
    end
    self.token_type = options.type
    self.asset      = resolveAsset(options.type)
    self.subTokens  = options.subTokens

    applyFlingPhysics(self, rect, options)

    table.insert(instances, self)
    return self
end

------------------------------------------------------------------------
-- Constructor: attract mode (homes to exact target, eases in)
------------------------------------------------------------------------
function Token.new_attract(start_x, start_y, target_x, target_y, options)
    options = options or {}
    local self = setmetatable({}, Token)

    self.mode        = "attract"
    self.x           = start_x
    self.y           = start_y
    self.target_x    = target_x
    self.target_y    = target_y
    self.speed       = options.initial_speed  or (SPEED  * SCALE_X)
    self.max_speed   = options.max_speed      or (TOP_SPEED * SCALE_X)
    self.accel       = options.acceleration   or (ACCEL * SCALE_X)
    self.threshold   = options.threshold      or 4
    self.base_scale      = options.base_scale     or 1
    self.scale           = self.base_scale
    self.rotation        = 0
    self.done            = false
    if options.delay == false then
        self.delay = 0
    elseif options.delay then
        self.delay = options.delay
    else
        self.delay = defaultDelay()
    end
    self.token_type      = options.type
    self.start_rotation  = 0
    self.target_rotation = shortest_rotation_target(0, options.target_rotation or 0)
    self.start_scale     = self.base_scale
    self.target_scale    = options.target_scale    or self.base_scale
    local adx = target_x - start_x
    local ady = target_y - start_y
    self.attract_dist    = math.max(math.sqrt(adx*adx + ady*ady), 1)
    self.asset           = resolveAsset(options.type)
    self.subTokens       = options.subTokens
    self.onArrive        = options.onArrive

    table.insert(instances, self)
    return self
end

------------------------------------------------------------------------
-- Shared update
------------------------------------------------------------------------
function Token:update(dt, gameDt)
    if self.delay and self.delay > 0 then
        self.delay = self.delay - gameDt
        return
    end
    if self.mode == "fling" then
        if not self.done then self:_update_fling(dt) end
    else
        if not self.done then self:_update_attract(dt) end
    end

    if self.done and self.quiver and self.quiver.active then
        self.quiver.time = self.quiver.time + dt
        self.rotation = self.quiver.baseRot + math.sin(self.quiver.time * 18) * 0.35
        self.scale    = self.base_scale + math.abs(math.sin(self.quiver.time * 12)) * 0.5
        if self.quiver.time >= self.quiver.duration then
            self.quiver.active = false
            self.rotation = self.quiver.baseRot
            self.scale    = self.base_scale
        end
    end
end

function Token:_update_fling(dt)
    local drag = DRAG

    -- move
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt

    -- wall bounce (clamped to rect)
    local r = self.rect
    if self.x < r.x then
        self.x  = r.x
        self.vx = math.abs(self.vx) * RESTITUTION
    elseif self.x > r.x + r.w then
        self.x  = r.x + r.w
        self.vx = -math.abs(self.vx) * RESTITUTION
    end
    if self.y < r.y then
        self.y  = r.y
        self.vy = math.abs(self.vy) * RESTITUTION
    elseif self.y > r.y + r.h then
        self.y  = r.y + r.h
        self.vy = -math.abs(self.vy) * RESTITUTION
    end

    -- track distance for arc
    local speed = math.sqrt(self.vx*self.vx + self.vy*self.vy)
    self.dist_so_far = self.dist_so_far + speed * dt

    -- drag (frame-rate independent: same decay per second regardless of fps)
    local frame_drag = drag ^ (dt * 60)
    self.vx = self.vx * frame_drag
    self.vy = self.vy * frame_drag

    -- arc height: t = 0→1 as speed drops from v0 to 0, sin curve peaks at midpoint
    local t = 1 - math.min(speed / self.v0, 1)
    local arc_height = math.sin(t * math.pi)
    self.scale = self.base_scale + arc_height * ARC_SCALE

    -- spin: driven by horizontal velocity so bounces naturally flip direction
    self.rotation = self.rotation + self.vx * SPIN_SCALE * dt

    -- stop when nearly stationary
    if speed < MIN_SPEED then
        self.vx, self.vy = 0, 0
        self.scale = self.base_scale
        self.done  = true
    end
end

function Token:_update_attract(dt)
    local dx = self.target_x - self.x
    local dy = self.target_y - self.y
    local dist = math.sqrt(dx*dx + dy*dy)

    if dist < self.threshold then
        self.x, self.y   = self.target_x, self.target_y
        self.rotation    = self.target_rotation
        self.scale       = self.target_scale
        self.done        = true
        if self.onArrive then self.onArrive(self) end
        return
    end

    -- accelerate toward target
    self.speed = math.min(self.speed + self.accel * dt, self.max_speed)

    local nx = dx / dist
    local ny = dy / dist
    local step = math.min(self.speed * dt, dist)

    self.x = self.x + nx * step
    self.y = self.y + ny * step

    -- tween rotation and scale based on travel progress
    local t = 1 - math.min(dist / self.attract_dist, 1)
    self.rotation = self.start_rotation + (self.target_rotation - self.start_rotation) * t
    self.scale    = self.start_scale    + (self.target_scale    - self.start_scale)    * t
end

function Token:draw()
  love.graphics.push()
  love.graphics.translate(self.x, self.y)
  love.graphics.rotate(self.rotation)
  love.graphics.scale(
    (self.scale * SCALE_X) * 0.3,
    (self.scale * SCALE_Y) * 0.3
  )
  if self.asset then
    local iw, ih = self.asset:getDimensions()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.asset, 0, 0, 0, 1, 1, iw / 2, ih / 2)
    if self.subTokens and #self.subTokens > 0 then
      local n     = #self.subTokens
      local slotW = iw / n
      for i, tokenType in ipairs(self.subTokens) do
        local sub = resolveAsset(tokenType)
        if sub then
          local sw, sh = sub:getDimensions()
          local s  = math.min(slotW / sw, ih / sh) * 0.85
          local cx = (i - 0.5) * slotW - iw / 2
          love.graphics.draw(sub, cx, 0, 0, s, s, sw / 2, sh / 2)
        end
      end
    end
  else
    love.graphics.setColor(1, 0.5, 0.5, 1)
    love.graphics.circle("fill", 0, 0, 100 * SCALE_X)
  end
  love.graphics.pop()
end

------------------------------------------------------------------------
-- Module-level update/draw — call these from main instead of iterating
------------------------------------------------------------------------
function Token.clearAll()
    instances = {}
end

function Token.updateAll(dt, gameDt)
    for _, token in ipairs(instances) do
        token:update(dt, gameDt)
    end
end

function Token.drawAll()
    for _, token in ipairs(instances) do
        token:draw()
    end
end

function Token.isActive()
    for _, token in ipairs(instances) do
        if not token.done then return true end
    end
    return false
end

function Token.allDone(token_type)
    for _, token in ipairs(instances) do
        if (token_type == nil or token.token_type == token_type) and not token.done then
            return false
        end
    end
    return true
end

------------------------------------------------------------------------
-- Attract all done tokens of a given type toward a destination.
-- destination = {x, y} point, or {x, y, w, h} rect (uses center).
-- Mutates matching instances back into attract mode in-place.
------------------------------------------------------------------------
function Token.attractDone(token_type, destination, options)
    options = options or {}
    local running_delay = options.running_delay or 0

    for _, token in ipairs(instances) do
        if token.done and token.token_type == token_type then
            local target_x, target_y
            if type(destination) == "function" then
                local dest = destination(token)
                if dest then
                    target_x, target_y = dest.x, dest.y
                    token.dest_meta = dest
                end
            elseif destination.w then
                target_x = destination.x + math.random() * destination.w
                target_y = destination.y + math.random() * destination.h
            else
                target_x = destination.x
                target_y = destination.y
            end
            if target_x and target_y then
                local adx = target_x - token.x
                local ady = target_y - token.y
                token.mode             = "attract"
                token.target_x         = target_x
                token.target_y         = target_y
                token.speed            = options.initial_speed  or (SPEED  * SCALE_X)
                token.max_speed        = options.max_speed      or (TOP_SPEED * SCALE_X)
                token.accel            = options.acceleration   or (ACCEL * SCALE_X)
                token.threshold        = options.threshold      or 4
                token.start_rotation   = token.rotation
                token.target_rotation  = shortest_rotation_target(token.rotation, options.target_rotation or 0)
                token.start_scale      = token.scale
                token.target_scale     = options.target_scale   or token.base_scale
                token.attract_dist     = math.max(math.sqrt(adx*adx + ady*ady), 1)
                if options.acc then
                    token.delay = options.acc:nextDelay()
                elseif options.delay == false then
                    token.delay = 0
                elseif options.delay then
                    token.delay = running_delay
                    running_delay = running_delay + options.delay
                else
                    token.delay = running_delay
                    running_delay = running_delay + defaultDelay()
                end
                token.done             = false
                token.onArrive         = options.onArrive
            end
        end
    end
end

------------------------------------------------------------------------
-- Remove a specific token from instances by reference.
------------------------------------------------------------------------
function Token.removeSingle(token)
    for i, t in ipairs(instances) do
        if t == token then
            table.remove(instances, i)
            return
        end
    end
end

------------------------------------------------------------------------
-- Attach a flying token to a card slot. Removes it from physics.
------------------------------------------------------------------------
function Token:attachToSlot(card, zone, index)
    self.mode        = "slotted"
    self.parentCard  = card
    self.parentZone  = zone
    self.parentIndex = index
    local zoneSlots  = card._slots and card._slots[zone]
    if zoneSlots and zoneSlots[index] then
        zoneSlots[index].token       = self
        zoneSlots[index].targetAlpha = 1
    end
    Token.removeSingle(self)
end

------------------------------------------------------------------------
-- Detach a slotted token back into the world at the slot's world pos.
------------------------------------------------------------------------
function Token:detachFromSlot()
    if self.parentCard then
        local pos = self.parentCard:getSlotPosition(self.parentZone, self.parentIndex)
        if pos.x then self.x, self.y = pos.x, pos.y end
        local zoneSlots = self.parentCard._slots and self.parentCard._slots[self.parentZone]
        if zoneSlots and zoneSlots[self.parentIndex] then
            zoneSlots[self.parentIndex].token       = nil
            zoneSlots[self.parentIndex].targetAlpha = 0
        end
        self.parentCard  = nil
        self.parentZone  = nil
        self.parentIndex = nil
    end
    self.mode = "free"
    self.done = false
    table.insert(instances, self)
end

------------------------------------------------------------------------
-- Detach and immediately launch as a fling from the slot world pos.
------------------------------------------------------------------------
function Token:flingFromSlot(rect, options)
    if self.parentCard then
        local pos = self.parentCard:getSlotPosition(self.parentZone, self.parentIndex)
        if pos.x then self.x, self.y = pos.x, pos.y end
        local zoneSlots = self.parentCard._slots and self.parentCard._slots[self.parentZone]
        if zoneSlots and zoneSlots[self.parentIndex] then
            zoneSlots[self.parentIndex].token       = nil
            zoneSlots[self.parentIndex].targetAlpha = 0
        end
        self.parentCard  = nil
        self.parentZone  = nil
        self.parentIndex = nil
    end
    applyFlingPhysics(self, rect, options)
    table.insert(instances, self)
end

------------------------------------------------------------------------
-- Trigger quiver on all done tokens within threshold pixels of scannerY.
function Token.triggerQuiverNear(scannerY, threshold, duration)
    threshold = threshold or (40 * SCALE_Y)
    duration  = duration  or 0.25
    for _, token in ipairs(instances) do
        if token.done and math.abs(token.y - scannerY) < threshold then
            if not (token.quiver and token.quiver.active) then
                token.quiver = {
                    active   = true,
                    time     = 0,
                    duration = duration,
                    baseRot  = token.rotation,
                }
            end
        end
    end
end

------------------------------------------------------------------------
-- Remove done tokens from instances.
-- token_type: optional; if nil, removes all done tokens.
-- Returns the table of removed tokens.
------------------------------------------------------------------------
function Token.removeDone(token_type)
    local removed   = {}
    local remaining = {}
    for _, token in ipairs(instances) do
        if token.done and (token_type == nil or token.token_type == token_type) then
            removed[#removed + 1] = token
        else
            remaining[#remaining + 1] = token
        end
    end
    instances = remaining
    return removed
end

return Token
