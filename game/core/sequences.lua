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
      return math.abs(card.current.y - card.target.y) < 1
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll",
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

  -- events.push({
  --   fn = function()
  --     d.target.y = d.startY
  --     card.target.y = d.startY
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0.7, type = "after",
  -- })
  -- events.push({
  --   fn = function()
  --     card.target.y = card.current.y - 270
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0.65, type = "after",
  -- })
  -- events.push({
  --   fn = function()
  --     card.asset = card.assets.default
  --     card.target.y = d.startY
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0.65, type = "after",
  -- })
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

function sequences.play(card, areas, onStart, onDone)
  local p = areas.play
  local chip1x, chip1y, chip2x, chip2y

  events.push({
    fn = function() if onStart then onStart() end end,
    blocking = false, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })
  events.push({
    fn = function()
      card.hover.is = false
      card.hover.can = false
      card.drag.is   = false
      card.drag.can  = false
      card.target.scale = 1
      -- card.target.scale = 0.95
      card.target.x = p.x + (p.w - card.w) / 2
      card.target.y = p.y + (p.h - card.h / 2)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  events.push({
    fn = function()
      card.target.y = card.current.y + 30
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  events.push({
    fn = function()
      return math.abs(card.current.y - card.target.y) < 1
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll",
  })
  events.push({
    fn = function()
      local chips = areas.consumePoolChips(2)
      chip1x, chip1y = chips[1].x, chips[1].y
      chip2x, chip2y = chips[2].x, chips[2].y
      projectiles.ramChip:launch(chip1x, chip1y, card.target.x + 30, card.target.y + 25, "")
    end,
    blocking = false, blockable = true, persistent = false,
    delay = 0.25, type = "immediate",
  })
  events.push({
    fn = function()
      projectiles.ramChip2:launch(chip2x, chip2y, card.target.x + 55, card.target.y + 25, "")
    end,
    blocking = false, blockable = true, persistent = false,
    delay = 0.25, type = "before",
  })
  events.push({
    fn = function()
      -- print (projectiles.ramChip2:isNearTarget(1))
      -- print(projectiles.ramChip2.current.x, projectiles.ramChip2.current.y, projectiles.ramChip2.target.x, projectiles.ramChip2.target.y)
      return projectiles.ramChip:isNearTarget(7)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll",
  })
  events.push({
    fn = function()
      card:shake(8, 0.05)
      card.target.y = card.current.y
      card.current.y = card.current.y - 10
      card.target.x = card.current.x
      card.current.x = card.current.x + 10
      card.current.r = animation.degreesToRadians(-5)
    end,
    blocking = false, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })
  events.push({
    fn = function()
      -- print (projectiles.ramChip2:isNearTarget(1))
      -- print(projectiles.ramChip2.current.x, projectiles.ramChip2.current.y, projectiles.ramChip2.target.x, projectiles.ramChip2.target.y)
      return projectiles.ramChip2.visible
        and projectiles.ramChip2:isNearTarget(7)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll",
  })
  events.push({
    fn = function()
      card:shake(8, 0.05)
      card.target.y = card.current.y
      card.current.y = card.current.y - 10
      card.target.x = card.current.x
      card.current.x = card.current.x + 10
      card.current.r = animation.degreesToRadians(-5)
    end,
    blocking = false, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })
  events.push({
    fn = function()
      -- move spider part up 150 px
      card:updatePartById("spiderGuy", nil, -110, nil)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.6, type = "after",
  })
  events.push({
    fn = function()
      local travelY = p.y + 20
      card.target.y = travelY
      projectiles.ramChip:launch(
        projectiles.ramChip.current.x,
        projectiles.ramChip.current.y,
        projectiles.ramChip.current.x,
        travelY,
        "",
        6
      )
      projectiles.ramChip2:launch(
        projectiles.ramChip2.current.x,
        projectiles.ramChip2.current.y,
        projectiles.ramChip2.current.x,
        travelY,
        "",
        6
      )
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "before",
  })
  events.push({
    fn = function()
      return math.abs(card.current.y - card.target.y) < 5
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll",
  })
  -- events.push({
  --   fn = function()
  --     areas.ram.value = areas.ram.value - 1
  --     projectiles.ram:launch(
  --       areas.ram.x + areas.ram.w / 2,
  --       areas.ram.y + areas.ram.h / 2,
  --       areas.play.x + areas.play.w / 2,
  --       areas.ram.y + areas.ram.h / 2,
  --       "1"
  --     )
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0.5, type = "after",
  -- })
  events.push({
    fn = function()
      projectiles.ram:hide()
      projectiles.ramChip:hide()
      projectiles.ramChip2:hide()
      p.slotText = "+1 Progress"
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  events.push({
    fn = function()
      projectiles.progress:launch(
        p.x + p.w / 2,
        areas.ram.y + areas.ram.h / 2,
        areas.progress.x + areas.progress.w / 2,
        areas.progress.y + areas.progress.h / 2,
        "1"
      )
      p.slotText = ""
      card:updatePartById("spiderGuy", nil, 0, nil)
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
      elseif onDone then
        onDone()
      end
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })
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


function sequences.discard(card, areas, onStart, onDone)
  local p = areas.play
  local d = areas.discard
  local et = areas.endTurn
  local klakBG = areas.klakBG
  local klak = areas.klak
  local pos1x, pos1y = areas.randomPoolPosition()
  local pos2x, pos2y = areas.randomPoolPosition()

  events.push({
    fn = function() if onStart then onStart() end end,
    blocking = false, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })
  events.push({
    fn = function()
      card.hover.is = false
      card.hover.can = false
      card.drag.is   = false
      card.drag.can  = false
      card.target.scale = 0.95
      card.drawShadow = false
      card.target.x = klakBG.x + klakBG.w / 2 - card.w / 2
      card.target.y = klakBG.y + klakBG.h / 2 - card.h / 2
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  events.push({
    fn = function()
      klak.text.color = {1, 0.5, 0, 1}
      klak.text.value = "DESTROY"
      -- card.target.y = d.startY
      -- card.target.y = d.startY + (d.h - card.h / 2) + 30
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  events.push({
    fn = function()
      klak.target.y = klak.downY
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })
  events.push({
    fn = function()
      return math.abs(klak.target.y - klak.current.y) < 10
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll",
  })
  events.push({
    fn = function()
      screenshake.trigger(10, 0.25)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after",
  })
  events.push({
    fn = function()
      if card then card:startDissolve() end
      projectiles.ramChip:launch(
        card.current.x + card.w - 67,
        card.current.y + card.h - 40,
        card.current.x + card.w - 67,
        card.current.y + card.h - 40,
        ""
      )
      projectiles.ramChip2:launch(
        card.current.x + card.w - 40,
        card.current.y + card.h - 40,
        card.current.x + card.w - 40,
        card.current.y + card.h - 40,
        ""
      )
      projectiles.spiderThreat:launch(
        card.target.x + 90,
        card.target.y + 180,
        card.target.x + 90,
        card.target.y + 180,
        ""
      )
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.7, type = "after",
  })
  events.push({
    fn = function()
      projectiles.spiderThreat:launch(
        projectiles.spiderThreat.current.x,
        projectiles.spiderThreat.current.y,
        projectiles.spiderThreat.current.x,
        klak.current.y + klak.h / 2,
        -- areas.discard.current.y - 20,
        ""
      )
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  events.push({
    fn = function()
      return projectiles.spiderThreat:isNearTarget()

    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll",
  })
  events.push({
    fn = function()
      klak.text.color = {0.8, 0.2, 0, 1}
      klak.text.value = "+1 THREAT"
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after",
  })
  events.push({
    fn = function()
      projectiles.ramChip:launch(
        projectiles.ramChip.current.x,
        projectiles.ramChip.current.y,
        pos1x + projectiles.ramChip.w / 2,
        pos1y + projectiles.ramChip.h / 2,
        ""
      )
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after",
  })
  events.push({
    fn = function()
      projectiles.ramChip2:launch(
        projectiles.ramChip2.current.x,
        projectiles.ramChip2.current.y,
        pos2x + projectiles.ramChip2.w / 2,
        pos2y + projectiles.ramChip2.h / 2,
        ""
      )
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.7, type = "after",
  })
  events.push({
    fn = function()
      return projectiles.ramChip:isNearTarget()
         and projectiles.ramChip2:isNearTarget()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll",
  })
  events.push({
    fn = function()
      areas.addPoolChip(pos1x, pos1y)
      areas.addPoolChip(pos2x, pos2y)
      projectiles.ramChip:hide()
      projectiles.ramChip2:hide()
      projectiles.spiderThreat:hide()
      -- d.slotText = "+1 Threat"
      klak.target.y = klak.upY
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })
  events.push({
    fn = function()
      return math.abs(klak.target.y - klak.current.y) < 10
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll",
  })
  events.push({
    fn = function()
      screenshake.trigger(10, 0.25)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after",
  })
  events.push({
    fn = function()
      if onDone then onDone() end
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })
  -- events.push({
  --   fn = function()
  --     card.target.x = d.x + (d.w - card.w) / 2
  --     card.target.y = d.current.y
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0.5, type = "after",
  -- })
  -- events.push({
  --   fn = function()
  --     return math.abs(card.current.y - card.target.y) < 5
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0, type = "poll",
  -- })
  -- events.push({
  --   fn = function()
  --    d.slotText = "+1 RAM"
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0.5, type = "after",
  -- })
  -- events.push({
  --   fn = function()
  --     projectiles.ram:launch(
  --       areas.discard.x + areas.discard.w / 2,
  --       areas.ram.y + areas.ram.h / 2,
  --       areas.ram.x + areas.ram.w / 2,
  --       areas.ram.y + areas.ram.h / 2,
  --       "1"
  --     )
  --     areas.discard.slotText = ""
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0, type = "immediate",
  -- })
  --   events.push({
  --   fn = function()
  --     return projectiles.ram:isNearTarget()
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0, type = "poll",
  -- })
  -- events.push({
  --   fn = function()
  --     projectiles.ram:hide()
  --     areas.ram.current.scale = 1.4
  --     areas.ram.value = areas.ram.value + 1
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0.5, type = "after",
  -- })
  -- events.push({
  --   fn = function()
  --     card.target.y = card.current.y - card.h
  --     areas.discard.slotText = "DTOR enqueued."
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0.75, type = "after",
  -- })
  -- events.push({
  --   fn = function()
  --     areas.discard.slotText = ""
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0.5, type = "after",
  -- })
  -- events.push({
  --   fn = function()
  --     sequences.popTopOff(card, areas)
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0, type = "immediate",
  -- })
end

function sequences.endTurn(card, areas, onDone)
  local p = areas.play
  local d = areas.discard
  local klak = areas.klak
  local klakBG = areas.klakBG

  events.push({
    fn = function()
      card:setParts({})
      card.hover.is = false
      card.hover.can = false
      card.drag.is   = false
      card.drag.can  = false
      card.drawShadow = false
      card.current.x = klakBG.x + klakBG.w / 2 - card.w / 2
      card.current.y = klakBG.y + klakBG.h / 2 - card.h / 2
      -- card.current.x = d.x + (d.w - card.w) / 2
      -- card.current.y = d.startY - card.h
      card.target.x = card.current.x
      card.target.y = card.current.y
      -- projectiles.spiderThreat:launch(
      --   card.current.x + 90,
      --   areas.discard.current.y - 20,
      --   card.current.x + 90,
      --   areas.discard.current.y - 20,
      --   ""
      -- )
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })
  events.push({
    fn = function()
      -- projectiles.spiderThreat:launch(
      --   projectiles.spiderThreat.current.x,
      --   projectiles.spiderThreat.current.y,
      --   projectiles.spiderThreat.current.x,
      --   love.graphics.getHeight() / 2,
      --   ""
      -- )
      klak.target.y = klak.downY
      card.target.y = d.startY + d.h - card.h * 0.65
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })
  events.push({
    fn = function()
      return math.abs(klak.current.y - klak.target.y) < 10
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll",
  })
  events.push({
    fn = function()
      screenshake.trigger(10, 0.25)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after",
  })
  events.push({
    fn = function()
      -- d.slotText = ""
      klak.text.color = {1, 1, 1, 1}
      klak.text.value = ""
      projectiles.threat:launch(
        klak.current.x,
        klak.current.y + klak.h / 2,
        areas.threat.x + areas.threat.w / 2,
        areas.threat.y + areas.threat.h / 2,
        ""
      )
      -- projectiles.threat:launch(
      --   projectiles.spiderThreat.current.x,
      --   projectiles.spiderThreat.current.y,
      --   areas.threat.x + areas.threat.w / 2,
      --   areas.threat.y + areas.threat.h / 2,
      --   ""
      -- )
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "before",
  })
   events.push({
    fn = function()
      return projectiles.threat:isNearTarget()
    end,
    blocking = true, blockable = true, persistent = false,
    type = "poll", delay = 0,
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
        -- sequences.ejectFromDiscard(card, areas)
        klak.target.y = klak.upY
      end
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })
  events.push({
    fn = function()
      return math.abs(klak.target.y - klak.current.y) < 10
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll",
  })
  events.push({
    fn = function()
      screenshake.trigger(10, 0.25)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after",
  })
  events.push({
    fn = function()
      -- d.slotText = "+1 Threat"
      klak.text.value = "EMPTY"
      print("Setting card parts")
      card:setParts({
        { id = "base", asset = card.partAssets.base, yOffset = 0},
        { id = "ramChip", asset = card.partAssets.ramChip, xOffset = card.w - 67, yOffset = card.h - 40, },
        { id = "ramChip2", asset = card.partAssets.ramChip, xOffset = card.w - 40, yOffset = card.h - 40, },
        { id = "spiderGuy", asset = card.partAssets.spiderGuy, xOffset = 21, yOffset = 156, },
        { id = "threat", asset = card.partAssets.threat, xOffset = 67, yOffset = 164, },
        { id = "progress", asset = card.partAssets.progress, xOffset = 67, yOffset = 54, },
      })
      card:startReverseDissolve()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  events.push({
    fn = function()
      return not card:isDissolving()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll",
  })
  events.push({
    fn = function()
      -- projectiles.spiderThreat:hide()
      card.drawShadow = true
      areas.endTurn.state = "idle"
      if onDone then onDone() end
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "before",
  })
  -- events.push({
  --   fn = function()
  --     return projectiles.threat:isNearTarget()
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   type = "poll",
  -- })
  -- events.push({
  --   fn = function()
  --     projectiles.threat:hide()
  --     areas.threat.current.scale = 1.4
  --     areas.threat.value = areas.threat.value + 1
  --     if checkWin(areas) then
  --       sequences.win(card, areas)
  --     elseif checkLoss(areas) then
  --       sequences.loss(card, areas)
  --     else
  --       sequences.ejectFromDiscard(card, areas)
  --     end
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0, type = "immediate",
  -- })
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
