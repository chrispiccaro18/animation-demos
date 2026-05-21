local animation = require("lib.animation")

local W = love.graphics.getWidth()
local H = love.graphics.getHeight()

local areas = {}

areas.play = {
  x = 1, y = 1,
  w = W / 2 - 82,
  h = H / 2,
  color = {0.5, 0.5, 0.5, 1},
  slotText = "",
}

areas.discard = {
  x = W / 2 + 81,
  startY = 1,
  w = W / 2 - 82,
  h = H / 2,
  color = {0.5, 0.5, 0.5, 1},
  slotText = "",
  current = { y = 1 },
  target  = { y = 1 },
}

areas.endTurn = {
  x = W - 305 - 30,
  y = H - 118 - 30,
  w = 305,
  h = 118,
  color = {1, 0, 0, 1},
  baseAsset = nil,
  hoverAsset = nil,
  clickAsset = nil,
  state = "idle" -- "idle", "hover", "click"
}

areas.destructor = {
  x = W - 305 - 60,
  y = 200,
  w = 305,
  h = 300,
  -- color = {1, 0, 0, 1},
}
areas.ram      = { value = 1, x = 0, y = 0, w = 0, h = 0, current = { scale = 1 }, target = { scale = 1 } }
areas.pool     = { x = 0, y = 0, w = 150, h = 140, chips = {} }
areas.progress = { value = 0, x = 0, y = 0, w = 0, h = 0, current = { scale = 1 }, target = { scale = 1 } }
areas.threat   = { value = 0, x = 0, y = 0, w = 0, h = 0, current = { scale = 1 }, target = { scale = 1 } }
areas.message  = { text = "", textColor = {1, 1, 1, 1}, current = { scale = 1 }, target = { scale = 1 } }

local slotBottomAsset = nil
local slotTopAsset    = nil
local playTextObject  = nil
local discardTextObject = nil
local textObjectScale = 1
local endTurnAsset  = nil
local endTurnHoverAsset = nil
local endTurnClickAsset = nil
local ramAsset      = nil
local ramTinyAsset  = nil
local progressAsset = nil
local threatAsset   = nil
local statFont      = nil
local messageFont   = nil

local klakAsset = nil
local klakBGAsset = nil

function areas.load()
  slotBottomAsset   = love.graphics.newImage("assets/slot-bottom.png")
  slotTopAsset      = love.graphics.newImage("assets/slot-top.png")
  endTurnAsset      = love.graphics.newImage("assets/kilo-end-turn.png")
  endTurnHoverAsset = love.graphics.newImage("assets/kilo-end-turn-hover.png")
  endTurnClickAsset = love.graphics.newImage("assets/kilo-end-turn-click.png")

  areas.endTurn.baseAsset  = endTurnAsset
  areas.endTurn.hoverAsset = endTurnHoverAsset
  areas.endTurn.clickAsset = endTurnClickAsset

  ramAsset          = love.graphics.newImage("assets/large-ram.png")
  ramTinyAsset      = love.graphics.newImage("assets/ram-chip.png")
  progressAsset     = love.graphics.newImage("assets/new-progress.png")
  -- progressAsset     = love.graphics.newImage("assets/progress.png")
  threatAsset       = love.graphics.newImage("assets/new-threat.png")
  -- threatAsset       = love.graphics.newImage("assets/threat.png")
  statFont          = love.graphics.newFont("assets/NotoSans-Medium.ttf", 36)
  messageFont       = love.graphics.newFont("assets/NotoSans-Medium.ttf", 120)

  klakAsset       = love.graphics.newImage("assets/klak.png")
  klakBGAsset     = love.graphics.newImage("assets/klak-bg.png")

  local klakBGW = klakBGAsset:getWidth()
  local klakBGH = klakBGAsset:getHeight()
  local klakW = klakAsset:getWidth()
  local klakH = klakAsset:getHeight()

  areas.klakBG = {
    x = areas.discard.x + areas.discard.w / 2 - klakBGW / 2,
    -- x = areas.endTurn.x + areas.endTurn.w / 2 - klakBGW / 2,
    -- x = W / 2 + W / 4 - klakBGW / 2,
    -- y = H / 2 - klakBGH / 2 - 65,
    y = areas.pool.h + klakH / 2,
    w = klakBGW,
    h = klakBGH,
  }

  areas.klak = {
    w = klakW,
    h = klakH,
    upY = areas.klakBG.y - klakH / 2,
    downY = areas.klakBG.y + areas.klakBG.h - klakH / 2,
    current = {
      x = areas.klakBG.x + areas.klakBG.w / 2 - klakW / 2,
      y = areas.klakBG.y - klakH / 2,
      scale = 1,
    },
    target = {
      x = areas.klakBG.x + areas.klakBG.w / 2 - klakW / 2,
      y = areas.klakBG.y - klakH / 2,
      scale = 1,
    },
    text = {
      xOffset = 22,
      yOffset = 19,
      w = 308,
      h = 48,
      value = "DISCARD",
      color = {1, 1, 1, 1},
    }
  }

  areas.playKlakBG = {
    x = areas.play.x + areas.play.w / 2 - klakBGW / 2,
    -- x = W / 2 + W / 4 - klakBGW / 2,
    y = areas.pool.h + klakH / 2,
    -- y = H / 2 - klakBGH / 2 - 65,
    w = klakBGW,
    h = klakBGH,
  }

  areas.playKlak = {
    w = klakW,
    h = klakH,
    upY = areas.playKlakBG.y - klakH / 2,
    downY = areas.playKlakBG.y + areas.playKlakBG.h - klakH / 2,
    current = {
      x = areas.playKlakBG.x + areas.playKlakBG.w / 2 - klakW / 2,
      y = areas.playKlakBG.y - klakH / 2,
      scale = 1,
    },
    target = {
      x = areas.playKlakBG.x + areas.playKlakBG.w / 2 - klakW / 2,
      y = areas.playKlakBG.y - klakH / 2,
      scale = 1,
    },
    text = {
      xOffset = 22,
      yOffset = 19,
      w = 308,
      h = 48,
      value = "PLAY",
      color = {1, 1, 1, 1},
    }
  }

  areas.discard.h = areas.klakBG.y + areas.klakBG.h
  areas.play.h = areas.playKlakBG.y + areas.playKlakBG.h


  areas.ram.w = ramAsset:getWidth()
  areas.ram.h = ramAsset:getHeight()
  areas.ram.x = (W - areas.ram.w) / 2
  areas.ram.y = 2

  areas.pool.x = (W - areas.pool.w) / 2
  areas.pool.y = 1
  -- areas.pool.y = H * 0.55

  areas.progress.w = progressAsset:getWidth()
  areas.progress.h = progressAsset:getHeight()
  areas.progress.x = areas.play.x + areas.play.w / 2 - areas.progress.w / 2
  areas.progress.y = areas.play.y + 20
  -- areas.progress.x = W / 2 - areas.progress.w - 5
  -- areas.progress.y = H / 2 - areas.progress.h / 2

  areas.threat.w = threatAsset:getWidth()
  areas.threat.h = threatAsset:getHeight()
  areas.threat.x = areas.discard.x + areas.discard.w / 2 - areas.threat.w / 2
  areas.threat.y = areas.discard.startY + 20
  -- areas.threat.x = W / 2 + 5
  -- areas.threat.y = H / 2 - areas.threat.h / 2

  local font        = love.graphics.newFont("assets/NotoSans-Medium.ttf", 40)
  playTextObject    = love.graphics.newText(font, "PLAY")
  discardTextObject = love.graphics.newText(font, "DISCARD")

  local pos1x, pos1y = areas.randomPoolPosition()
  local pos2x, pos2y = areas.randomPoolPosition()
  areas.addPoolChip(pos1x, pos1y)
  areas.addPoolChip(pos2x, pos2y)
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

function areas.randomPoolPosition()
  local p = areas.pool
  local pad = 8
  return
    p.x + pad + math.random() * (p.w - pad * 2),
    p.y + pad + math.random() * (p.h - pad * 2)
end

function areas.update(mouseX, mouseY)
  if areas.endTurn.state == "click" then
    -- no-op
  elseif areas.mouseInEndTurn(mouseX, mouseY) then
    areas.endTurn.state = "hover"
  else
    areas.endTurn.state = "idle"
  end

  areas.discard.current.y = animation.expDecay(areas.discard.current.y, areas.discard.target.y, 10, realDt)
  local ra = areas.ram
  ra.current.scale = animation.expDecay(ra.current.scale, ra.target.scale, 8, realDt)
  local pr = areas.progress
  pr.current.scale = animation.expDecay(pr.current.scale, pr.target.scale, 8, realDt)
  local th = areas.threat
  th.current.scale = animation.expDecay(th.current.scale, th.target.scale, 8, realDt)
  local msg = areas.message
  msg.current.scale = animation.expDecay(msg.current.scale, msg.target.scale, 8, realDt)

  local klak = areas.klak
  klak.current.x = animation.expDecay(klak.current.x, klak.target.x, 20, realDt)
  klak.current.y = animation.expDecay(klak.current.y, klak.target.y, 20, realDt)
  klak.current.scale = animation.expDecay(klak.current.scale, klak.target.scale, 20, realDt)

  local playKlak = areas.playKlak
  playKlak.current.x = animation.expDecay(playKlak.current.x, playKlak.target.x, 20, realDt)
  playKlak.current.y = animation.expDecay(playKlak.current.y, playKlak.target.y, 20, realDt)
  playKlak.current.scale = animation.expDecay(playKlak.current.scale, playKlak.target.scale, 20, realDt)
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

local function drawSlotTops()
  if not slotTopAsset then return end
  local p = areas.play
  local d = areas.discard
  local deg180 = animation.degreesToRadians(180)

  -- love.graphics.draw(slotTopAsset, p.x + (p.w - slotTopAsset:getWidth()) / 2, p.y)
  -- -- love.graphics.draw(slotTopAsset, d.x + (d.w - slotTopAsset:getWidth()) / 2, d.current.y)
  -- love.graphics.setColor(0, 0, 0, 1)
  -- love.graphics.printf(p.slotText, p.x, p.y + 10, p.w, "center")
  -- -- love.graphics.printf(d.slotText, d.x, d.current.y + 10, d.w, "center")
  -- love.graphics.setColor(1, 1, 1, 1)
  -- love.graphics.draw(
  --   slotTopAsset,
  --   d.x + (d.w - slotTopAsset:getWidth()) / 2,
  --   love.graphics.getHeight() - slotTopAsset:getHeight(),
  --   deg180, 1, 1,
  --   slotTopAsset:getWidth(), slotTopAsset:getHeight()
  -- )
  if klakAsset then
    local klak = areas.klak
    love.graphics.draw(klakAsset, klak.current.x, klak.current.y, 0, klak.current.scale, klak.current.scale)
    love.graphics.setColor(klak.text.color)
    local previousFont = love.graphics.getFont()
    if statFont then love.graphics.setFont(statFont) end
    love.graphics.printf(
      klak.text.value,
      klak.current.x + klak.text.xOffset,
      klak.current.y + klak.text.yOffset,
      klak.text.w,
      "center"
    )

    love.graphics.setColor(1, 1, 1, 1)
    local playKlak = areas.playKlak
    love.graphics.draw(klakAsset, playKlak.current.x, playKlak.current.y, 0, playKlak.current.scale, playKlak.current.scale)
    love.graphics.setColor(playKlak.text.color)
    local previousFont = love.graphics.getFont()
    if statFont then love.graphics.setFont(statFont) end
    love.graphics.printf(
      playKlak.text.value,
      playKlak.current.x + playKlak.text.xOffset,
      playKlak.current.y + playKlak.text.yOffset,
      playKlak.text.w,
      "center"
    )

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(previousFont)
  end

  if statFont then
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(statFont)

    -- if ramAsset then
    --   local ra = areas.ram
    --   love.graphics.push()
    --   love.graphics.translate(ra.x + ra.w / 2, ra.y + ra.h / 2)
    --   love.graphics.scale(ra.current.scale, ra.current.scale)
    --   love.graphics.setColor(1, 1, 1, 1)
    --   love.graphics.draw(ramAsset, -ra.w / 2, -ra.h / 2)
    --   love.graphics.setColor(0, 0, 0, 1)
    --   love.graphics.printf(
    --     tostring(ra.value),
    --     -ra.w / 2,
    --     -ra.h / 2 + (ra.h - statFont:getHeight()) / 2,
    --     ra.w,
    --     "center"
    --   )
    --   love.graphics.pop()
    -- end

    if progressAsset then
      local pr = areas.progress
      love.graphics.push()
      love.graphics.translate(pr.x + pr.w / 2, pr.y + pr.h / 2)
      love.graphics.scale(pr.current.scale, pr.current.scale)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(progressAsset, -pr.w / 2, -pr.h / 2)
      love.graphics.printf(
        tostring(pr.value),
        -pr.w / 2,
        -pr.h / 2 + (pr.h - statFont:getHeight()) / 2,
        pr.w,
        "center"
      )
      love.graphics.pop()
    end

    if threatAsset then
      local th = areas.threat
      love.graphics.push()
      love.graphics.translate(th.x + th.w / 2, th.y + th.h / 2)
      love.graphics.scale(th.current.scale, th.current.scale)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(threatAsset, -th.w / 2, -th.h / 2)
      love.graphics.printf(
        tostring(th.value),
        -th.w / 2,
        -th.h / 2 + (th.h - statFont:getHeight()) / 2,
        th.w,
        "center"
      )
      love.graphics.pop()
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(prevFont)
  end
end

-- Call before drawing cards. Draws area outlines, slot bottoms, and (when dragging)
-- the drop-zone labels and slot tops underneath the card.
function areas.drawBefore(isDragging)
  local p = areas.play
  local d = areas.discard
  local e = areas.endTurn
  local dtor = areas.destructor
  local deg180 = animation.degreesToRadians(180)
  love.graphics.setColor(0.7, 0.7, 0.7, 1)
  -- love.graphics.rectangle("fill", dtor.x, dtor.y, dtor.w, dtor.h)
  love.graphics.setColor(1, 1, 1, 1)

  love.graphics.setColor(p.color)
  love.graphics.rectangle("line", p.x, p.y, p.w, p.h)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setColor(d.color)
  love.graphics.rectangle("line", d.x, d.startY, d.w, d.h)
  love.graphics.setColor(1, 1, 1, 1)
  -- love.graphics.setColor(e.color)
  -- love.graphics.rectangle("line", e.x, e.y, e.w, e.h)
  love.graphics.setColor(1, 1, 1, 1)

  love.graphics.rectangle("line", e.x, e.y, e.w, e.h)


  if e.state == "idle" and endTurnAsset then
    love.graphics.draw(endTurnAsset, e.x, e.y)
  elseif e.state == "hover" and endTurnHoverAsset then
    love.graphics.draw(endTurnHoverAsset, e.x, e.y)
  elseif e.state == "click" and endTurnClickAsset then
    love.graphics.draw(endTurnClickAsset, e.x, e.y)
  end

  if slotBottomAsset then
    -- love.graphics.draw(slotBottomAsset, p.x + (p.w - slotBottomAsset:getWidth()) / 2, p.y)
    -- love.graphics.draw(slotBottomAsset, d.x + (d.w - slotBottomAsset:getWidth()) / 2, d.current.y)
    -- love.graphics.draw(
    --   slotBottomAsset,
    --   d.x + (d.w - slotBottomAsset:getWidth()) / 2,
    --   love.graphics.getHeight() - slotBottomAsset:getHeight(),
    --   deg180, 1, 1,
    --   slotBottomAsset:getWidth(), slotBottomAsset:getHeight()
    -- )
  end

  local po = areas.pool
  love.graphics.setColor(0.5, 0.5, 0.5, 1)
  love.graphics.rectangle("line", po.x, po.y, po.w, po.h)
  love.graphics.setColor(1, 1, 1, 1)
  if ramTinyAsset then
    for _, chip in ipairs(po.chips) do
      love.graphics.draw(ramTinyAsset, chip.x, chip.y)
    end
  end

  if klakBGAsset then
    local klakBG = areas.klakBG
    love.graphics.draw(klakBGAsset, klakBG.x, klakBG.y)
    local playKlakBG = areas.playKlakBG
    love.graphics.draw(klakBGAsset, playKlakBG.x, playKlakBG.y)
  end

  if isDragging then
    if playTextObject then
      love.graphics.draw(
        playTextObject,
        p.x + p.w - playTextObject:getWidth() * textObjectScale - 10,
        p.y + p.h - playTextObject:getHeight() * textObjectScale - 10,
        0, textObjectScale, textObjectScale
      )
    end
    if discardTextObject then
      love.graphics.draw(
        discardTextObject,
        d.x + 10,
        -- d.x + d.w - discardTextObject:getWidth() * textObjectScale,
        d.current.y + d.h - discardTextObject:getHeight() * textObjectScale - 10,
        0, textObjectScale, textObjectScale
      )
    end
    drawSlotTops()
  end
end

-- Call after drawing cards. Draws slot tops over the card when not dragging.
function areas.drawAfter(isDragging)
  if not isDragging then
    drawSlotTops()
  end
end

function areas.drawStatic()
  if messageFont and areas.message.text ~= "" then
    local msg = areas.message
    local s   = msg.current.scale
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(messageFont)
    local textW = messageFont:getWidth(msg.text)
    local textH = messageFont:getHeight()
    love.graphics.push()
    love.graphics.translate(W / 2, H / 2)
    love.graphics.scale(s, s)
    love.graphics.setColor(msg.textColor)
    love.graphics.print(msg.text, -textW / 2, -textH / 2)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(prevFont)
  end
end

return areas
