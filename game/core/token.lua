local AssetManifest = require("assets.manifest")
local Audio = require("assets.audio")
local particles     = require("core.particles")
local animation     = require("lib.animation")

-- Two modes: fling (derived or targeted) and attract (homing)
local Token = {}
Token.__index = Token

local instances = {}

local DRAG        = 0.85   -- per-frame velocity multiplier (tune for feel)
local RESTITUTION = 1.0   -- energy kept on wall bounce
local MIN_SPEED   = 0.5       -- px/s below which we snap to rest
local ARC_SCALE   = 1.75    -- max scale delta at arc peak
local SPIN_SCALE  = 0.012   -- rotation rate relative to horizontal speed (rad/px)

local ANT_DUR        = 0.15
local ANT_PAUSE      = 0.15
local ANT_PEAK_SCALE = 1.5

local QUIVER_TWEEN_DUR = 0.15  -- time to rotate from current angle to upright before jiggling
local QUIVER_AMP       = math.rad(2)
local QUIVER_FREQ      = 60
local QUIVER_SCALE_FREQ = 4
local QUIVER_SCALE_AMP  = 0.5

local TRAIL_INHERIT_VEL  = false  -- true: comet tail (particles hang in world space), false: jet exhaust (particles fire backward)
local TRAIL_VEL_FACTOR   = 0.5   -- fraction of token speed for comet mode
local TRAIL_BACK_FACTOR  = 0.2   -- exhaust speed as a fraction of token speed (scales naturally with velocity)
local TRAIL_SPREAD       = math.pi * 0.4
local TRAIL_RATE         = 120    -- particles per second at peak speed
local TRAIL_SPEED_THRESH = 150   -- game px/s below which trail is suppressed
local TRAIL_PEAK_SPEED   = 1500  -- game px/s at which trail rate reaches full intensity


local _dtorBounds = nil

local _immediateTypes   = {}
local _immediateHandler = nil

------------------------------------------------------------------------
-- Register token types that fire their terminal effect immediately on
-- fling settle rather than waiting for the end-of-turn scan.
-- handler(token) is called once per settling token of a registered type.
------------------------------------------------------------------------
function Token.registerImmediateSettle(types, handler)
    _immediateTypes = {}
    for _, t in ipairs(types) do _immediateTypes[t] = true end
    _immediateHandler = handler
end

function Token.setDtorBounds(x, y, w, h)
  _dtorBounds = { x = x, y = y, w = w, h = h }
end

local SPEED = 6000
local TOP_SPEED = 20000
local PULL_SPEED = 10000
local ACCEL = 5000
local ATTRACT_DECAY_K = 4
local CHAIN_SPEED = SPEED
-- local CHAIN_SPEED = SPEED * 2.5

local DEFAULT_DELAY = 0.2
local BASE_DELAY = 0.25

local function defaultDelay()
    return math.min(BASE_DELAY, math.random() + DEFAULT_DELAY)
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
local progressNegativeAsset = nil
local threatNegativeAsset = nil
local shuffleAsset = nil
local drawToDtorAsset = nil
local drawToHandAsset = nil
local multiplyAllAsset      = nil
local multiplyThreatAsset   = nil
local multiplyProgressAsset = nil
local flipAsset             = nil

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
  elseif token_type == "progressNegative" then return progressNegativeAsset
  elseif token_type == "threatNegative" then return threatNegativeAsset
  elseif token_type == "shuffle" then return shuffleAsset
  elseif token_type == "drawToDtor" then return drawToDtorAsset
  elseif token_type == "drawToHand" then return drawToHandAsset
  elseif token_type == "multiplyAll"      then return multiplyAllAsset
  elseif token_type == "multiplyThreat"   then return multiplyThreatAsset
  elseif token_type == "multiplyProgress" then return multiplyProgressAsset
  elseif token_type == "flip"             then return flipAsset
  end
end


local function applyFlingPhysics(self, rect, options)
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

  if options and options.downward then
    dest_y = math.max(dest_y, self.y + rect.h * 0.1)
  elseif options and options.rightward then
    dest_x = math.max(dest_x, self.x + rect.w * 0.1)
  end

  self.debug_dest_x = dest_x
  self.debug_dest_y = dest_y

  local walls = n_bounces > 0 and random_wall_sequence(n_bounces) or {}
  local angle, total_dist = solve_unfolded(self.x, self.y, dest_x, dest_y, walls, rect)
  local waypoints = trace_ray(self.x, self.y, angle, total_dist, walls, rect)

  -- Each bounce multiplies speed by RESTITUTION, so segment i starts with R^i less speed.
  -- Compensate by weighting each segment's distance by 1/R^i before deriving v0.
  local effective_dist = 0
  for i, wp in ipairs(waypoints) do
    effective_dist = effective_dist + wp.dist / (RESTITUTION ^ (i - 1))
  end
  local v0 = effective_dist * (1 - DRAG) * 60

  self.vx       = math.cos(angle) * v0
  self.vy       = math.sin(angle) * v0
  self.v0       = v0
  self.rect     = rect
  self.mode     = "fling"
  self.done     = false
  self.scale    = self.base_scale
  self.quivered = false
end

function Token.load()
  ramAsset = AssetManifest.get("tokens", "ram")
  progressAsset = AssetManifest.get("tokens", "progress")
  threatAsset = AssetManifest.get("tokens", "threat")
  dtorAsset = AssetManifest.get("card", "dtorSlot")
  nullifyAsset = AssetManifest.get("tokens", "nullify")
  emptyNullifyDtorAsset = AssetManifest.get("card", "emptyNullifySlot")
  progressNegativeAsset = AssetManifest.get("tokens", "progressNegative")
  threatNegativeAsset = AssetManifest.get("tokens", "threatNegative")
  shuffleAsset         = AssetManifest.get("tokens", "shuffle")
  drawToDtorAsset      = AssetManifest.get("tokens", "drawToDtor")
  drawToHandAsset      = AssetManifest.get("tokens", "drawToHand")
  multiplyAllAsset      = AssetManifest.get("tokens", "multiplyAll")
  multiplyThreatAsset   = AssetManifest.get("tokens", "multiplyThreat")
  multiplyProgressAsset = AssetManifest.get("tokens", "multiplyProgress")
  flipAsset             = AssetManifest.get("tokens", "flip")
end

------------------------------------------------------------------------
-- Constructor: fling mode
-- rect    = {x, y, w, h} bounding area
-- options = {
--   target    = {x,y} (optional; if nil, lands at random point in rect)
--   bounces   = int 0-3 (optional; random if nil)
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
    self.value      = options.value

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
    self.initial_speed = self.speed
    self.max_speed   = options.max_speed      or (TOP_SPEED * SCALE_X)
    self.accel       = options.acceleration   or (ACCEL * SCALE_X)
    self.threshold   = options.threshold      or 1
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
    self.value           = options.value
    self.start_rotation  = 0
    self.target_rotation = shortest_rotation_target(0, options.target_rotation or 0)
    self.start_scale     = self.base_scale
    self.target_scale    = options.target_scale    or self.base_scale
    self.start_alpha     = options.start_alpha     or 1
    self.target_alpha    = options.target_alpha    or 1
    self.alpha           = self.start_alpha
    local adx = target_x - start_x
    local ady = target_y - start_y
    self.attract_dist    = math.max(math.sqrt(adx*adx + ady*ady), 1)
    self.elapsed         = 0
    self.ant_dur         = options.no_anticipation and 0 or ANT_DUR
    self.ant_pause       = options.no_anticipation and 0 or ANT_PAUSE
    self.ant_peak_scale  = options.no_anticipation and self.start_scale or self.start_scale * ANT_PEAK_SCALE
    self.asset           = resolveAsset(options.type)
    self.subTokens       = options.subTokens
    self.onArrive        = options.onArrive
    self.self_remove     = options.self_remove

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
        if not self.done then self:_update_fling(gameDt) end
    elseif self.mode == "chain" then
        if not self.done then self:_update_chain(gameDt) end
    else
        if not self.done then self:_update_attract(gameDt) end
    end

    if self.done and self.quiver and self.quiver.active then
        self.quiver.time = self.quiver.time + gameDt
        local tweenDur = self.quiver.tweenDur
        if self.quiver.time < tweenDur then
            -- smoothstep tween from landing rotation to upright
            local t = self.quiver.time / tweenDur
            local eased = t * t * (3 - 2 * t)
            self.rotation = self.quiver.baseRot + (self.quiver.targetRot - self.quiver.baseRot) * eased
            self.scale    = self.base_scale
        else
            -- jiggle around upright for the scanner's remaining duration
            local jt = self.quiver.time - tweenDur
            self.rotation = math.sin(jt * QUIVER_FREQ) * QUIVER_AMP
            self.scale    = self.base_scale + math.abs(math.sin(jt * QUIVER_SCALE_FREQ)) * QUIVER_SCALE_AMP
        end
        if self.quiver.time >= self.quiver.duration then
            self.quiver.active = false
            -- self.rotation        = self.quiver.baseRot  -- rotation is already near 0 after jiggle phase
            -- self.scale           = self.base_scale
            -- self.target_rotation = shortest_rotation_target(self.rotation, 0)
        end
    end

    if self.done and self.pop and self.pop.active then
        self.pop.time = self.pop.time + dt
        local t = self.pop.time / self.pop.duration
        if t >= 1 then
            self.pop.active = false
            if self.pop.onComplete then self.pop.onComplete(self) end
            self._remove = true
        else
            self.scale = self.pop.restScale + math.sin(t * math.pi) * (self.pop.peak - self.pop.restScale)
        end
    end

    if self.done and not (self.quiver and self.quiver.active) and self.target_rotation then
        local diff = self.target_rotation - self.rotation
        if math.abs(diff) > 0.005 then
            -- self.rotation = self.rotation + diff * math.min(dt * 6, 1)
            self.rotation = self.rotation + diff * math.min(gameDt * 60, 1)
        else
            self.rotation = self.target_rotation
            self.target_rotation = nil
        end
    end
end

function Token:_update_fling(dt)
    local drag = DRAG

    -- move
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt

    -- wall bounce (clamped to rect); reset v0 so arc restarts cleanly per segment
    local r = self.rect
    local bounced = false
    if self.x < r.x then
        self.x  = r.x
        self.vx = math.abs(self.vx) * RESTITUTION
        bounced = true
    elseif self.x > r.x + r.w then
        self.x  = r.x + r.w
        self.vx = -math.abs(self.vx) * RESTITUTION
        bounced = true
    end
    if self.y < r.y then
        self.y  = r.y
        self.vy = math.abs(self.vy) * RESTITUTION
        bounced = true
    elseif self.y > r.y + r.h then
        self.y  = r.y + r.h
        self.vy = -math.abs(self.vy) * RESTITUTION
        bounced = true
    end

    local speed = math.sqrt(self.vx*self.vx + self.vy*self.vy)
    if bounced then
      self.v0 = speed
      Audio.playClink(self.token_type)
    end

    -- drag (frame-rate independent: same decay per second regardless of fps)
    local frame_drag = drag ^ (dt * 60)
    self.vx = self.vx * frame_drag
    self.vy = self.vy * frame_drag

    -- arc height: t = 0→1 as speed drops from v0 to 0; resets each segment after a bounce
    local t = 1 - math.min(speed / self.v0, 1)
    local arc_height = math.sin(t * math.pi)
    self.scale = self.base_scale + arc_height * ARC_SCALE

    -- spin: driven by horizontal velocity so bounces naturally flip direction
    self.rotation = self.rotation + self.vx * SPIN_SCALE * dt

    -- trail particles
    local gameSpeed = speed / SCALE_X
    if gameSpeed > TRAIL_SPEED_THRESH then
      local speedFrac   = math.min(gameSpeed / TRAIL_PEAK_SPEED, 1)
      local fwdAngle    = math.atan2(self.vy, self.vx)
      local trailPreset = self.token_type and (self.token_type .. "_trail") or "token_trail"
      self.trailAccum   = (self.trailAccum or 0) + TRAIL_RATE * speedFrac * dt
      local emitCount   = math.floor(self.trailAccum)
      if emitCount > 0 then
        self.trailAccum = self.trailAccum - emitCount
        if TRAIL_INHERIT_VEL then
          particles.emitDir(trailPreset, self.x, self.y, emitCount, fwdAngle,             TRAIL_SPREAD, speed * TRAIL_VEL_FACTOR)
        else
          particles.emitDir(trailPreset, self.x, self.y, emitCount, fwdAngle + math.pi,   TRAIL_SPREAD, speed * TRAIL_BACK_FACTOR)
        end
      end
    else
      self.trailAccum = 0
    end

    -- stop when nearly stationary
    if speed < MIN_SPEED then
        self.vx, self.vy = 0, 0
        self.scale = self.base_scale
        self.done  = true
        if _immediateHandler and _immediateTypes[self.token_type] then
            _immediateHandler(self)
        end
    end
end

function Token:_update_attract(dt)
    self.elapsed = (self.elapsed or 0) + dt

    local dx = self.target_x - self.x
    local dy = self.target_y - self.y
    local dist = math.sqrt(dx*dx + dy*dy)

    if dist < self.threshold then
        self.x, self.y   = self.target_x, self.target_y
        self.rotation    = self.target_rotation
        self.scale       = self.target_scale
        self.done        = true
        if self.onArrive then self.onArrive(self) end
        if self.self_remove and not (self.pop and self.pop.active) then
            self._remove = true
        end
        return
    end

    -- slingshot pullback: drift away from target before the main pull
    local ant_dur   = self.ant_dur   or 0
    local ant_pause = self.ant_pause or 0
    if self.elapsed < ant_dur then
        local phase = self.elapsed / ant_dur
        local pull_speed = (PULL_SPEED * SCALE_X) * 0.15 * (1 - phase * phase)
        local nx = dx / dist
        local ny = dy / dist
        self.x = self.x - nx * pull_speed * dt
        self.y = self.y - ny * pull_speed * dt
        self.scale = self.start_scale + (self.ant_peak_scale - self.start_scale) * (phase * phase)
        return
    end

    -- pause at peak pullback before releasing
    if self.elapsed < ant_dur + ant_pause then
        self.scale = self.ant_peak_scale
        return
    end

    -- first frame after pause: recalibrate distance so ease-in starts fresh
    if (self.elapsed - dt) < (ant_dur + ant_pause) then
        self.attract_dist = math.max(dist, 1)
        self.speed = self.initial_speed
        Audio.playZip(self.token_type)
    end

    local t = 1 - math.min(dist / self.attract_dist, 1)

    -- cubic ease-in: nearly still early, rockets toward the end
    -- local eased = t * t * t
    -- self.speed = self.initial_speed + (self.max_speed - self.initial_speed) * eased
    self.speed = animation.expDecay(self.speed, self.max_speed, ATTRACT_DECAY_K, dt)

    local nx = dx / dist
    local ny = dy / dist
    local step = math.min(self.speed * dt, dist)

    self.x = self.x + nx * step
    self.y = self.y + ny * step

    -- tween rotation based on travel progress
    self.rotation = self.start_rotation + (self.target_rotation - self.start_rotation) * t

    -- scale deflates from anticipation peak down to target as token travels
    self.scale = self.ant_peak_scale + (self.target_scale - self.ant_peak_scale) * t

    -- tween alpha (for overflow fade-in / fade-out)
    local sa = self.start_alpha  or 1
    local ta = self.target_alpha or 1
    self.alpha = sa + (ta - sa) * t

    -- trail particles (only reached in travel phase; anticipation/pause phases return early)
    local gameSpeed = self.speed / SCALE_X
    if gameSpeed > TRAIL_SPEED_THRESH then
      local speedFrac   = math.min(gameSpeed / TRAIL_PEAK_SPEED, 1)
      local fwdAngle    = math.atan2(dy, dx)
      local trailPreset = self.token_type and (self.token_type .. "_trail") or "token_trail"
      self.trailAccum   = (self.trailAccum or 0) + TRAIL_RATE * speedFrac * dt
      local emitCount   = math.floor(self.trailAccum)
      if emitCount > 0 then
        self.trailAccum = self.trailAccum - emitCount
        if TRAIL_INHERIT_VEL then
          particles.emitDir(trailPreset, self.x, self.y, emitCount, fwdAngle,           TRAIL_SPREAD, self.speed * TRAIL_VEL_FACTOR)
        else
          particles.emitDir(trailPreset, self.x, self.y, emitCount, fwdAngle + math.pi, TRAIL_SPREAD, self.speed * TRAIL_BACK_FACTOR)
        end
      end
    else
      self.trailAccum = 0
    end
end

function Token:_update_chain(dt)
    local chain = self.chain
    local target = chain.targets[chain.idx]

    if not target then
        self.done = true
        if chain.onComplete then chain.onComplete(self) end
        return
    end

    local dx   = target.x - self.x
    local dy   = target.y - self.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < (self.threshold or 8) then
        self.x, self.y = target.x, target.y
        if chain.onVisit then chain.onVisit(self, target) end
        chain.idx = chain.idx + 1
        local next = chain.targets[chain.idx]
        if next then
            local ndx = next.x - self.x
            local ndy = next.y - self.y
            self.target_x     = next.x
            self.target_y     = next.y
            self.attract_dist = math.max(math.sqrt(ndx * ndx + ndy * ndy), 1)
            self.speed        = CHAIN_SPEED * SCALE_X
            self.start_rotation = self.rotation
            Audio.playZip(self.token_type)
        else
            self.done = true
            if chain.onComplete then chain.onComplete(self) end
        end
        return
    end

    self.speed = animation.expDecay(self.speed, self.max_speed, ATTRACT_DECAY_K, dt)
    local nx   = dx / dist
    local ny   = dy / dist
    self.x     = self.x + nx * math.min(self.speed * dt, dist)
    self.y     = self.y + ny * math.min(self.speed * dt, dist)

    local progress  = 1 - math.min(dist / (self.attract_dist or dist + 1), 1)
    self.rotation   = self.start_rotation + (0 - self.start_rotation) * progress
    self.scale      = self.target_scale

    local gameSpeed = self.speed / SCALE_X
    if gameSpeed > TRAIL_SPEED_THRESH then
        local speedFrac   = math.min(gameSpeed / TRAIL_PEAK_SPEED, 1)
        local fwdAngle    = math.atan2(dy, dx)
        local trailPreset = self.token_type and (self.token_type .. "_trail") or "token_trail"
        self.trailAccum   = (self.trailAccum or 0) + TRAIL_RATE * speedFrac * dt
        local emitCount   = math.floor(self.trailAccum)
        if emitCount > 0 then
            self.trailAccum = self.trailAccum - emitCount
            if TRAIL_INHERIT_VEL then
                particles.emitDir(trailPreset, self.x, self.y, emitCount, fwdAngle,           TRAIL_SPREAD, self.speed * TRAIL_VEL_FACTOR)
            else
                particles.emitDir(trailPreset, self.x, self.y, emitCount, fwdAngle + math.pi, TRAIL_SPREAD, self.speed * TRAIL_BACK_FACTOR)
            end
        end
    else
        self.trailAccum = 0
    end
end

------------------------------------------------------------------------
-- Start chain mode on this token — it will zip between each entry in
-- targets in order, firing options.onVisit(self, target) on arrival at
-- each, then options.onComplete(self) when the list is exhausted.
-- targets: array of { x, y, tokenType, ref }
------------------------------------------------------------------------
function Token:startChain(targets, options)
    options = options or {}
    self.mode     = "chain"
    self.done     = false
    self.quiver   = nil
    self.chain    = {
        targets    = targets,
        idx        = 1,
        onVisit    = options.onVisit,
        onComplete = options.onComplete,
    }
    self.threshold    = 8
    self.speed        = CHAIN_SPEED * SCALE_X
    self.initial_speed = self.speed
    self.max_speed    = TOP_SPEED * SCALE_X
    self.start_rotation = self.rotation
    self.target_scale = self.scale
    self.trailAccum   = 0

    if #targets > 0 then
        local t   = targets[1]
        local dx  = t.x - self.x
        local dy  = t.y - self.y
        self.target_x     = t.x
        self.target_y     = t.y
        self.attract_dist = math.max(math.sqrt(dx * dx + dy * dy), 1)
        Audio.playZip(self.token_type)
    else
        self.done = true
        if options.onComplete then options.onComplete(self) end
    end
end

------------------------------------------------------------------------
-- Find all done tokens of affectType and run them sequentially through
-- a chain that visits all done tokens matching targetTypes.
-- Targets are snapshotted before any chain starts so mutations mid-chain
-- don't affect the visit list.
-- onVisit(affectToken, target) fires on each arrival.
------------------------------------------------------------------------
function Token.startChainForType(affectType, targetTypes, onVisit)
    -- snapshot targets once so mutations don't change the list mid-chain
    local targets = {}
    for _, token in ipairs(instances) do
        if token.done and not token.is_terminal then
            for _, t in ipairs(targetTypes) do
                if token.token_type == t then
                    table.insert(targets, { x = token.x, y = token.y, tokenType = t, ref = token })
                    break
                end
            end
        end
    end

    -- collect affect tokens
    local affectTokens = {}
    for _, token in ipairs(instances) do
        if token.done and not token.is_terminal and token.token_type == affectType then
            table.insert(affectTokens, token)
        end
    end

    if #affectTokens == 0 then return end

    local function startIdx(i)
        if i > #affectTokens then return end
        local at = affectTokens[i]
        at:startChain(targets, {
            onVisit = onVisit,
            onComplete = function(token)
                token:triggerPop(token.scale * 2, 0.2, function()
                    token._remove = true
                    Audio.playImpactIn()
                end)
                startIdx(i + 1)
            end,
        })
    end
    startIdx(1)
end

------------------------------------------------------------------------
-- Mutate a single token instance to a new type in-place.
-- Used by chain onVisit callbacks for flip effects.
------------------------------------------------------------------------
function Token.mutateOne(token, newType)
    token.token_type = newType
    token.asset      = resolveAsset(newType)
end

function Token:draw()
  love.graphics.push()
  love.graphics.translate(self.x, self.y)
  love.graphics.rotate(self.rotation)
  love.graphics.scale(
    (self.scale * SCALE_X) * 0.3,
    (self.scale * SCALE_Y) * 0.3
  )
  local alpha = self.alpha or 1
  if self.asset then
    local iw, ih = self.asset:getDimensions()
    love.graphics.setColor(1, 1, 1, alpha)
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
    love.graphics.setColor(1, 0.5, 0.5, alpha)
    love.graphics.circle("fill", 0, 0, 100 * SCALE_X)
  end
  love.graphics.pop()

  -- if self.debug_dest_x then
  --   local sz = 15 * SCALE_X
  --   love.graphics.setColor(1, 0, 0, 1)
  --   love.graphics.setLineWidth(3 * SCALE_X)
  --   love.graphics.line(self.debug_dest_x - sz, self.debug_dest_y - sz, self.debug_dest_x + sz, self.debug_dest_y + sz)
  --   love.graphics.line(self.debug_dest_x + sz, self.debug_dest_y - sz, self.debug_dest_x - sz, self.debug_dest_y + sz)
  --   love.graphics.setColor(1, 1, 1, 1)
  --   love.graphics.setLineWidth(1)
  -- end
end

function Token:triggerPop(peakScale, duration, onComplete)
    self.rotation        = 0
    self.target_rotation = 0
    self.pop = {
        active     = true,
        time       = 0,
        duration   = duration or 0.4,
        restScale  = self.scale,
        peak       = peakScale or self.scale * 2,
        onComplete = onComplete,
    }
    -- Audio.playImpactIn()
end

------------------------------------------------------------------------
-- Module-level update/draw — call these from main instead of iterating
------------------------------------------------------------------------
function Token.clearAll()
  instances = {}
end

function Token.debugDump(label)
  print(string.format("[Token.debugDump] %s — %d instance(s)", label or "", #instances))
  for i, t in ipairs(instances) do
    print(string.format("  [%d] type=%-10s done=%-5s is_terminal=%-5s _remove=%-5s mode=%s",
      i,
      tostring(t.token_type),
      tostring(t.done),
      tostring(t.is_terminal),
      tostring(t._remove),
      tostring(t.mode)
    ))
  end
end

function Token.updateAll(dt, gameDt)
  for _, token in ipairs(instances) do
      token:update(dt, gameDt)
  end
  local remaining = {}
  for _, token in ipairs(instances) do
      if not token._remove then
          remaining[#remaining + 1] = token
      end
  end
  instances = remaining
end

function Token.drawAll()
  -- Scissor disabled: dtor tokens need to be visible during fling/attract phases
  -- before they reach the dtor area.
  -- local db = _dtorBounds
  -- if db then
  --   for _, token in ipairs(instances) do
  --     if token.token_type ~= "dtor" and token.token_type ~= "dtor_null" then token:draw() end
  --   end
  --   love.graphics.setScissor(db.x, db.y, db.w, db.h)
  --   for _, token in ipairs(instances) do
  --     if token.token_type == "dtor" or token.token_type == "dtor_null" then token:draw() end
  --   end
  --   love.graphics.setScissor()
  -- else
    for _, token in ipairs(instances) do
      token:draw()
    end
  -- end
end

function Token.swapTypes(typeA, typeB)
  local toA, toB = {}, {}
  for _, token in ipairs(instances) do
    if token.done and not token.is_terminal then
      if token.token_type == typeA then
        table.insert(toB, token)
      elseif token.token_type == typeB then
        table.insert(toA, token)
      end
    end
  end
  for _, token in ipairs(toB) do
    token.token_type = typeB
    token.asset      = resolveAsset(typeB)
  end
  for _, token in ipairs(toA) do
    token.token_type = typeA
    token.asset      = resolveAsset(typeA)
  end
end

function Token.spawnMultiplied(types, count, rect, flingTarget)
  local toSpawn = {}
  for _, token in ipairs(instances) do
    if token.done and not token.is_terminal then
      for _, t in ipairs(types) do
        if token.token_type == t then
          for _ = 1, count - 1 do
            table.insert(toSpawn, { x = token.x, y = token.y, tokenType = t })
          end
        end
      end
    end
  end
  for _, s in ipairs(toSpawn) do
    Token.new_fling(s.x, s.y, rect, {
      type        = s.tokenType,
      bounces     = math.random(1, 2),
      target_rect = flingTarget,
      base_scale  = 1.25,
      delay       = false,
    })
  end
end

function Token.isActive()
  for _, token in ipairs(instances) do
      if not token.done then return true end
  end
  return false
end

function Token.allQuiverDone()
  for _, token in ipairs(instances) do
    if token.quiver and token.quiver.active then return false end
  end
  return true
end

function Token.allDone(token_type)
  for _, token in ipairs(instances) do
    if (token_type == nil or token.token_type == token_type) and not token.done then
        return false

    -- if (token_type == nil or token.token_type == token_type) then
    --   if not token.done then return false end
    --   if token.pop and token.pop.active then return false end
    end
  end
  return true
end

function Token.count(token_type)
  local count = 0
  for _, token in ipairs(instances) do
    if (token_type == nil or token.token_type == token_type) and not token.is_terminal then
      count = count + 1
    end
  end
  return count
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
                token.initial_speed    = token.speed
                token.max_speed        = options.max_speed      or (TOP_SPEED * SCALE_X)
                token.accel            = options.acceleration   or (ACCEL * SCALE_X)
                token.threshold        = options.threshold      or 4
                token.start_rotation   = token.rotation
                token.target_rotation  = shortest_rotation_target(token.rotation, options.target_rotation or 0)
                token.start_scale      = token.scale
                token.target_scale     = options.target_scale   or token.base_scale
                token.attract_dist     = math.max(math.sqrt(adx*adx + ady*ady), 1)
                token.elapsed          = 0
                token.ant_dur          = options.no_anticipation and 0 or ANT_DUR
                token.ant_pause        = options.no_anticipation and 0 or ANT_PAUSE
                token.ant_peak_scale   = options.no_anticipation and token.start_scale or token.start_scale * ANT_PEAK_SCALE
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
                token.start_alpha      = token.alpha or 1
                token.target_alpha     = options.target_alpha or 1
                token.alpha            = token.start_alpha
                token.done             = false
                token.quivered         = false
                token.onArrive         = options.onArrive
                token.self_remove      = options.self_remove
                token.is_terminal      = options.terminal or false
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
        zoneSlots[index].alpha = 1
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
------------------------------------------------------------------------
function Token.triggerQuiverNear(scannerY, threshold, duration, direction)
    threshold = threshold or (40 * SCALE_Y)
    duration  = duration  or 0.25
    direction = direction or 1
    for _, token in ipairs(instances) do
        if token.done and not token.quivered and not (token.quiver and token.quiver.active) then
            -- going down: trigger when scanner has swept past the token
            -- going up:   force any stragglers the downward pass missed
            local passed = direction == 1 and scannerY >= token.y - threshold
            local force  = direction == -1
            if passed or force then
                token.quivered = true
                token.quiver = {
                    active    = true,
                    time      = 0,
                    duration  = duration,
                    tweenDur  = math.min(QUIVER_TWEEN_DUR, duration),
                    baseRot   = token.rotation,
                    targetRot = shortest_rotation_target(token.rotation, 0),
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
