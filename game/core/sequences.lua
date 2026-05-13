local events        = require("lib.events")
local projectiles   = require("core.projectiles")
local animation    = require("lib.animation")

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
      areas.ram.value = areas.ram.value - 1
      projectiles.ram:launch(
        areas.ram.x + areas.ram.w / 2,
        areas.ram.y + areas.ram.h / 2,
        areas.play.x + areas.play.w / 2,
        areas.ram.y + areas.ram.h / 2,
        "1"
      )
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  events.push({
    fn = function()
      sequences.insertMiddle(card, areas)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })
  -- events.push({
  --   fn = function()
  --     card.target.y = p.y + (p.h - card.h / 2) + 30
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0.25, type = "after",
  -- })
  -- events.push({
  --   fn = function()
  --     card.target.x = p.x + (p.w - card.w) / 2
  --     card.target.y = p.y
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0.5, type = "after",
  -- })
  --   events.push({
  --   fn = function()
  --     areas.ram.value = areas.ram.value - 1
  --     projectiles.ram:launch(
  --       areas.ram.x + areas.ram.w / 2,
  --       areas.ram.y + areas.ram.h / 2,
  --       p.x + p.w / 2,
  --       areas.ram.y + areas.ram.h / 2,
  --       "1"
  --     )
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0.5, type = "after",
  -- })
  -- events.push({
  --   fn = function()
  --     card.target.scale = 1.2
  --     p.slotText = "+1 Progress"
  --     projectiles.ram:hide()
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0.5, type = "after",
  -- })
  -- events.push({
  --   fn = function()
  --     card.target.scale = 0.95
  --     projectiles.progress:launch(
  --       p.x + p.w / 2,
  --       areas.ram.y + areas.ram.h / 2,
  --       areas.progress.x + areas.progress.w / 2,
  --       areas.progress.y + areas.progress.h / 2,
  --       "1"
  --     )
  --     p.slotText = ""
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0, type = "immediate",
  -- })
  -- events.push({
  --   fn = function()
  --     return projectiles.progress:isNearTarget()
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   type = "poll",
  -- })
  -- events.push({
  --   fn = function()
  --     projectiles.progress:hide()
  --     areas.progress.current.scale = 1.4
  --     areas.progress.value = areas.progress.value + 1
  --     if checkWin(areas) then
  --       sequences.win(card, areas)
  --     elseif checkLoss(areas) then
  --       sequences.loss(card, areas)
  --     else
  --       sequences.ejectCard(card, areas)
  --     end
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   type = "immediate",
  -- })
end

-- NEW discard sequence:
-- Move full card to discard x, center y
-- Move card up by 30
-- Move card down to bottom right slot y
-- Pop off top (play part of card)
-- Top left slot goes down to top of card (now top of discard part)
-- Top left slot and middle part of card go back update
-- Top left slot "eats" middle
-- RAM projectile: slot -> RAM pool


function sequences.discard(card, areas)
  local p = areas.play
  local d = areas.discard
  local et = areas.endTurn

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
      card.target.y = d.startY + (d.h - card.h / 2) - 30
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after",
  })
  events.push({
    fn = function()
      card.target.x = d.x + (d.w - card.w) / 2
      card.target.y = et.y - card.h * 0.8
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  events.push({
    fn = function()
      sequences.popTopOff(card, areas)
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

-- Animation 1: pop the top section off, then split middle and bottom apart
function sequences.popTopOff(card, areas)
  local a = card.partAssets
  events.push({
    fn = function()
      card:setParts({
        { asset = a.middleBottom, yOffset = 32 },
        { id = "top", asset = a.top, yOffset = 0, origin = { x = 180, y = 56 } },
      })
      card.parts[2].target.dy = -80
      card.parts[2].target.dx =  200
      card.parts[2].target.dr =  animation.degreesToRadians(145)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })
  events.push({
    fn = function()
      -- print(card.parts[2].current.dy)
      return math.abs(card.parts[2].current.dx - card.parts[2].target.dx) < 1
    end,
    blocking = true, blockable = true, persistent = false,
    type = "poll",
  })
  -- events.push({
  --   fn = function()
  --     card:removePart("top")
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0.5, type = "before",
  -- })
  events.push({
    fn = function()
      card:removePart("top")
      -- local topDy = card.parts[2].current.dy
      card:setParts({
        { id = "middle", asset = a.middle, yOffset = 32  },
        { id = "bottom", asset = a.bottom, yOffset = 151 },
      })
      card.parts[1].target.dy =  areas.discard.current.y - card.current.y - 32
      -- card.parts[2].target.dy = -25
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  events.push({
    fn = function()
      card.parts[1].target.dy = areas.discard.current.y - card.current.y - 22
      card.parts[2].target.dy = -10
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  events.push({
    fn = function()
      card.parts[1].target.dy = areas.discard.current.y - card.current.y - 300
      card.parts[2].target.dy = 200
      areas.discard.slotText = "+1 RAM"
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.7, type = "after",
  })
  events.push({
    fn = function()
      card:removePart("middle")
      card:removePart("bottom")
      projectiles.ram:launch(
        areas.discard.x + areas.discard.w / 2,
        areas.ram.y + areas.ram.h / 2,
        areas.ram.x + areas.ram.w / 2,
        areas.ram.y + areas.ram.h / 2,
        "1"
      )
      areas.discard.slotText = ""
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
  -- events.push({
  --   fn = function()
  --     card.target.y = card.current.y - 30
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0.25, type = "after",
  -- })
  -- events.push({
  --   fn = function()
  --     card.target.y = love.graphics.getHeight() - card.asset:getHeight()
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0.25, type = "after",
  -- })
  -- events.push({
  --   fn = function()
  --     card.hover.can = false
  --     card.drag.can  = false
  --     p.slotText = ""
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0, type = "immediate",
  -- })
end

-- Animation 2: fly a middle section down onto the card, then split at the seam
function sequences.insertMiddle(card, areas)
  local a = card.partAssets
  events.push({
    fn = function()
      projectiles.ram:hide()
      card:setParts({
        { id = "middleBottom", asset = a.middleBottom, yOffset = 32 },
        { id = "middle", asset = a.middle, yOffset = -115, dy = -400 },
        { id = "top", asset = a.top,    yOffset = 0   },
      })
      card.parts[2].target.dy = 0
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 1, type = "after",
  })
  events.push({
    fn = function()
      -- print(card.parts[2].current.dy)
      return math.abs(card.parts[2].current.dy) < 2
    end,
    blocking = true, blockable = true, persistent = false,
    type = "poll",
  })
  events.push({
    fn = function()
      card.parts[1].target.dy = 100
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.7, type = "after",
  })
  events.push({
    fn = function()
      card:removePart("top")
      card:removePart("middle")
      card:setParts({
        { id = "middleBottom", asset = a.middleBottom, yOffset = 132 },
        { id = "middleTop",    asset = a.middleTop,    yOffset = -115  },
      })
      -- card.parts[1].target.dy =  50
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })
  events.push({
    fn = function()
      card.parts[2].target.dy = areas.play.y - card.current.y + 35
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.7, type = "after",
  })
  events.push({
    fn = function()
      -- card.target.scale = 1.2
      areas.play.slotText = "+1 Progress"
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  events.push({
    fn = function()
      -- card.target.scale = 0.95
      projectiles.progress:launch(
        areas.play.x + areas.play.w / 2,
        areas.ram.y + areas.ram.h / 2,
        areas.progress.x + areas.progress.w / 2,
        areas.progress.y + areas.progress.h / 2,
        "1"
      )
      areas.play.slotText = ""
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
      -- if checkWin(areas) then
      --   sequences.win(card, areas)
      -- elseif checkLoss(areas) then
      --   sequences.loss(card, areas)
      -- else
      --   -- sequences.ejectCard(card, areas)
      -- end
    end,
    blocking = true, blockable = true, persistent = false,
    type = "after", delay = 0.5,
  })
  events.push({
    fn = function()
      card:removePart("middleTop")
      card:setParts({
        { id = "middleBottom", asset = a.middleBottom, yOffset = 132 },
        { id = "top",    asset = a.top, yOffset = -180  },
      })
      card.parts[2].target.dy = card.current.y + 65
    end,
    blocking = true, blockable = true, persistent = false,
    type = "after", delay = 0.5,
  })
  -- events.push({
  --   fn = function()
  --     card.parts[1].target.dy = 0   -- back to natural (yOffset=32)
  --     card.parts[2].target.dy = 0   -- back to natural (yOffset=0)
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   type = "after", delay = 0.5,
  -- })
  -- events.push({
  --   fn = function()
  --     card:convergeParts()
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   type = "immediate", delay = 0,
  -- })
  -- events.push({
  --   fn = function()
  --     return card:partsSettled()
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   type = "poll", delay = 0,
  -- })
  -- events.push({
  --   fn = function()
  --     card:clearParts()
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   type = "immediate", delay = 0,
  -- })
end

return sequences
