-- Frame-based tooltip system with hoverable child interactables.
--
-- Each frame, callers issue tooltip.request() for any currently-hovered parent.
-- The module tracks per-id hover timers, fades in/out, computes child world
-- positions, hit-tests children, and tracks an extended keep-alive zone so the
-- tooltip stays visible while the mouse is anywhere in [card → gap → box].
--
-- Call order (each frame, inside love.update):
--   tooltip.clear()                    before any requests
--   [callers issue tooltip.request()]
--   tooltip.update(mx, my)             after all requests are in
--   glowRequests.collectAll(...)       picks up tooltip.collectGlowRequests
--
-- Call order (love.draw):
--   tooltip.draw()                     after glow:renderTop(), before pop()
--
-- Request data:
--   {
--     x          = number,   -- tooltip box left edge (screen coords)
--     y          = number,   -- tooltip box top edge (screen coords)
--     extendLeft = number,   -- screen pixels left of x that are still "in" the tooltip
--                            -- (covers card body + gap so hover persists across the gap)
--     lines      = { string, ... },
--     children   = {
--       {
--         id     = string,
--         localX = number,   -- offset from tooltip origin, pre-scale units
--         localY = number,
--         radius = number,   -- hit radius, pre-scale (default 30)
--         asset  = Image,
--         glows  = function(glow),
--       },
--     },
--   }

local animation = require("lib.animation")

local M = {}

-- ─── Config ───────────────────────────────────────────────────────────────────

local PARENT_DELAY = 0.35   -- seconds hovered before tooltip appears
local CHILD_DELAY  = 0.10   -- seconds child hovered before feedback fires
local FADE_SPEED   = 8      -- expDecay lambda for all alpha transitions

-- Box layout constants (pre-scale; multiply by SCALE_X / SCALE_Y at runtime)
local BOX_W   = 340
local PAD_X   = 16
local PAD_Y   = 14
local LINE_H  = 26
local CHILD_H = 80   -- height reserved below text for the children icon row

-- ─── State ────────────────────────────────────────────────────────────────────

local _requests      = {}   -- this frame: { id, data }
local _prevIds       = {}   -- id -> true, present in requests last frame
local _parentTimers  = {}   -- id -> seconds continuously hovered
local _parentAlpha   = {}   -- id -> current alpha, persists for fade-out
local _lastData      = {}   -- id -> last known data, used during fade-out
local _childTimers   = {}   -- child_id -> seconds continuously hovered
local _childActive   = {}   -- child_id -> bool
local _extendedHover = {}   -- id -> bool; rebuilt each update(); read by hand:update() next frame
local _layouts       = {}   -- computed each frame; consumed by draw + collectGlowRequests

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function hitCircle(mx, my, cx, cy, r)
  local dx, dy = mx - cx, my - cy
  return dx * dx + dy * dy <= r * r
end

local function boxDims(data)
  local lines = data.lines or {}
  local hasChildren = data.children and #data.children > 0
  local bw = BOX_W  * SCALE_X
  local bh = BOX_W * 1.25 * SCALE_Y
  -- local bh = (PAD_Y * 2 + math.max(#lines, 1) * LINE_H) * SCALE_Y
  --          + (hasChildren and CHILD_H * SCALE_Y or 0)
  return bw, bh
end

local function buildChildLayouts(data, ox, oy, mx, my, dt, alpha)
  local out = {}
  if not data.children then return out end
  for _, child in ipairs(data.children) do
    local cid    = child.id
    local wx     = ox + (child.localX or 0) * SCALE_X
    local wy     = oy + (child.localY or 0) * SCALE_Y
    local radius = (child.radius or 30) * SCALE_X
    if hitCircle(mx, my, wx, wy, radius) then
      _childTimers[cid] = (_childTimers[cid] or 0) + dt
    else
      _childTimers[cid] = 0
    end
    local active = (_childTimers[cid] or 0) >= CHILD_DELAY
    _childActive[cid] = active
    out[#out + 1] = {
      id     = cid,
      worldX = wx,
      worldY = wy,
      radius = radius,
      asset  = child.asset,
      glows  = child.glows,
      active = active,
      alpha  = alpha,
    }
  end
  return out
end

local function computeExtendedHover(data, ox, oy, bw, bh, mx, my)
  local padX = PAD_X * SCALE_X
  local padY = PAD_Y * SCALE_Y
  return mx >= ox - padX and mx <= ox + bw + padX
     and my >= oy - padY and my <= oy + bh + padY
end

-- ─── Public API ───────────────────────────────────────────────────────────────

-- Call once per frame before issuing requests.
function M.clear()
  _prevIds = {}
  for _, req in ipairs(_requests) do
    _prevIds[req.id] = true
  end
  _requests    = {}
  _layouts     = {}
  _childActive = {}
  -- _extendedHover is NOT cleared here — hand:update() reads it before update() runs.
end

-- Queue a tooltip for this frame. id must be stable for the same logical parent.
function M.request(id, data)
  if not _prevIds[id] then
    -- If residual alpha exists (quick re-hover), skip the delay so the tooltip
    -- doesn't flash down to zero before fading back in.
    if (_parentAlpha[id] or 0) > 0.05 then
      _parentTimers[id] = PARENT_DELAY
    else
      _parentTimers[id] = 0
    end
    if data.children then
      for _, child in ipairs(data.children) do
        _childTimers[child.id] = 0
      end
    end
  end
  _lastData[id] = data
  _requests[#_requests + 1] = { id = id, data = data }
end

-- Advance timers, compute layouts, hit-test children, update extended hover zones.
-- Must be called after all requests for the frame have been issued.
function M.update(mx, my)
  local dt = realDt
  _extendedHover = {}

  local activeIds = {}
  for _, req in ipairs(_requests) do activeIds[req.id] = true end

  -- Active tooltips.
  for _, req in ipairs(_requests) do
    local id   = req.id
    local data = req.data

    _parentTimers[id] = (_parentTimers[id] or 0) + dt
    local target     = (_parentTimers[id] >= PARENT_DELAY) and 1.0 or 0.0
    _parentAlpha[id] = animation.expDecay(_parentAlpha[id] or 0, target, FADE_SPEED, dt)

    local alpha   = _parentAlpha[id]
    local visible = alpha > 0.01
    local ox      = data.x or 0
    local oy      = data.y or 0
    local bw, bh  = boxDims(data)

    _extendedHover[id] = visible and computeExtendedHover(data, ox, oy, bw, bh, mx, my)

    _layouts[#_layouts + 1] = {
      id       = id,
      data     = data,
      ox       = ox,
      oy       = oy,
      bw       = bw,
      bh       = bh,
      alpha    = alpha,
      visible  = visible,
      children = visible and buildChildLayouts(data, ox, oy, mx, my, dt, alpha) or {},
    }
  end

  -- Retired tooltips: fade out, no child interaction, but keep-alive zone still active.
  for id in pairs(_prevIds) do
    if not activeIds[id] then
      _parentAlpha[id] = animation.expDecay(_parentAlpha[id] or 0, 0, FADE_SPEED, dt)
      local alpha = _parentAlpha[id]
      if alpha > 0.01 and _lastData[id] then
        local data   = _lastData[id]
        local ox     = data.x or 0
        local oy     = data.y or 0
        local bw, bh = boxDims(data)

        _extendedHover[id] = computeExtendedHover(data, ox, oy, bw, bh, mx, my)

        _layouts[#_layouts + 1] = {
          id       = id,
          data     = data,
          ox       = ox,
          oy       = oy,
          bw       = bw,
          bh       = bh,
          alpha    = alpha,
          visible  = true,
          children = {},
        }
      end
    end
  end
end

function M.areAnyActive()
  for _, layout in ipairs(_layouts) do
    if layout.visible then return true end
  end
  return false
end

function M.isActive(id)
  for _, layout in ipairs(_layouts) do
    if layout.id == id and layout.visible then
      return true
    end
  end
  return false
end

-- True if the mouse is within the tooltip's extended keep-alive zone (card + gap + box).
-- Reads previous frame's data — safe to call from hand:update() before tooltip.update().
function M.isExtendedHover(id)
  return _extendedHover[id] == true
end

function M.isChildActive(id)
  return _childActive[id] == true
end

-- Called from glowRequests.collectAll.
function M.collectGlowRequests(glow)
  for _, layout in ipairs(_layouts) do
    if layout.visible then
      for _, child in ipairs(layout.children) do
        if child.active and child.glows then
          child.glows(glow)
        end
      end
    end
  end
end

-- Call after glow:renderTop(), before love.graphics.pop().
-- Visual placeholder — replace box/text/icon rendering to match your art style.
function M.draw()
  local padX  = PAD_X * SCALE_X
  local padY  = PAD_Y * SCALE_Y
  local lineH = LINE_H * SCALE_Y

  for _, layout in ipairs(_layouts) do
    if layout.visible then
      local data  = layout.data
      local alpha = layout.alpha
      local ox    = layout.ox
      local oy    = layout.oy
      local bw    = layout.bw
      local bh    = layout.bh
      local lines = data.lines or {}

      love.graphics.setColor(0.05, 0.05, 0.12, 0.88 * alpha)
      love.graphics.rectangle("fill", ox, oy, bw, bh, 6 * SCALE_X, 6 * SCALE_Y)
      love.graphics.setColor(0.35, 0.35, 0.65, 0.5 * alpha)
      love.graphics.rectangle("line", ox, oy, bw, bh, 6 * SCALE_X, 6 * SCALE_Y)

      love.graphics.setColor(1, 1, 1, alpha)
      for i, line in ipairs(lines) do
        love.graphics.print(line, ox + padX, oy + padY + (i - 1) * lineH, 0, SCALE_X, SCALE_Y)
      end

      for _, child in ipairs(layout.children) do
        if child.asset then
          local iw, ih = child.asset:getDimensions()
          local s      = 0.5 * SCALE_X
          local bright = child.active and 1.5 or 1.0
          love.graphics.setColor(bright, bright, bright, child.alpha)
          love.graphics.draw(child.asset, child.worldX, child.worldY, 0, s, s, iw / 2, ih / 2)
        end
      end
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
end

return M
