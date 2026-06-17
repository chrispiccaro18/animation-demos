local AssetManifest = require("assets.manifest")
local animation         = require("lib.animation")

local W                 = SCALE_X * 3840
local H                 = SCALE_Y * 2160

local areas             = {}

local playDiscardGap = 250 * SCALE_X

areas.play              = {
  x = 1,
  y = 1,
  w = W / 2 - playDiscardGap,
  h = H * 0.6,
  color = { 0.5, 0.5, 0.5, 1 },
  slotText = "",
}

areas.discard           = {
  x        = W / 2 + playDiscardGap,
  startY   = 1,
  w        = W / 2 - playDiscardGap,
  h        = H * 0.6,
  color    = { 0.5, 0.5, 0.5, 1 },
  slotText = "",
  current  = { y = 1 },
  target   = { y = 1 },
}

areas.progressDestination = {
  x = 436 * SCALE_X,
  y = 142 * SCALE_Y,
}

areas.threatDestination = {
  x = 3333 * SCALE_X,
  y = 142 * SCALE_Y,
}

areas.desk = {
  x = 241 * SCALE_X,
  y = 305 * SCALE_Y,
  w = 3268 * SCALE_X,
  h = 1684 * SCALE_Y,
}

areas.progressBar = {
  x = 873 * SCALE_X,
  y = 73 * SCALE_Y,
  w = 38 * SCALE_X,
  h = 138 * SCALE_Y,
  gapX = 64 * SCALE_X,
  asset = nil,
  count = 9,
  max = 10,
  popScale = 1.0,
  textArea = {
    x = 522 * SCALE_X,
    y = 120 * SCALE_Y,
    w = 291 * SCALE_X,
    h = 66 * SCALE_Y,
    value = ""
  },
}

areas.threatBar = {
  x = 2320 * SCALE_X,
  y = 73 * SCALE_Y,
  w = 38 * SCALE_X,
  h = 138 * SCALE_Y,
  gapX = 64 * SCALE_X,
  asset = nil,
  count = 9,
  max = 10,
  popScale = 1.0,
  textArea = {
    x = 2997 * SCALE_X,
    y = 110 * SCALE_Y,
    w = 291 * SCALE_X,
    h = 66 * SCALE_Y,
    value = ""
  },
}


areas.endTurn           = {
  x = 3136 * SCALE_X,
  y = 1732 * SCALE_Y,
  w = 614 * SCALE_X,
  h = 229 * SCALE_Y,
  color = { 1, 0, 0, 1 },
  baseAsset = nil,
  hoverAsset = nil,
  clickAsset = nil,
  state = "idle", -- "idle", "hover", "click"
  hover = {
    can = true,
    is = false,
  },
  click = {
    can = false,
    is = false,
  },
  frozen = false,
}

areas.pool              = {
  x = 0,
  y = 0,
  w = playDiscardGap * 2,
  h = 800 * SCALE_Y,
  chips = {}
}
areas.message           = { text = "", subtitle = "", textColor = { 1, 1, 1, 1 }, subtitleColor = { 1, 1, 1, 0.7 }, current = { scale = 1 }, target = { scale = 1 } }


local endTurnAsset      = nil
local endTurnHoverAsset = nil
local endTurnClickAsset = nil

local statFont          = nil
local messageFont       = nil

local ramTokenAsset        = nil

local subtitleFont         = nil

function areas.load()
  endTurnAsset             = AssetManifest.get("endTurn", "idle")
  endTurnHoverAsset        = AssetManifest.get("endTurn", "hover")
  endTurnClickAsset        = AssetManifest.get("endTurn", "down")

  areas.progressBar.asset = AssetManifest.get("ticks", "progress")
  areas.threatBar.asset = AssetManifest.get("ticks", "threat")
  ramTokenAsset              = AssetManifest.get("tokens", "ram")

  areas.endTurn.baseAsset  = endTurnAsset
  areas.endTurn.hoverAsset = endTurnHoverAsset
  areas.endTurn.clickAsset = endTurnClickAsset

  statFont                 = AssetManifest.getFont(72)
  messageFont              = AssetManifest.getFont(240)
  subtitleFont             = AssetManifest.getFont(120)

  local dk = areas.desk
  areas.scanner = {
    left = {
      x1 = dk.x, x2 = dk.x + dk.w / 2,
      y = dk.y, direction = 1,
      speed = 3000 * SCALE_Y,
      active = false,
      color = { 0, 1, 0.4 },
      trailLength = 1000 * SCALE_Y,
      segments = 48,
    },
    right = {
      x1 = dk.x + dk.w / 2, x2 = dk.x + dk.w,
      y = dk.y, direction = 1,
      speed = 3000 * SCALE_Y,
      active = false,
      color = { 1, 0.2, 0.2 },
      trailLength = 1000 * SCALE_Y,
      segments = 48,
    },
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

  areas.pool.x       = (W - areas.pool.w) / 2
  areas.pool.y       = 500 * SCALE_Y
end

function areas.addPoolChip(x, y)
  table.insert(areas.pool.chips, { x = x, y = y })
end

function areas.consumePoolChips(n)
  local consumed = {}
  for i = 1, n do
    consumed[i] = table.remove(areas.pool.chips)
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
          love.graphics.line(s.x1, ty, s.x2, ty)
        end
      end
      love.graphics.setColor(s.color[1], s.color[2], s.color[3], 0.2)
      love.graphics.setLineWidth(8 * SCALE_Y)
      love.graphics.line(s.x1, s.y, s.x2, s.y)
      love.graphics.setColor(s.color[1], s.color[2], s.color[3], 0.55)
      love.graphics.setLineWidth(4 * SCALE_Y)
      love.graphics.line(s.x1, s.y, s.x2, s.y)
      love.graphics.setColor(s.color[1], s.color[2], s.color[3], 1)
      love.graphics.setLineWidth(1.5 * SCALE_Y)
      love.graphics.line(s.x1, s.y, s.x2, s.y)
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
      return true
      -- sequences.endTurn()
    elseif not love.mouse.isDown(1) and et.hover.can then
      et.state = "hover"
      et.hover.is = true
      et.hover.can = false
      et.click.can = true
      return false
    end
  else
    et.state = "idle"
    et.hover.is = false
    et.hover.can = true
    et.click.is = false
    et.click.can = false
    return false
  end
end

function areas.updateMessage(dt)
  local msg = areas.message
  msg.current.scale = animation.expDecay(msg.current.scale, msg.target.scale, 18, dt)
end

function areas.triggerBarPop(bar)
  local peak = 1.0 + 0.6 * (bar.count / bar.max)
  bar.popScale = peak
end

function areas.updateBars(dt)
  areas.progressBar.popScale = animation.expDecay(areas.progressBar.popScale, 1.0, 10, dt)
  areas.threatBar.popScale   = animation.expDecay(areas.threatBar.popScale,   1.0, 10, dt)
end

function areas.update(mouseX, mouseY)
end

-- Hit detection

function areas.mouseInPlay(x, y)
  local a = areas.play
  return x >= a.x and x <= a.x + a.w and y >= a.y and y <= a.y + a.h
end

function areas.mouseInDiscard(x, y)
  local a = areas.discard
  return x >= a.x and x <= a.x + a.w and y >= a.startY and y <= a.startY + a.h
end

function areas.mouseInEndTurn(x, y)
  local a = areas.endTurn
  return x >= a.x and x <= a.x + a.w and y >= a.y and y <= a.y + a.h
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

-- Draw helpers
function areas.drawStatic()
  local p = areas.play
  local d = areas.discard
  local et = areas.endTurn

  love.graphics.setColor(1, 1, 1, 1)
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
  love.graphics.setColor(1, 1, 1, 1)

  if areas.progressBar.asset then
    local pb = areas.progressBar
    local aw = pb.w / SCALE_X
    local ah = pb.h / SCALE_Y
    for i = 0, pb.count - 1 do
      local s = (i == pb.count - 1) and pb.popScale or 1.0
      local cx = pb.x + i * pb.gapX + pb.w / 2
      local cy = pb.y + pb.h / 2
      love.graphics.draw(pb.asset, cx, cy, 0, SCALE_X * s, SCALE_Y * s, aw / 2, ah / 2)
    end
  end

  if areas.threatBar.asset then
    local tb = areas.threatBar
    local aw = tb.w / SCALE_X
    local ah = tb.h / SCALE_Y
    for i = 0, tb.count - 1 do
      local s = (i == tb.count - 1) and tb.popScale or 1.0
      local cx = tb.x + i * tb.gapX + tb.w / 2
      local cy = tb.y + tb.h / 2
      love.graphics.draw(tb.asset, cx, cy, 0, SCALE_X * s, SCALE_Y * s, aw / 2, ah / 2)
    end
  end

  if areas.progressBar.textArea.value ~= "" then
    love.graphics.setColor(1, 1, 1, 1)
    local prevFont = love.graphics.getFont()
    if statFont then love.graphics.setFont(statFont) end
    local progressCount = areas.progressBar.count
    areas.progressBar.textArea.value = string.format("%02d/%02d", progressCount, areas.progressBar.max)
    love.graphics.printf(
      areas.progressBar.textArea.value,
      areas.progressBar.textArea.x,
      areas.progressBar.textArea.y,
      areas.progressBar.textArea.w,
      "right"
    )
    love.graphics.setFont(prevFont)
  end

  if areas.threatBar.textArea.value ~= "" then
    love.graphics.setColor(1, 1, 1, 1)
    local prevFont = love.graphics.getFont()
    if statFont then love.graphics.setFont(statFont) end
    local threatCount = areas.threatBar.count
    areas.threatBar.textArea.value = string.format("%02d/%02d", threatCount, areas.threatBar.max)
    love.graphics.printf(
      areas.threatBar.textArea.value,
      areas.threatBar.textArea.x,
      areas.threatBar.textArea.y,
      areas.threatBar.textArea.w,
      "left"
    )
    love.graphics.setFont(prevFont)
  end

  -- love.graphics.setColor({ 0, 0, 1, 1})
  -- love.graphics.rectangle("line", areas.playDeskArea.x, areas.playDeskArea.y, areas.playDeskArea.w, areas.playDeskArea.h)
  -- love.graphics.setColor(1, 1, 1, 1)
  -- love.graphics.setColor({1, 0, 0, 1})
  -- love.graphics.rectangle("line", areas.discardDeskArea.x, areas.discardDeskArea.y, areas.discardDeskArea.w, areas.discardDeskArea.h)
  -- love.graphics.setColor(1, 1, 1, 1)

  -- love.graphics.setColor(p.color)
  -- love.graphics.rectangle("line", p.x, p.y, p.w, p.h)
  -- love.graphics.setColor(1, 1, 1, 1)
  -- love.graphics.setColor(d.color)
  -- love.graphics.rectangle("line", d.x, d.startY, d.w, d.h)
  -- love.graphics.setColor(1, 1, 1, 1)

  local po = areas.pool
  -- love.graphics.setColor(0.5, 0.5, 0.5, 1)
  -- love.graphics.rectangle("line", po.x, po.y, po.w, po.h)
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

  -- love.graphics.rectangle("line", areas.desk.x, areas.desk.y, areas.desk.w, areas.desk.h)

  if messageFont and areas.message.text ~= "" then
    local msg      = areas.message
    local s        = msg.current.scale
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(messageFont)
    local textW = messageFont:getWidth(msg.text)
    local textH = messageFont:getHeight()
    love.graphics.push()
    love.graphics.translate(W / 2, H / 2)
    love.graphics.scale(s, s)
    love.graphics.setColor(msg.textColor)
    love.graphics.print(msg.text, -textW / 2, -textH / 2)
    if subtitleFont and msg.subtitle ~= "" then
      love.graphics.setFont(subtitleFont)
      local subW = subtitleFont:getWidth(msg.subtitle)
      love.graphics.setColor(msg.subtitleColor)
      love.graphics.print(msg.subtitle, -subW / 2, textH / 2 + 20)
    end
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(prevFont)
  end
end


return areas
