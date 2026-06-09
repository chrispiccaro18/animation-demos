local events        = require("lib.events")
local projectiles   = require("core.projectiles")
local animation    = require("lib.animation")
local areas       = require("core.areas")
local Token       = require("core.token")
local Color = require("lib.color")
local Camera = require("core.camera")
local laser = require("core.laser")

local sequences = {}



local discardDeskArea = {
  x = areas.desk.x + areas.desk.w * 0.6,
  y = areas.desk.y + areas.desk.h * 0.25,
  w = areas.desk.w * 0.2,
  h = areas.desk.h * 0.4,
}

local discardDeskFullRect = {
  x = areas.desk.x + areas.desk.w / 2,
  y = areas.desk.y,
  w = areas.desk.w / 2,
  h = areas.desk.h,
}

local playDeskArea = {
  x = areas.desk.x + areas.desk.w * 0.1,
  y = areas.desk.y + areas.desk.h * 0.25,
  w = areas.desk.w * 0.2,
  h = areas.desk.h * 0.4,
}

local playDeskFullRect = {
  x = areas.desk.x,
  y = areas.desk.y,
  w = areas.desk.w / 2,
  h = areas.desk.h,
}

local discardFlingOptions = { bounces = math.random(2, 3), target_rect = discardDeskArea, base_scale = 1.25 }
local playFlingOptions = { bounces = math.random(2, 3), target_rect = playDeskArea, delay = false, base_scale = 1.25 }

function sequences.discard(card, camera, hand)
  events.push({
    fn = function()
      card:lock()
      card.target.scale = card.scales.hover
      Camera:lookAt(card)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after"
  })
  events.push({
    fn = function()
      card.target.x = areas.discard.x + areas.discard.w / 4
      card.target.y = areas.discard.current.y + areas.discard.h
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate"
  })
  events.push({
    fn = function()
      return card:isAtTarget()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll"
  })
  events.push({
    fn = function()
      camera:setColor(Color("#9C2B2B"))
      local lensX, lensY = camera:getLensPosition()
      laser.show(lensX, lensY, card.current.x, card.current.y)
      screenshake.trigger(10, 0.25)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate"
  })
  events.push({
    fn = function()
      return laser.isDone()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll"
  })
  events.push({
    fn = function()
      camera:setColor(Color("#D56E6E"))
      laser.hide()
      card:startDissolve()
      card:flingZone("bottomEnergy", discardDeskFullRect, discardFlingOptions)
      card:flingZone("discardEffect",  discardDeskFullRect, discardFlingOptions)
      card:flingZone("dtorEffect",     discardDeskFullRect, discardFlingOptions)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate"
  })
  events.push({
    fn = function()
      return not Token.isActive()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll"
  })
  events.push({
    fn = function()
      Token.attractDone("ram", areas.pool)
      Token.attractDone(
        "dtor",
        function(_token)
          return areas.reserveDtorSlot()
        end,
        {
          target_rotation = 0,
          target_scale = 1.5,
          initial_speed = 700,
        }
      )
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate"
  })
  events.push({
    fn = function()
      return Token.allDone()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll"
  })
  events.push({
    fn = function()
      local ramTokens = Token.removeDone("ram")
      for _, t in ipairs(ramTokens) do
        areas.addPoolChip(t.x, t.y)
      end
      local dtorTokens = Token.removeDone("dtor")
      for _, t in ipairs(dtorTokens) do
        if t.dest_meta and t.dest_meta.index then
          areas.claimDtorSlot(t.dest_meta.index, t.scale)
        end
      end
      areas.scanner.right.active = true
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 1.5, type = "after"
  })
  events.push({
    fn = function()
      Token.attractDone("progress", areas.progressDestination, { target_scale = 1.5 })
      Token.attractDone("threat", areas.threatDestination , { target_scale = 1.5 })
      Token.attractDone("nullify", areas.nextUnnullifiedDtorSlot(), { target_scale = 1.5 })
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after"
  })
  events.push({
    fn = function()
      return Token.allDone()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll"
  })
  events.push({
    fn = function()
      local removedTokens = Token.removeDone()
      for _, t in ipairs(removedTokens) do
        if t.token_type == "progress" then
          areas.progressBar.count = math.min(areas.progressBar.count + 1, 5)
        elseif t.token_type == "threat" then
          areas.threatBar.count = math.min(areas.threatBar.count + 1, 5)
        elseif t.token_type == "nullify" then
          areas.nullifyNextDtorSlot()
        end
      end
      -- card.current.x = love.graphics.getWidth() + 400 * SCALE_X
      Camera:setIdle()
      hand:remove(card)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate"
  })
end

function sequences.play(card, camera, hand)
  events.push({
    fn = function()
      card:lock()
      card.target.scale = card.scales.hover
      Camera:lookAt(card)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after"
  })
  events.push({
    fn = function()
      card.target.x = areas.play.x + areas.play.w * 0.6
      card.target.y = areas.play.y + areas.play.h
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate"
  })
  events.push({
    fn = function()
      return card:isAtTarget(1)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll"
  })
  events.push({
    fn = function()
      -- camera:setColor(Color("#9C2B2B"))
      -- local lensX, lensY = camera:getLensPosition()
      -- laser.show(lensX, lensY, card.current.x, card.current.y)
      -- screenshake.trigger(10, 0.25)
      local ramChips = areas.consumePoolChips(card.energy)
      if #ramChips < card.energy then
        print("not enough ram to play card, returning to hand", #ramChips, "needed", card.energy)
        for _, chip in ipairs(ramChips) do
          areas.addPoolChip(chip.x, chip.y)
        end
        card:setZoneState("idle")
        Camera:setIdle()
      else
        print("enough ram to play card", #ramChips)
        for i, chip in ipairs(ramChips) do
          local slotPos = card:getTargetSlotPosition("topEnergyHoles", i)
          local slotIndex = i
          Token.new_attract(
            chip.x, chip.y,
            slotPos.x, slotPos.y,
            {
              type = "ram",
              target_scale = 1,
              onArrive = function(t)
                t:attachToSlot(card, "topEnergyHoles", slotIndex)
              end
            }
          )
        end
      end
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate"
  })
  events.push({
    fn = function()
      return Token.allDone("ram")
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll"
  })
  events.push({
    fn = function()
      card:enterSlot(471 * SCALE_Y)
      card.target.y = 440 * SCALE_Y + (card.h / 2) * SCALE_Y
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "before"
  })
  events.push({
    fn = function()
      return card:isAtTarget()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll"
  })
  events.push({
    fn = function()
      card.target.x = card.current.x + 50 * SCALE_X
      card.target.y = 471 * SCALE_Y
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 1.5, type = "before"
  })
  events.push({
    fn = function()
      return card:isAtTarget()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll"
  })
  events.push({
    fn = function()
      card:flingZone("playEffect", playDeskFullRect, playFlingOptions)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after"
  })
  events.push({
    fn = function()
      card.current.r = math.rad(-5)
      card.target.x = card.current.x + 150 * SCALE_X
      card.target.y = card.current.y - card.h / 4
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate"
  })
  events.push({
    fn = function()
      return not Token.isActive()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll"
  })
  events.push({
    fn = function()
      areas.scanner.left.active = true
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 1.5, type = "after"
  })
  events.push({
    fn = function()
      Token.attractDone("progress", areas.progressDestination, { target_scale = 1.5 })
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after"
  })
  events.push({
    fn = function()
      return Token.allDone()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll"
  })
  events.push({
    fn = function()
      local removedTokens = Token.removeDone()
      for _, t in ipairs(removedTokens) do
        if t.token_type == "progress" then
          areas.progressBar.count = math.min(areas.progressBar.count + 1, 5)
        elseif t.token_type == "threat" then
          areas.threatBar.count = math.min(areas.threatBar.count + 1, 5)
        -- elseif t.token_type == "nullify" then
        --   areas.nullifyNextDtorSlot()
        end
      end
      -- card.current.x = love.graphics.getWidth() + 400 * SCALE_X
      Camera:setIdle()
      hand:remove(card)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate"
  })
end

function sequences.endTurn(hand)
  print(hand:isDragging())
  print(hand:discardQueueSize())
end

return sequences
