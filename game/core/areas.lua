local AssetManifest = require("assets.manifest")
local Audio          = require("assets.audio")
local Palette     = require("lib.palette")
-- local Color      = require("lib.color")
local progressBar = require("core.progressBar")
local threatBar   = require("core.threatBar")
local envEffects  = require("core.envEffects")

local areas = {}

-- Tweakable: post-rejection "Insufficient RAM" display.
-- Text/glow show at full opacity for DISPLAY_TIME, then fade over FADE_TIME.
-- newHand.lua seeds the timer with DISPLAY_TIME + FADE_TIME.
areas.RAM_DISPLAY_TIME = 0.7
areas.RAM_FADE_TIME    = 0.3

-- Scale-dependent layout locals — computed in load() once SCALE_X/Y are final
local W, H, playDiscardGap, dropYExtend

local endTurnAsset      = nil
local endTurnHoverAsset = nil
local endTurnClickAsset = nil
local statFont          = nil
local ramTokenAsset     = nil

-- Pool chip interactivity ------------------------------------------------
-- Toggle CHIP_SPRING_BACK to compare the two feel modes:
--   true  = chips remember their home position and spring back after scattering
--   false = chips bounce off the pool walls and come to rest where they stop
local CHIP_SPRING_BACK  = false
local CHIP_REPEL_RADIUS = 200    -- game u; scales with SCALE_X at runtime
local CHIP_REPEL_FORCE  = 1800   -- game u/s²; acceleration at zero distance
local CHIP_DRAG         = 0.88   -- per-frame @ 60fps
local CHIP_SPRING_K     = 5      -- spring constant (game u / (s² · canvas px displacement))
local POOL_DETECTION_BUFFER = 60 -- design px around pool that detects a hover

function areas.load()
  W              = SCALE_X * 3840
  H              = SCALE_Y * 2160
  playDiscardGap = 250 * SCALE_X
  dropYExtend    = 250 * SCALE_Y

  areas.play = {
    x        = 91 * SCALE_X,
    y        = 303  * SCALE_Y,
    w        = 1591 * SCALE_X,
    h        = 1000 * SCALE_Y,
    -- w        = W / 2 - playDiscardGap,
    -- h        = H * 0.6,
    color    = { 0.5, 0.5, 0.5, 1 },
    slotText = "",
  }

  areas.discard = {
    x        = 2110 * SCALE_X,
    startY   = 303  * SCALE_Y,
    w        = 1591 * SCALE_X,
    h        = 1000 * SCALE_Y,
    -- w        = W / 2 - playDiscardGap,
    -- h        = H * 0.6,
    color    = { 0.5, 0.5, 0.5, 1 },
    slotText = "",
    current  = { y = 1 },
    target   = { y = 1 },
  }

  areas.dtorRow = {
    x = 3430 * SCALE_X,
    y = 1200 * SCALE_Y,
    asset = AssetManifest.get("board", "dtorRow")
  }

  areas.leftLine = {
    x1 = 230 * SCALE_X,
    y1 = 309 * SCALE_Y,
    x2 = 94 * SCALE_X,
    y2 = 1974 * SCALE_Y,
    w = 6 * SCALE_X
  }

  areas.rightLine = {
    x1 = 3522 * SCALE_X,
    y1 = 309 * SCALE_Y,
    x2 = 3658 * SCALE_X,
    y2 = 1974 * SCALE_Y,
    w = 6 * SCALE_X
  }

  areas.progressDestination = {
    x = 436 * SCALE_X,
    y = 142 * SCALE_Y,
  }

  areas.threatDestination = {
    x = 3333 * SCALE_X,
    y = 142  * SCALE_Y,
  }

  areas.desk = {
    x = 241  * SCALE_X,
    y = 305  * SCALE_Y,
    w = 3268 * SCALE_X,
    h = 1684 * SCALE_Y,
  }

  progressBar.load()
  threatBar.load()
  envEffects.load(areas.leftLine)
  envEffects.register(1, 2, progressBar.getCount, { effects = { { type = "drawToHand" } } })
  envEffects.register(2, 6, progressBar.getCount, { effects = { { type = "ram" } } })

  areas.endTurn = {
    x          = 3136 * SCALE_X,
    y          = 1732 * SCALE_Y,
    w          = 614  * SCALE_X,
    h          = 229  * SCALE_Y,
    color      = { 1, 0, 0, 1 },
    baseAsset  = nil,
    hoverAsset = nil,
    clickAsset = nil,
    state      = "idle",
    hover      = { can = true,  is = false },
    click      = { can = false, is = false },
    frozen     = false,
  }

  areas.pool = {
    x                   = 0,
    y                   = 0,
    w                   = playDiscardGap * 2,
    h                   = 800 * SCALE_Y,
    chips               = {},
    showText            = false,
    insufficientRam     = false,
    insufficientRamTimer = 0,
  }

  endTurnAsset             = AssetManifest.get("endTurn", "idle")
  endTurnHoverAsset        = AssetManifest.get("endTurn", "hover")
  endTurnClickAsset        = AssetManifest.get("endTurn", "down")

  ramTokenAsset            = AssetManifest.get("tokens", "ram")

  areas.endTurn.baseAsset  = endTurnAsset
  areas.endTurn.hoverAsset = endTurnHoverAsset
  areas.endTurn.clickAsset = endTurnClickAsset

  statFont     = AssetManifest.getFont(72)

  local scannerSpeed = 4000 * SCALE_Y
  -- local scannerSpeed = 3000 * SCALE_Y

  local dk = areas.desk
  areas.scanner = {
    left = {
      x1          = dk.x,
      x2          = dk.x + dk.w / 2 + (70 * SCALE_X),
      y           = dk.y,
      direction   = 1,
      speed       = scannerSpeed,
      active      = false,
      color       = { 0, 1, 0.4 },
      trailLength = 1000 * SCALE_Y,
      segments    = 48,
      boundX1     = areas.leftLine,
    },
    right = {
      x1          = dk.x + dk.w / 2,
      x2          = dk.x + dk.w,
      y           = dk.y,
      direction   = 1,
      speed       = scannerSpeed,
      active      = false,
      color       = { 1, 0.2, 0.2 },
      trailLength = 1000 * SCALE_Y,
      segments    = 48,
      boundX2     = areas.rightLine,
    },
    both = {
      x1          = dk.x,
      x2          = dk.x + dk.w,
      y           = dk.y,
      direction   = 1,
      speed       = scannerSpeed,
      active      = false,
      color       = { 0.2, 0.8, 1 },
      trailLength = 1000 * SCALE_Y,
      segments    = 48,
      boundX1     = areas.leftLine,
      boundX2     = areas.rightLine,
    }
  }

  areas.discardDeskArea = {
    x = areas.desk.x + areas.desk.w * 0.6,
    y = areas.desk.y + areas.desk.h * 0.25,
    w = areas.desk.w * 0.2,
    h = areas.desk.h * 0.4,
  }

  areas.playDeskArea = {
    x = areas.desk.x + areas.desk.w * 0.1,
    y = areas.desk.y + areas.desk.h * 0.25,
    w = areas.desk.w * 0.2,
    h = areas.desk.h * 0.4,
  }

  areas.flingTarget = {
    x = areas.desk.x + areas.desk.w * 0.1,
    y = areas.desk.y + areas.desk.h * 0.2,
    w = areas.desk.w * 0.6,
    h = areas.desk.h * 0.4,
  }

  areas.pool.x = (W - areas.pool.w) / 2
  areas.pool.y = 500 * SCALE_Y
end

function areas.addPoolChip(x, y)
  table.insert(areas.pool.chips, { x = x, y = y, homeX = x, homeY = y, vx = 0, vy = 0 })
end

function areas.consumePoolChips(n)
  local consumed = {}
  for i = 1, n do
    consumed[i] = table.remove(areas.pool.chips, 1)
  end
  return consumed
end

function areas.updateScanners(dt)
  local top = areas.desk.y
  local bot = areas.desk.y + areas.desk.h
  for _, s in pairs(areas.scanner) do
    if s.active then
      s.y = s.y + s.speed * s.direction * dt
      if s.y >= bot then
        s.y = bot
        s.direction = -1
      elseif s.y <= top and s.direction == -1 then
        s.y = top
        s.direction = 1
        s.active = false
      end
    end
  end
end

local function lineXAtY(line, y)
  local t = (y - line.y1) / (line.y2 - line.y1)
  t = math.max(0, math.min(1, t))
  return line.x1 + t * (line.x2 - line.x1)
end

local function scannerX1(s, y)
  return s.boundX1 and lineXAtY(s.boundX1, y) or s.x1
end

local function scannerX2(s, y)
  return s.boundX2 and lineXAtY(s.boundX2, y) or s.x2
end

function areas.drawScanners()
  local top = areas.desk.y
  local bot = areas.desk.y + areas.desk.h
  for _, s in pairs(areas.scanner) do
    if s.active then
      local step = s.trailLength / s.segments
      for i = 1, s.segments do
        local ty = s.y - s.direction * i * step
        if ty >= top and ty <= bot then
          local alpha = (1 - i / s.segments) * 0.5
          love.graphics.setColor(s.color[1], s.color[2], s.color[3], alpha)
          love.graphics.setLineWidth(2 * SCALE_Y)
          love.graphics.line(scannerX1(s, ty), ty, scannerX2(s, ty), ty)
        end
      end
      local lx1 = scannerX1(s, s.y)
      local lx2 = scannerX2(s, s.y)
      love.graphics.setColor(s.color[1], s.color[2], s.color[3], 0.2)
      love.graphics.setLineWidth(8 * SCALE_Y)
      love.graphics.line(lx1, s.y, lx2, s.y)
      love.graphics.setColor(s.color[1], s.color[2], s.color[3], 0.55)
      love.graphics.setLineWidth(4 * SCALE_Y)
      love.graphics.line(lx1, s.y, lx2, s.y)
      love.graphics.setColor(s.color[1], s.color[2], s.color[3], 1)
      love.graphics.setLineWidth(1.5 * SCALE_Y)
      love.graphics.line(lx1, s.y, lx2, s.y)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.setLineWidth(1)
    end
  end
end

function areas.randomPoolPosition()
  local p = areas.pool
  local pad = 8
  return
      p.x + pad + math.random() * (p.w - pad * 2),
      p.y + pad + math.random() * (p.h - pad * 2)
end

function areas.updateEndTurn(dt, mouseX, mouseY)
  local et = areas.endTurn
  if areas.mouseInEndTurn(mouseX, mouseY) then
    if et.click.can and love.mouse.isDown(1) then
      et.state = "click"
      et.click.is = true
      et.click.can = false
      et.hover.is = false
      et.hover.can = true
      et.frozen = true
      Audio.playClickIn()
      return true
    elseif not love.mouse.isDown(1) and et.hover.can then
      et.state = "hover"
      et.hover.is = true
      et.hover.can = false
      et.click.can = true
      Audio.playPress()
      return false
    end
  else
    if et.state == "click" then
      Audio.playClickOut()
    end
    et.state = "idle"
    et.hover.is = false
    et.hover.can = true
    et.click.is = false
    et.click.can = false
    return false
  end
end

function areas.update(mouseX, mouseY)
end

-- Hit detection

function areas.mouseInPlay(x, y, isTouch)
  local a = areas.play
  local extend = isTouch and dropYExtend or 0
  return x >= a.x and x <= a.x + a.w and y >= a.y and y <= a.y + a.h + extend
end

function areas.mouseInDiscard(x, y, isTouch)
  local a = areas.discard
  local extend = isTouch and dropYExtend or 0
  return x >= a.x and x <= a.x + a.w and y >= a.startY and y <= a.startY + a.h + extend
end

function areas.mouseInEndTurn(x, y)
  local a = areas.endTurn
  return x >= a.x and x <= a.x + a.w and y >= a.y and y <= a.y + a.h
end

function areas.mouseInPool(x, y)
  local p = areas.pool
  return x >= p.x - POOL_DETECTION_BUFFER * SCALE_X
    and x <= p.x + p.w + POOL_DETECTION_BUFFER * SCALE_X
    and y >= p.y - POOL_DETECTION_BUFFER * SCALE_Y
    and y <= p.y + p.h + POOL_DETECTION_BUFFER * SCALE_Y
end

function areas.cardInPlay(card)
  local a = areas.play
  return card.current.x >= a.x and card.current.x + card.w <= a.x + a.w
      and card.current.y >= a.y and card.current.y <= a.y + a.h
end

function areas.cardInDiscard(card)
  local a = areas.discard
  return card.current.x >= a.x and card.current.x + card.w <= a.x + a.w
      and card.current.y >= a.startY and card.current.y <= a.startY + a.h
end

function areas.updatePoolChips(dt, mx, my)
  local p          = areas.pool
  local repelR     = CHIP_REPEL_RADIUS * SCALE_X
  local repelF     = CHIP_REPEL_FORCE  * SCALE_X
  local springK    = CHIP_SPRING_K     * SCALE_X
  local frame_drag = CHIP_DRAG ^ (dt * 60)

  for _, chip in ipairs(p.chips) do
    local dx   = chip.x - mx
    local dy   = chip.y - my
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < repelR and dist > 0.5 then
      local falloff = 1 - dist / repelR
      chip.vx = chip.vx + (dx / dist) * repelF * falloff * dt
      chip.vy = chip.vy + (dy / dist) * repelF * falloff * dt
    end

    if CHIP_SPRING_BACK then
      chip.vx = chip.vx + springK * (chip.homeX - chip.x) * dt
      chip.vy = chip.vy + springK * (chip.homeY - chip.y) * dt
    end

    chip.vx = chip.vx * frame_drag
    chip.vy = chip.vy * frame_drag
    chip.x  = chip.x + chip.vx * dt
    chip.y  = chip.y + chip.vy * dt

    if not CHIP_SPRING_BACK then
      if chip.x < p.x then
        chip.x  = p.x
        chip.vx = math.abs(chip.vx) * 0.5
      elseif chip.x > p.x + p.w then
        chip.x  = p.x + p.w
        chip.vx = -math.abs(chip.vx) * 0.5
      end
      if chip.y < p.y then
        chip.y  = p.y
        chip.vy = math.abs(chip.vy) * 0.5
      elseif chip.y > p.y + p.h then
        chip.y  = p.y + p.h
        chip.vy = -math.abs(chip.vy) * 0.5
      end
    end
  end
end

-- Draw helpers
function areas.drawStatic()
  love.graphics.setColor(1, 1, 1, 1)
  progressBar.draw()
  threatBar.draw()

  local po = areas.pool
  love.graphics.setColor(1, 1, 1, 1)
  if ramTokenAsset then
    for _, chip in ipairs(po.chips) do
      love.graphics.draw(
        ramTokenAsset,
        chip.x,
        chip.y,
        0,
        SCALE_X * 0.3,
        SCALE_Y * 0.3,
        ramTokenAsset:getWidth() / 2,
        ramTokenAsset:getHeight() / 2
      )
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

function areas.drawDynamic()
  if areas.pool.showText then
    love.graphics.setColor(Palette.energy)
    if areas.pool.insufficientRam then
      love.graphics.setColor(Palette.warning)
    end
    local previousFont = love.graphics.getFont()
    love.graphics.setFont(statFont)
    love.graphics.printf(
      "RAM: " .. tostring(#areas.pool.chips),
      areas.pool.x,
      areas.pool.y + areas.pool.h / 4,
      areas.pool.w,
      "center"
    )
    if areas.pool.insufficientRam then
      love.graphics.setColor(Palette.warning)
      love.graphics.printf(
        "INSUFFICIENT",
        areas.pool.x,
        areas.pool.y + areas.pool.h / 4 - 100 * SCALE_Y,
        areas.pool.w,
        "center"
      )
    end
    love.graphics.setColor(1, 1, 1, 1)


    love.graphics.printf(
      "PLAY",
      areas.play.x - 20 * SCALE_X,
      areas.play.y + areas.play.h - 120 * SCALE_Y,
      areas.play.w,
      "right"
    )
    love.graphics.printf(
      "DISCARD",
      areas.discard.x + 20 * SCALE_X,
      areas.discard.startY + areas.discard.h - 120 * SCALE_Y,
      areas.discard.w,
      "left"
    )
    love.graphics.setFont(previousFont)
  elseif areas.pool.insufficientRamTimer > 0 then
    local fadeAlpha   = math.min(1.0, areas.pool.insufficientRamTimer / areas.RAM_FADE_TIME)
    local previousFont = love.graphics.getFont()
    love.graphics.setFont(statFont)
    local ec = Palette.warning
    love.graphics.setColor(ec[1], ec[2], ec[3], fadeAlpha)
    love.graphics.printf(
      "RAM: " .. tostring(#areas.pool.chips),
      areas.pool.x,
      areas.pool.y + areas.pool.h / 4,
      areas.pool.w,
      "center"
    )
    local wc = Palette.warning
    love.graphics.setColor(wc[1], wc[2], wc[3], fadeAlpha)
    love.graphics.printf(
      "INSUFFICIENT",
      areas.pool.x,
      areas.pool.y + areas.pool.h / 4 - 100 * SCALE_Y,
      areas.pool.w,
      "center"
    )
    love.graphics.setFont(previousFont)
  end
  love.graphics.setColor(1, 1, 1, 1)

  if areas.dtorRow.asset then
    love.graphics.draw(
      areas.dtorRow.asset,
      areas.dtorRow.x,
      areas.dtorRow.y,
      0,
      SCALE_X,
      SCALE_Y,
      areas.dtorRow.asset:getWidth() / 2,
      areas.dtorRow.asset:getHeight() / 2
    )
  end
  local et = areas.endTurn

  if et.state == "idle" and endTurnAsset then
    love.graphics.draw(endTurnAsset, et.x, et.y, 0, SCALE_X, SCALE_Y)
  elseif et.state == "hover" and endTurnHoverAsset then
    love.graphics.draw(endTurnHoverAsset, et.x, et.y, 0, SCALE_X, SCALE_Y)
  elseif et.state == "click" and endTurnClickAsset then
    love.graphics.draw(endTurnClickAsset, et.x, et.y, 0, SCALE_X, SCALE_Y)
  else
    love.graphics.setColor(et.color)
    love.graphics.rectangle("line", et.x, et.y, et.w, et.h)
  end

  envEffects.draw()
  love.graphics.setColor(1, 1, 1, 1)
end


return areas
