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

local _deck = nil
function sequences.setDeck(d) _deck = d end

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

local function terminalEvent(tokenType)
  return function()
    events.push({
      fn = function()
        print("terminal event for token type", tokenType)
        if tokenType == "progress" then
          areas.progressBar.count = math.min(areas.progressBar.count + 1, 10)
        elseif tokenType == "threat" then
          areas.threatBar.count = math.min(areas.threatBar.count + 1, 10)
        elseif tokenType == "nullify" then
          Dtor.nullifyNextSlot()
        end
        if areas.progressBar.count >= areas.progressBar.max then
          gameOver = "win"
          areas.message.text = "SUCCESS"
          areas.message.subtitle = "Press R to reset"
          areas.message.textColor = { 0.4, 1, 0.6, 1 }
          areas.message.current.scale = 6
        elseif areas.threatBar.count >= areas.threatBar.max then
          gameOver = "loss"
          areas.message.text = "FAILURE"
          areas.message.subtitle = "Press R to reset"
          areas.message.current.scale = 6
          areas.message.textColor = { 1, 0.3, 0.3, 1 }
        end
      end,
      blocking = true, blockable = true, persistent = false,
      delay = 0, type = "immediate",
    }, "terminalArrive")
  end
end

local function startTerminalAttract(tokenType, target, acc)
  local tokenOptions = {
    target_scale = 1.5,
    acc = acc,
    terminal = true,
    onArrive = terminalEvent(tokenType),
  }
  Token.attractDone(tokenType, target, tokenOptions)
end

local function terminalAttract()
  local acc = Token.makeCascadeAccumulator()
  startTerminalAttract("progress", areas.progressDestination, acc)
  startTerminalAttract("threat", areas.threatDestination, acc)
  startTerminalAttract("nullify", Dtor.nextUnnullifiedSlot(), acc)
end

function sequences.scanDiscard()
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
    delay = 0.1, type = "after"
  })
  events.push({
    fn = function()
      return not areas.scanner.right.active
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll"
  })
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
  events.push({
    fn = function()
      local removedTokens = Token.removeDone()
      for _, t in ipairs(removedTokens) do
        if t.token_type == "progress" then
          areas.progressBar.count = math.min(areas.progressBar.count + 1, 5)
        elseif t.token_type == "threat" then
          areas.threatBar.count = math.min(areas.threatBar.count + 1, 5)
        elseif t.token_type == "nullify" then
          Dtor.nullifyNextSlot()
        end
      end
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })
end

function sequences.restoreCard(card, hand)
  events.push({
    fn = function()
      card:restoreAllSlots()
      card:startReverseDissolve()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
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
      card.target.x = _deck:position().x
      card.target.y = _deck:position().y
      card.target.scale = 0.1
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "before",
  })

  events.push({
    fn = function()
      return card:isAtTarget()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll",
  })

  -- 8. Restore state
  events.push({
    fn = function()
      hand:remove(card)
      _deck:add(card)
      Camera:setIdle()
      Dtor.compactSlots()
      areas.endTurn.frozen = false
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.1, type = "after",
  })

  events.push({
    fn = function()
      return Token.allDone()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll",
  })
  events.push({
    fn = function()
      Dtor.showText()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })
end

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
          return Dtor.reserveSlot()
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
          Dtor.claimSlot(t.dest_meta.index, t.scale)
          table.insert(slotIndices, t.dest_meta.index)
        end
      end
      if #slotIndices > 0 then
        Dtor.register(card, slotIndices)
        Dtor.showText()
      end
      areas.scanner.right.active = true
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.1, type = "after"
  })
  events.push({
    fn = function()
      return not areas.scanner.right.active
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll"
  })
  events.push({
    fn = terminalAttract,
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
      Token.removeDone()
      -- local removedTokens = Token.removeDone()
      -- for _, t in ipairs(removedTokens) do
      --   if t.token_type == "progress" then
      --     areas.progressBar.count = math.min(areas.progressBar.count + 1, 10)
      --   elseif t.token_type == "threat" then
      --     areas.threatBar.count = math.min(areas.threatBar.count + 1, 10)
      --   elseif t.token_type == "nullify" then
      --     Dtor.nullifyNextSlot()
      --   end
      -- end
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
        local acc = Token.makeCascadeAccumulator()
        for i, chip in ipairs(ramChips) do
          local slotPos = card:getTargetSlotPosition("topEnergyHoles", i)
          local slotIndex = i
          Token.new_attract(
            chip.x, chip.y,
            slotPos.x, slotPos.y,
            acc:next({
              type = "ram",
              target_scale = 1,
              onArrive = function(t)
                t:attachToSlot(card, "topEnergyHoles", slotIndex)
              end
            })
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
      card:flingZone("playEffect", playDeskFullRect, playFlingOptions)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after"
  })
  events.push({
    fn = function()
      -- card.current.r = math.rad(-2)
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
    delay = 0.1, type = "after"
  })
  events.push({
    fn = function()
      return not areas.scanner.left.active
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll"
  })
  events.push({
    fn = terminalAttract,
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
      Token.removeDone()
      Camera:setIdle()
      hand:remove(card)
      _deck:add(card)
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

  local entry = Dtor.peekEntry()
  if not entry then
    Camera:setIdle()
    areas.endTurn.frozen = false
    return
  end

  local card        = entry.card
  local slotIndices = entry.slotIndices

  events.push({
    fn = function()
      local cx = love.graphics.getWidth() / 2
      local cy = love.graphics.getHeight() / 2
      -- local cx = Dtor.area.x + Dtor.area.w / 2
      -- local cy = Dtor.area.y + Dtor.area.h / 2
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

  events.push({
    fn = function()
      Dtor.hideText()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after",
  })

  events.push({
    fn = function()
      if Dtor.isEntryNullified() then
        screenshake.trigger(5, 0.15)
        Dtor.popEntry()
        local idx   = slotIndices[1]
        Dtor.releaseSlot(idx)
        sequences.restoreCard(card, hand)
      else
        local sx, sy = Dtor.getTextCenter()
        for _, effect in ipairs(card.data.dtor or {}) do
          Token.new_fling(sx, sy, discardDeskFullRect, {
            type       = effect.type,
            bounces    = 1,
            base_scale = 1.25,
            delay      = false,
            target_rect = discardDeskFullRect,
          })
        end
        Dtor.popEntry()
        local idx   = slotIndices[1]
        Dtor.releaseSlot(idx)
        sequences.scanDiscard()
        sequences.restoreCard(card, hand)
      end
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.1, type = "after",
  })
end

return sequences
