local Palette = require("lib.palette")

local Shatter = {}

local CARD_W   = 757
local CARD_H   = 1014
local OFFSET_X = CARD_W / 2   -- 378.5
local OFFSET_Y = CARD_H / 2   -- 507
local MAX_CENT_LEN = math.sqrt((CARD_W/2)^2 + (CARD_H/2)^2)  -- ~633

local NUM_PATTERNS = 8
local SEEDS_MIN    = 6
local SEEDS_MAX    = 10

local CRACK_SPEED     = 1800   -- card-pixels/s for crack front from center
local CRACK_DRAW_TIME = 0.05  -- s for each edge to grow to full length
local CRACK_WIDTH     = 2.5   -- card-pixel line width

local SHARD_FADE_TIME = 1.00
local SHARD_GRAVITY   = 100   -- world-px/s^2
local SHARD_SPEED_MIN = 1250
local SHARD_SPEED_MAX = 2800

-- Reverse (assemble) constants
local ASSEMBLE_TIME     = 0.7   -- s for each shard to travel from start to target
local ASSEMBLE_STAGGER  = 0.15  -- s of extra delay for innermost shards
local OFFSCREEN_DIST    = 1600  -- world-px; how far off-screen shards start
local HEAL_TIME         = 0.15  -- s for healing cracks to sweep closed

local PATTERN_SEEDS = { 42, 137, 271, 589, 1024, 2048, 3141, 9999 }

local _patterns = {}

-- ── Crack growth easing ───────────────────────────────────────────────────────
-- t is the raw linear progress [0, 1] for a single edge growing to full length.
-- Return a remapped t to change the feel of crack propagation.
local function crack_ease(t)
  -- return t                        -- linear
  -- return t * t                 -- ease in (slow start, fast finish)
  -- return 1 - (1-t)*(1-t)       -- ease out (fast start, slow finish)
  -- return t * t * (3 - 2*t)     -- smoothstep
  return t < 0.5 and 2*t*t or 1-(-2*t+2)^2/2  -- ease in-out quad
end

-- ── Assemble easing ───────────────────────────────────────────────────────────
-- t in [0, 1]; controls how shards decelerate into their target positions.
local function assemble_ease(t)
  return 1 - (1 - t)^3   -- ease-out cubic: fast start, gentle landing
  -- return 1 - (1-t)*(1-t)  -- ease-out quad (softer)
  -- return t                 -- linear
end

-- ── Sutherland-Hodgman polygon clipping ──────────────────────────────────────

local function sh_inside(px, py, ax, ay, bx, by)
  return (bx - ax) * (py - ay) - (by - ay) * (px - ax) >= -1e-6
end

local function sh_intersect(ax, ay, bx, by, cx, cy, dx, dy)
  local denom = (ax - bx) * (cy - dy) - (ay - by) * (cx - dx)
  if math.abs(denom) < 1e-10 then return nil end
  local t = ((ax - cx) * (cy - dy) - (ay - cy) * (cx - dx)) / denom
  return { x = ax + t * (bx - ax), y = ay + t * (by - ay) }
end

local function clip_polygon(poly, ax, ay, bx, by)
  if #poly < 3 then return {} end
  local out  = {}
  local prev = poly[#poly]
  for _, curr in ipairs(poly) do
    local ci = sh_inside(curr.x, curr.y, ax, ay, bx, by)
    local pi = sh_inside(prev.x, prev.y, ax, ay, bx, by)
    if ci then
      if not pi then
        local pt = sh_intersect(prev.x, prev.y, curr.x, curr.y, ax, ay, bx, by)
        if pt then table.insert(out, pt) end
      end
      table.insert(out, { x = curr.x, y = curr.y })
    elseif pi then
      local pt = sh_intersect(prev.x, prev.y, curr.x, curr.y, ax, ay, bx, by)
      if pt then table.insert(out, pt) end
    end
    prev = curr
  end
  return out
end

-- ── Polygon utilities ─────────────────────────────────────────────────────────

local function polygon_area_centroid(poly)
  local area = 0
  local cx, cy = 0, 0
  local n = #poly
  for i = 1, n do
    local j = i % n + 1
    local cross = poly[i].x * poly[j].y - poly[j].x * poly[i].y
    area = area + cross
    cx   = cx + (poly[i].x + poly[j].x) * cross
    cy   = cy + (poly[i].y + poly[j].y) * cross
  end
  area = area / 2
  if math.abs(area) < 0.5 then
    cx, cy = 0, 0
    for _, v in ipairs(poly) do cx = cx + v.x; cy = cy + v.y end
    return cx / n, cy / n, 0
  end
  return cx / (6 * area), cy / (6 * area), math.abs(area)
end

local function build_vertex_data(vertices, centroid)
  local verts = {}
  local function uv(x, y)
    return (x + OFFSET_X) / CARD_W, (y + OFFSET_Y) / CARD_H
  end
  local cu, cv = uv(centroid.x, centroid.y)
  table.insert(verts, { 0, 0, cu, cv })
  for _, v in ipairs(vertices) do
    local u, vv = uv(v.x, v.y)
    table.insert(verts, { v.x - centroid.x, v.y - centroid.y, u, vv })
  end
  local v1 = vertices[1]
  local u1, vv1 = uv(v1.x, v1.y)
  table.insert(verts, { v1.x - centroid.x, v1.y - centroid.y, u1, vv1 })
  return verts
end

-- ── Pattern generation ────────────────────────────────────────────────────────

local function on_boundary(x, y)
  local hw, hh, tol = CARD_W / 2, CARD_H / 2, 1.5
  return math.abs(x - (-hw)) < tol or math.abs(x - hw) < tol
      or math.abs(y - (-hh)) < tol or math.abs(y - hh) < tol
end

local function generate_pattern()
  local hw = CARD_W / 2
  local hh = CARD_H / 2

  local boundary = {
    { x = -hw, y = -hh }, { x = hw, y = -hh },
    { x =  hw, y =  hh }, { x = -hw, y =  hh },
  }

  local n = math.random(SEEDS_MIN, SEEDS_MAX)
  local seeds = {}
  for _ = 1, n do
    table.insert(seeds, { x = math.random() * CARD_W - hw, y = math.random() * CARD_H - hh })
  end

  -- Voronoi cells via Sutherland-Hodgman clipping
  local cells = {}
  for i, si in ipairs(seeds) do
    local cell = {}
    for _, v in ipairs(boundary) do table.insert(cell, { x = v.x, y = v.y }) end
    for j, sj in ipairs(seeds) do
      if i ~= j and #cell >= 3 then
        local mx = (si.x + sj.x) / 2
        local my = (si.y + sj.y) / 2
        local dx = sj.x - si.x
        local dy = sj.y - si.y
        -- Perpendicular bisector oriented so seed_i is on the left (kept side)
        cell = clip_polygon(cell, mx + dy, my - dx, mx - dy, my + dx)
      end
    end
    if #cell >= 3 then
      local cx, cy, area = polygon_area_centroid(cell)
      if area > 10 then
        table.insert(cells, {
          vertices   = cell,
          centroid   = { x = cx, y = cy },
          area       = area,
          vertexData = build_vertex_data(cell, { x = cx, y = cy }),
        })
      end
    end
  end

  -- Collect interior edges (skip edges on the card border)
  local edges    = {}
  local edge_set = {}
  for _, cell in ipairs(cells) do
    local verts = cell.vertices
    local m     = #verts
    for i = 1, m do
      local j  = i % m + 1
      local v1 = verts[i]
      local v2 = verts[j]
      if not (on_boundary(v1.x, v1.y) and on_boundary(v2.x, v2.y)) then
        local mx2 = (v1.x + v2.x) / 2
        local my2 = (v1.y + v2.y) / 2
        local key = math.floor(mx2 + 0.5) .. "," .. math.floor(my2 + 0.5)
        if not edge_set[key] then
          edge_set[key] = true
          table.insert(edges, {
            ax = v1.x, ay = v1.y,
            bx = v2.x, by = v2.y,
            midX = mx2, midY = my2,
            dist = math.sqrt(mx2 * mx2 + my2 * my2),
          })
        end
      end
    end
  end

  table.sort(edges, function(a, b) return a.dist < b.dist end)

  return { shards = cells, edges = edges }
end

-- ── Public: load / pick ───────────────────────────────────────────────────────

function Shatter.load()
  _patterns = {}
  for i = 1, NUM_PATTERNS do
    math.randomseed(PATTERN_SEEDS[i] or (i * 12345))
    table.insert(_patterns, generate_pattern())
  end
  math.randomseed(os.time())
end

function Shatter.pickPattern()
  if #_patterns == 0 then Shatter.load() end
  return _patterns[math.random(#_patterns)]
end

-- ── Effect creation ───────────────────────────────────────────────────────────

function Shatter.newEffect(canvas, pattern, worldX, worldY, cardScale)
  local effect = {
    canvas    = canvas,
    pattern   = pattern,
    worldX    = worldX,
    worldY    = worldY,
    cardScale = cardScale,
    reverse   = false,
    phase     = "growing",
    crackTime = 0,
    fadeTime  = 0,
    shards    = {},
    _crackDone = false,
  }

  -- Pre-compute shard dynamics; physics start when triggerExplode is called
  local totalArea = 0
  for _, s in ipairs(pattern.shards) do totalArea = totalArea + s.area end
  local avgArea = totalArea / math.max(1, #pattern.shards)

  for _, s in ipairs(pattern.shards) do
    local mesh = love.graphics.newMesh(s.vertexData, "fan", "static")
    mesh:setTexture(canvas)

    local wx = worldX + s.centroid.x * cardScale * SCALE_X
    local wy = worldY + s.centroid.y * cardScale * SCALE_Y

    local areaRatio = math.max(0.05, s.area / avgArea)
    local speed = SHARD_SPEED_MIN
      + (SHARD_SPEED_MAX - SHARD_SPEED_MIN) / math.sqrt(areaRatio)
    speed = math.min(speed, SHARD_SPEED_MAX)

    local dir = math.atan2(s.centroid.y, s.centroid.x) + (math.random() - 0.5) * 1.0
    local dragK = 1.5 + 1.5 * math.sqrt(areaRatio)

    table.insert(effect.shards, {
      mesh   = mesh,
      wx     = wx, wy = wy,
      vx     = math.cos(dir) * speed,
      vy     = math.sin(dir) * speed - 100,  -- slight upward burst
      angle  = 0,
      angVel = (math.random() - 0.5) * 8,
      alpha  = 1,
      dragK  = dragK,
    })
  end

  return effect
end

function Shatter.triggerExplode(effect)
  effect.phase    = "exploding"
  effect.fadeTime = 0
end

function Shatter.newReverseEffect(canvas, pattern, worldX, worldY, cardScale)
  local effect = {
    canvas       = canvas,
    pattern      = pattern,
    worldX       = worldX,
    worldY       = worldY,
    cardScale    = cardScale,
    reverse      = true,
    phase        = "assembling",
    assembleTime = 0,
    healTime     = 0,
    shards       = {},
    _assembleDone = false,
  }

  for _, s in ipairs(pattern.shards) do
    local mesh = love.graphics.newMesh(s.vertexData, "fan", "static")
    mesh:setTexture(canvas)

    local targetX = worldX + s.centroid.x * cardScale * SCALE_X
    local targetY = worldY + s.centroid.y * cardScale * SCALE_Y

    -- Blend outward direction (for outer shards) with random (for inner shards)
    local centLen   = math.sqrt(s.centroid.x^2 + s.centroid.y^2)
    local influence = centLen / MAX_CENT_LEN
    local centDirX  = centLen > 1 and s.centroid.x / centLen or 0
    local centDirY  = centLen > 1 and s.centroid.y / centLen or 0
    local randAngle = math.random() * math.pi * 2
    local flyDirX   = centDirX * influence + math.cos(randAngle) * (1 - influence)
    local flyDirY   = centDirY * influence + math.sin(randAngle) * (1 - influence)
    local fLen      = math.sqrt(flyDirX^2 + flyDirY^2)
    if fLen > 0.001 then flyDirX = flyDirX / fLen; flyDirY = flyDirY / fLen end

    local offDist = OFFSCREEN_DIST * (0.8 + 0.4 * math.random())
    -- Outer shards start moving first; inner shards wait proportionally longer
    local delay = (1 - influence) * ASSEMBLE_STAGGER

    table.insert(effect.shards, {
      mesh       = mesh,
      startX     = targetX + flyDirX * offDist,
      startY     = targetY + flyDirY * offDist,
      targetX    = targetX,
      targetY    = targetY,
      wx         = targetX + flyDirX * offDist,
      wy         = targetY + flyDirY * offDist,
      startAngle = (math.random() - 0.5) * math.pi,
      angle      = (math.random() - 0.5) * math.pi,
      delay      = delay,
    })
  end

  -- Map each edge to its nearest shard centroid (for per-shard crack reveal)
  local edgeShardMap = {}
  for ei, edge in ipairs(pattern.edges) do
    local bestIdx  = 1
    local bestDist = math.huge
    for si, s in ipairs(pattern.shards) do
      local dx = edge.midX - s.centroid.x
      local dy = edge.midY - s.centroid.y
      local d  = dx * dx + dy * dy
      if d < bestDist then bestDist = d; bestIdx = si end
    end
    edgeShardMap[ei] = bestIdx
  end
  effect.edgeShardMap = edgeShardMap

  return effect
end

-- ── Update ────────────────────────────────────────────────────────────────────

function Shatter.update(effect, dt)
  if effect.phase == "growing" then
    effect.crackTime = effect.crackTime + dt
    if not effect._crackDone then
      local edges = effect.pattern.edges
      if #edges == 0 then
        effect._crackDone = true
      else
        local last = edges[#edges]
        if effect.crackTime >= last.dist / CRACK_SPEED + CRACK_DRAW_TIME then
          effect._crackDone = true
        end
      end
    end

  elseif effect.phase == "exploding" then
    effect.fadeTime = effect.fadeTime + dt
    local anyAlive = false
    for _, shard in ipairs(effect.shards) do
      if shard.alpha > 0 then
        local k = shard.dragK
        shard.vy    = shard.vy + SHARD_GRAVITY * dt
        shard.vx    = shard.vx * math.exp(-k * dt)
        shard.vy    = shard.vy * math.exp(-k * dt)
        shard.wx    = shard.wx + shard.vx * dt
        shard.wy    = shard.wy + shard.vy * dt
        shard.angVel = shard.angVel * math.exp(-k * dt)
        shard.angle  = shard.angle + shard.angVel * dt
        shard.alpha  = math.max(0, 1 - effect.fadeTime / SHARD_FADE_TIME)
        if shard.alpha > 0 then anyAlive = true end
      end
    end
    if not anyAlive then effect.phase = "done" end

  elseif effect.phase == "assembling" then
    effect.assembleTime = effect.assembleTime + dt
    local allDone = true
    for _, shard in ipairs(effect.shards) do
      local elapsed = math.max(0, effect.assembleTime - shard.delay)
      local t = math.min(1, elapsed / ASSEMBLE_TIME)
      local p = assemble_ease(t)
      shard.wx    = shard.startX + (shard.targetX - shard.startX) * p
      shard.wy    = shard.startY + (shard.targetY - shard.startY) * p
      shard.angle = shard.startAngle * (1 - p)
      if t < 1 then allDone = false end
    end
    if allDone then
      effect._assembleDone = true
      effect.phase         = "healing"
      effect.healTime      = 0
    end

  elseif effect.phase == "healing" then
    effect.healTime = effect.healTime + dt
    if effect.healTime >= HEAL_TIME then
      effect.phase = "done"
    end
  end
end

function Shatter.isCrackDone(effect)
  return effect._crackDone == true
end

function Shatter.isAssembleDone(effect)
  return effect._assembleDone == true
end

function Shatter.isDone(effect)
  return effect.phase == "done"
end

-- ── Draw ──────────────────────────────────────────────────────────────────────

function Shatter.drawCracks(effect)
  if not effect or effect.phase ~= "growing" then return end

  local wx = effect.worldX
  local wy = effect.worldY
  local sx = effect.cardScale * SCALE_X
  local sy = effect.cardScale * SCALE_Y

  love.graphics.push()
  love.graphics.translate(wx, wy)
  love.graphics.scale(sx, sy)

  for _, edge in ipairs(effect.pattern.edges) do
    local raw      = math.min(1, (effect.crackTime - edge.dist / CRACK_SPEED) / CRACK_DRAW_TIME)
    local progress = raw > 0 and crack_ease(raw) or 0
    if progress > 0 then
      local x1 = edge.midX + (edge.ax - edge.midX) * progress
      local y1 = edge.midY + (edge.ay - edge.midY) * progress
      local x2 = edge.midX + (edge.bx - edge.midX) * progress
      local y2 = edge.midY + (edge.by - edge.midY) * progress

      love.graphics.setLineWidth(CRACK_WIDTH * 1.8 / effect.cardScale)
      love.graphics.setColor(1, 0.45, 0.1, 0.85 * progress)
      love.graphics.line(x1, y1, x2, y2)

      love.graphics.setLineWidth(CRACK_WIDTH * 0.6 / effect.cardScale)
      love.graphics.setColor(1, 0.9, 0.8, 0.9 * progress)
      love.graphics.line(x1, y1, x2, y2)
    end
  end

  love.graphics.setLineWidth(1)
  love.graphics.pop()
  love.graphics.setColor(1, 1, 1, 1)
end

function Shatter.drawShards(effect)
  if not effect then return end
  if effect.phase ~= "exploding" and effect.phase ~= "done" then return end

  for _, shard in ipairs(effect.shards) do
    if shard.alpha > 0.005 then
      love.graphics.push()
      love.graphics.translate(shard.wx, shard.wy)
      love.graphics.rotate(shard.angle)
      love.graphics.scale(effect.cardScale * SCALE_X, effect.cardScale * SCALE_Y)
      love.graphics.setColor(1, 1, 1, shard.alpha)
      love.graphics.draw(shard.mesh)
      love.graphics.pop()
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
end

local ARRIVE_THRESHOLD = 0.75  -- shard t at which its edges start appearing

local function drawAssemblingCracks(effect)
  local edges = effect.pattern.edges
  if #edges == 0 or not effect.edgeShardMap then return end

  -- Per-shard progress snapshot
  local shardT = {}
  for i, shard in ipairs(effect.shards) do
    local elapsed = math.max(0, effect.assembleTime - shard.delay)
    shardT[i] = math.min(1, elapsed / ASSEMBLE_TIME)
  end

  local wx = effect.worldX
  local wy = effect.worldY
  local sx = effect.cardScale * SCALE_X
  local sy = effect.cardScale * SCALE_Y
  local ac = Palette.accent

  love.graphics.push()
  love.graphics.translate(wx, wy)
  love.graphics.scale(sx, sy)

  for ei, edge in ipairs(edges) do
    local t     = shardT[effect.edgeShardMap[ei]] or 0
    local alpha = math.max(0, (t - ARRIVE_THRESHOLD) / (1 - ARRIVE_THRESHOLD))
    if alpha > 0.005 then
      love.graphics.setLineWidth(CRACK_WIDTH * 1.8 / effect.cardScale)
      love.graphics.setColor(ac[1], ac[2], ac[3], (ac[4] or 1) * 0.65 * alpha)
      love.graphics.line(edge.ax, edge.ay, edge.bx, edge.by)

      love.graphics.setLineWidth(CRACK_WIDTH * 0.6 / effect.cardScale)
      love.graphics.setColor(ac[1], ac[2], ac[3], (ac[4] or 1) * alpha)
      love.graphics.line(edge.ax, edge.ay, edge.bx, edge.by)
    end
  end

  love.graphics.setLineWidth(1)
  love.graphics.pop()
end

function Shatter.drawReverseShards(effect)
  if not effect or effect.phase ~= "assembling" then return end

  for _, shard in ipairs(effect.shards) do
    love.graphics.push()
    love.graphics.translate(shard.wx, shard.wy)
    love.graphics.rotate(shard.angle)
    love.graphics.scale(effect.cardScale * SCALE_X, effect.cardScale * SCALE_Y)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(shard.mesh)
    love.graphics.pop()
  end

  drawAssemblingCracks(effect)
  love.graphics.setColor(1, 1, 1, 1)
end

function Shatter.drawHealingCracks(effect)
  if not effect or effect.phase ~= "healing" then return end

  local edges = effect.pattern.edges
  if #edges == 0 then return end

  local wx       = effect.worldX
  local wy       = effect.worldY
  local sx       = effect.cardScale * SCALE_X
  local sy       = effect.cardScale * SCALE_Y
  local maxDist  = edges[#edges].dist
  local fadeZone = maxDist * 0.25

  -- Closure front sweeps from outside inward as healTime progresses
  local closureDist = (1 - effect.healTime / HEAL_TIME) * maxDist

  local ac = Palette.accent

  love.graphics.push()
  love.graphics.translate(wx, wy)
  love.graphics.scale(sx, sy)

  for _, edge in ipairs(edges) do
    local alpha
    if edge.dist > closureDist + fadeZone then
      alpha = 0
    elseif edge.dist > closureDist then
      alpha = 1 - (edge.dist - closureDist) / fadeZone
    else
      alpha = 1
    end

    if alpha > 0.005 then
      love.graphics.setLineWidth(CRACK_WIDTH * 1.8 / effect.cardScale)
      love.graphics.setColor(ac[1], ac[2], ac[3], (ac[4] or 1) * 0.65 * alpha)
      love.graphics.line(edge.ax, edge.ay, edge.bx, edge.by)

      love.graphics.setLineWidth(CRACK_WIDTH * 0.6 / effect.cardScale)
      love.graphics.setColor(ac[1], ac[2], ac[3], (ac[4] or 1) * alpha)
      love.graphics.line(edge.ax, edge.ay, edge.bx, edge.by)
    end
  end

  love.graphics.setLineWidth(1)
  love.graphics.pop()
  love.graphics.setColor(1, 1, 1, 1)
end

return Shatter
