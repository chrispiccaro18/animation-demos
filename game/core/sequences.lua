local events = require("lib.events")

local sequences = {}

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
      card.target.scale = 1.2
      p.slotText = "+1 Progress"
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  events.push({
    fn = function()
      card.target.scale = 0.95
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
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
      p.slotText = ""
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
      card.target.scale = 0.95
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
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
      p.slotText = "+1 RAM"
      d.slotText = ""
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
      d.target.y = d.startY
      card.target.y = d.startY
    end,
    blocking = true, blockable = true, persistent = false, realTime = true,
    delay = 0.65, type = "after",
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
      d.slotText = ""
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

return sequences
