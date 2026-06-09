local events        = require("lib.events")
local projectiles   = require("core.projectiles")
local animation    = require("lib.animation")
local areas       = require("core.areas")
local Token       = require("core.token")
local Color = require("lib.color")
local Camera = require("core.camera")
local laser = require("core.laser")
local Dtor  = require("core.dtor")

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
      local slotIndices = {}
      for _, t in ipairs(dtorTokens) do
        if t.dest_meta and t.dest_meta.index then
          areas.claimDtorSlot(t.dest_meta.index, t.scale)
          table.insert(slotIndices, t.dest_meta.index)
        end
      end
      if #slotIndices > 0 then
        Dtor.register(card, slotIndices)
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
  if not Dtor.hasEntry() then
    Camera:setIdle()
    areas.endTurn.frozen = false
    return
  end

  local entry = Dtor.popEntry()
  if not entry then
    Camera:setIdle()
    areas.endTurn.frozen = false
    return
  end

  local card        = entry.card
  local slotIndices = entry.slotIndices


  -- 1. Position dissolved card at dtorQueue center, add it back to hand so
  --    card:update() runs every frame (required for reverse dissolve to tick).
  --    It is fully dissolved (invisible) so being in the hand is fine here.
  events.push({
    fn = function()
      local dq = areas.dtorQueue
      local cx = love.graphics.getWidth() / 2
      local cy = love.graphics.getHeight() / 2
      -- local cx = dq.x + dq.w / 2
      -- local cy = dq.y + dq.h / 2
      hand:add(card, false, false)
      card:setZoneState("idle")
      card.current.x = cx
      card.current.y = cy
      card.target.x = cx
      card.target.y = cy
      Camera:lookAt(card)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after",
  })

  -- 2. Fling sub-tokens from the slot; compact remaining entries up to slot 1
  events.push({
    fn = function()
      local dq    = areas.dtorQueue
      local dtorText = areas.dtorText
      local slotH = dq.h / dq.maxSlots
      local idx   = slotIndices[1]
      local sx    = dtorText.x + dtorText.w / 2
      local sy    = dtorText.y + dtorText.h / 2
      -- local sx    = dq.x + dq.w / 2
      -- local sy    = dq.y + (idx - 0.5) * slotH
      areas.releaseDtorSlot(idx)
      for _, effect in ipairs(card.data.dtor or {}) do
        Token.new_fling(sx, sy, discardDeskFullRect, {
          type       = effect.type,
          bounces    = 1,
          base_scale = 1.25,
          delay      = false,
          target_rect = discardDeskFullRect,
        })
      end
      Dtor.compactSlots()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.1, type = "after",
  })

  -- 3. Poll until flung tokens have landed and compact tokens have slid into place
  events.push({
    fn = function()
      return not Token.isActive()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll",
  })

  events.push({
    fn = function()
      areas.scanner.right.active = true
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 1.5, type = "after"
  })
  -- 4. Attract tokens back to the card's dtorEffect slot positions
  events.push({
    fn = function()
      Token.attractDone("threat", areas.threatDestination, { target_scale = 1.5 })

    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })

  -- 5. Poll until all tokens have arrived
  events.push({
    fn = function()
      return Token.allDone()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll",
  })

  -- 6. Remove tokens and start reverse dissolve
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
      card:restoreAllSlots()
      card:startReverseDissolve()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })

  -- 7. Poll until reverse dissolve is done
  events.push({
    fn = function()
      return not card:isDissolving()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll",
  })

  -- 8. Restore state
  events.push({
    fn = function()
      card:resetDissolve()
      card:unlock()
      hand:layout()
      Camera:setIdle()
      areas.endTurn.frozen = false
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })
end

return sequences
