local events        = require("lib.events")
local projectiles   = require("core.projectiles")

local sequences = {}

local function checkWin(areas)
  return areas.progress.value == 2
end

local function checkLoss(areas)
  return areas.threat.value == 2
end

function sequences.ejectCard(card, areas)
  events.push({
    fn = function()
      card.target.y = card.current.y - 30
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after",
  })
  events.push({
    fn = function()
      card.target.y = card._startY
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after",
  })
  events.push({
    fn = function()
      card.hover.can = true
      card.drag.can  = true
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })
end

function sequences.ejectFromDiscard(card, areas)
  local p = areas.play
  local d = areas.discard

  events.push({
    fn = function()
      d.target.y = d.startY
      card.target.y = d.startY
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.7, type = "after",
  })
  events.push({
    fn = function()
      card.target.y = card.current.y - 270
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.65, type = "after",
  })
  events.push({
    fn = function()
      card.asset = card.assets.default
      card.target.y = d.startY
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.65, type = "after",
  })
  events.push({
    fn = function()
      card.target.y = card.current.y - 30
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after",
  })
  events.push({
    fn = function()
      d.slotText = ""
      card.target.y = card._startY
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.055, type = "after",
  })
  events.push({
    fn = function()
      card.target.x = p.x + (p.w - card.w) / 2
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after",
  })
  events.push({
    fn = function()
      card.hover.can = true
      card.drag.can  = true
    end,
    blocking = true, blockable = true, persistent = true,
    delay = 0, type = "immediate",
  })
end

function sequences.win(card, areas)
  areas.message.textColor = {0, 1, 0, 1}
  areas.message.text = "WIN"
  areas.message.current.scale = 4
  areas.message.target.scale  = 1.0
end

function sequences.loss(card, areas)
  areas.message.textColor = {1, 0, 0, 1}
  areas.message.text = "LOSS"
  areas.message.current.scale = 4
  areas.message.target.scale  = 1.0
end

function sequences.play(card, areas)
  local p = areas.play

  events.push({
    fn = function()
      card.hover.is = false
      card.hover.can = false
      card.drag.is   = false
      card.drag.can  = false
      card.target.scale = 0.95
      card.target.x = p.x + (p.w - card.w) / 2
      card.target.y = p.y + (p.h - card.h / 2)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  events.push({
    fn = function()
      card.target.y = p.y + (p.h - card.h / 2) + 30
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after",
  })
  events.push({
    fn = function()
      card.target.x = p.x + (p.w - card.w) / 2
      card.target.y = p.y
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
    events.push({
    fn = function()
      areas.ram.value = areas.ram.value - 1
      projectiles.ram:launch(
        areas.ram.x + areas.ram.w / 2,
        areas.ram.y + areas.ram.h / 2,
        p.x + p.w / 2,
        areas.ram.y + areas.ram.h / 2,
        "1"
      )
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  events.push({
    fn = function()
      card.target.scale = 1.2
      p.slotText = "+1 Progress"
      projectiles.ram:hide()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  events.push({
    fn = function()
      card.target.scale = 0.95
      projectiles.progress:launch(
        p.x + p.w / 2,
        areas.ram.y + areas.ram.h / 2,
        areas.progress.x + areas.progress.w / 2,
        areas.progress.y + areas.progress.h / 2,
        "1"
      )
      p.slotText = ""
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })
  events.push({
    fn = function()
      return projectiles.progress:isNearTarget()
    end,
    blocking = true, blockable = true, persistent = false,
    type = "poll",
  })
  events.push({
    fn = function()
      projectiles.progress:hide()
      areas.progress.current.scale = 1.4
      areas.progress.value = areas.progress.value + 1
      if checkWin(areas) then
        sequences.win(card, areas)
      elseif checkLoss(areas) then
        sequences.loss(card, areas)
      else
        sequences.ejectCard(card, areas)
      end
    end,
    blocking = true, blockable = true, persistent = false,
    type = "immediate",
  })
end

function sequences.discard(card, areas)
  local p = areas.play
  local d = areas.discard

  events.push({
    fn = function()
      card.hover.is = false
      card.hover.can = false
      card.drag.is   = false
      card.drag.can  = false
      card.target.scale = 0.95
      card.target.x = d.x + (d.w - card.w) / 2
      card.target.y = d.startY + (d.h - card.h / 2)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  events.push({
    fn = function()
      card.target.y = d.startY + (d.h - card.h / 2) + 30
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after",
  })
  events.push({
    fn = function()
      card.target.x = d.x + (d.w - card.w) / 2
      card.target.y = d.startY
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  events.push({
    fn = function()
      card.target.scale = 1.2
      card.asset = card.assets.chomped
      d.slotText = "+1 RAM"
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  events.push({
    fn = function()
      projectiles.ram:launch(
        d.x + d.w / 2,
        areas.ram.y + areas.ram.h / 2,
        areas.ram.x + areas.ram.w / 2,
        areas.ram.y + areas.ram.h / 2,
        "1"
      )
      card.target.scale = 0.95
      d.slotText = ""
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })
  events.push({
    fn = function()
      return projectiles.ram:isNearTarget()
    end,
    blocking = true, blockable = true, persistent = false,
    type = "poll",
  })
  events.push({
    fn = function()
      projectiles.ram:hide()
      areas.ram.current.scale = 1.4
      areas.ram.value = areas.ram.value + 1
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })
  events.push({
    fn = function()
      card.target.y = card.current.y - 30
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after",
  })
  events.push({
    fn = function()
      card.target.y = love.graphics.getHeight() - card.asset:getHeight()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after",
  })
  events.push({
    fn = function()
      card.hover.can = false
      card.drag.can  = false
      p.slotText = ""
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })
end

function sequences.endTurn(card, areas)
  local p = areas.play
  local d = areas.discard

  events.push({
    fn = function()
      d.target.y = love.graphics.getHeight() - 60 * 2
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  events.push({
    fn = function()
      d.slotText = "+1 Threat"
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after",
  })
  events.push({
    fn = function()
      d.slotText = ""
      projectiles.threat:launch(
        d.x + d.w / 2,
        d.current.y,
        areas.threat.x + areas.threat.w / 2,
        areas.threat.y + areas.threat.h / 2,
        "1"
      )
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })
  events.push({
    fn = function()
      return projectiles.threat:isNearTarget()
    end,
    blocking = true, blockable = true, persistent = false,
    type = "poll",
  })
  events.push({
    fn = function()
      projectiles.threat:hide()
      areas.threat.current.scale = 1.4
      areas.threat.value = areas.threat.value + 1
      if checkWin(areas) then
        sequences.win(card, areas)
      elseif checkLoss(areas) then
        sequences.loss(card, areas)
      else
        sequences.ejectFromDiscard(card, areas)
      end
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })
end

return sequences
