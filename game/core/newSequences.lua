local events        = require("lib.events")
local particles     = require("core.particles")
local areas         = require("core.areas")
local message       = require("core.message")
local Token         = require("core.token")
local Color = require("lib.color")
local Camera = require("core.camera")
local laser = require("core.laser")
local Dtor  = require("core.dtor")

local COUNT_MIN = 10
local COUNT_MAX = 20

local sequences = {}

local _deck = nil
function sequences.setDeck(d) _deck = d end


local function discardFlingOptions()
  return {
    bounces = math.random(1, 3),
    target_rect = areas.discardDeskArea,
    base_scale = 1.25
  }
end
local function playFlingOptions()
  return {
    bounces = math.random(1, 3),
    target_rect = areas.playDeskArea,
    delay = false,
    base_scale = 1.25,
    downward = true
  }
end
local function endTurnFlingOptions(token_type)
  return {
    type       = token_type,
    bounces    = math.random(1, 3),
    base_scale = 1.25,
    delay      = false,
    target_rect = areas.discardDeskArea,
    downward   = true,
  }
end

local function terminalEvent(tokenType)
  return function(token)
    events.push({
      fn = function()
        print("terminal event for token type", tokenType)
        if tokenType == "progress" then
          areas.progressBar.count = math.min(areas.progressBar.count + 1, 10)
          areas.triggerBarPop(areas.progressBar)
          local pb = areas.progressBar
          local pbCount = math.floor(8 + 12 * (pb.count / pb.max))
          particles.emit("progress", areas.progressDestination.x, areas.progressDestination.y, pbCount, {
            lifetimeMin   = 0.25,
            lifetimeMax   = 0.5,
            speed = 1000
          })
          token:triggerPop(token.scale * 2.5, 0.35, function()
            particles.emit("progress", areas.progressDestination.x, areas.progressDestination.y, pbCount)
          end)
          local pbSegIdx   = pb.count - 1
          local pbCx       = pb.x + pbSegIdx * pb.gapX + pb.w / 2
          -- local pbBarCount = math.floor(COUNT_MIN + (COUNT_MAX - COUNT_MIN) * (pb.count / pb.max))
          -- particles.emit("progress", pbCx, pb.y + pb.h / 2, pbBarCount)
          screenshake.trigger(5, 0.2)
        elseif tokenType == "threat" then
          areas.threatBar.count = math.min(areas.threatBar.count + 1, 10)
          areas.triggerBarPop(areas.threatBar)
          local tb = areas.threatBar
          local tbCount = math.floor(8 + 12 * (tb.count / tb.max))
          particles.emit("threat", areas.threatDestination.x, areas.threatDestination.y, tbCount, {
            lifetimeMin   = 0.25,
            lifetimeMax   = 0.5,
            speed = 1000
          })
          token:triggerPop(token.scale * 2.5, 0.35, function()
            particles.emit("threat", areas.threatDestination.x, areas.threatDestination.y, tbCount)
          end)
          local tbSegIdx   = tb.count - 1
          local tbCx       = tb.x + tbSegIdx * tb.gapX + tb.w / 2
          -- local tbBarCount = math.floor(COUNT_MIN + (COUNT_MAX - COUNT_MIN) * (tb.count / tb.max))
          -- particles.emit("threat", tbCx, tb.y + tb.h / 2, tbBarCount)
          screenshake.trigger(5, 0.2)
        elseif tokenType == "nullify" then
          token._remove = true
          Dtor.nullifyNextSlot()
          screenshake.triggerH(2)
        end
        if areas.progressBar.count >= areas.progressBar.max then
          gameOver = "win"
          message.text          = "SUCCESS"
          message.subtitle      = "Press R to reset"
          message.textColor     = { 0.4, 1, 0.6, 1 }
          message.current.scale = 6
        elseif areas.threatBar.count >= areas.threatBar.max then
          gameOver = "loss"
          message.text          = "FAILURE"
          message.subtitle      = "Press R to reset"
          message.current.scale = 6
          message.textColor     = { 1, 0.3, 0.3, 1 }
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

function sequences.dealCardToHand(hand)
  events.push({
    fn = function()
      local card = _deck:deal()
      if card then
        card:resetToInitial(_deck.x, _deck.y)
        card.current.scale = 0.05
        hand:add(card, false, true)
      else
        print("no card to deal to hand")
      end
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
end

function sequences.scan(scanner)
  events.push({
    fn = function()
      return not Token.isActive()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll",
  })
  events.push({
    fn = function()
      scanner.active = true
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.1, type = "after"
  })
  events.push({
    fn = function()
      return not scanner.active
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll"
  })
  events.push({
    fn = function()
      terminalAttract()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
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
      Dtor.clearTransitCard()
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
  events.push({
    fn = function()
    local handSize = hand:handSize()
      print("hand size after end turn:", handSize)
      local toDeal = math.min(4 - handSize, 4)
      print("cards to deal after end turn:", toDeal)
      for _ = 1, toDeal do
        sequences.dealCardToHand(hand)
      end
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.1, type = "after",
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
      card.target.y = areas.discard.current.y + areas.discard.h * 0.75
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
      card:flingZone("bottomEnergy", areas.desk, discardFlingOptions())
      card:flingZone("discardEffect",  areas.desk, discardFlingOptions())
      card:flingZone("dtorEffect",     areas.desk, discardFlingOptions())
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
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.1, type = "after"
  })

  events.push({
    fn = function()
      if Token.count() > 0 then
        sequences.scan(areas.scanner.right)
      end
      events.push({
        fn = function()
          return Token.allDone()
        end,
        blocking = true, blockable = true, persistent = false,
        delay = 0, type = "poll"
      })
      events.push({
        fn = function()
          Camera:setIdle()
          hand:remove(card)
        end,
        blocking = true, blockable = true, persistent = false,
        delay = 0, type = "immediate"
      })
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
      card.target.y = areas.play.y + areas.play.h * 0.75
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
      local ramChips = areas.consumePoolChips(card.energy)
      local acc = Token.makeCascadeAccumulator()
      for i, chip in ipairs(ramChips) do
        local slotPos   = card:getTargetSlotPosition("topEnergyHoles", i)
        local slotIndex = i
        Token.new_attract(
          chip.x, chip.y,
          slotPos.x, slotPos.y,
          acc:next({
            type = "ram",
            target_scale = 1,
            onArrive = function(t)
              t:attachToSlot(card, "topEnergyHoles", slotIndex)
              screenshake.triggerH(4)
            end
          })
        )
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
      card:clearZone("topEnergyHoles")
      card:flingZone("playEffect", areas.desk, playFlingOptions())
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after"
  })
  events.push({
    fn = function()
      -- card.current.r = math.rad(-2)
      -- card.target.x = card.current.x + 150 * SCALE_X
      -- card.target.y = card.current.y - card.h / 4

      -- card.target.x = _deck:position().x / 2
      card.target.y = _deck:position().y * 0.7
      card.target.scale = 0.5
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "after"
  })
  events.push({
    fn = function()
      -- card.current.r = math.rad(-2)
      -- card.target.x = card.current.x + 150 * SCALE_X
      -- card.target.y = card.current.y - card.h / 4

      card.target.x = _deck:position().x
      card.target.y = _deck:position().y
      card.target.scale = 0
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate"
  })

  events.push({
    fn = function()
      if Token.count() > 0 then
        sequences.scan(areas.scanner.left)
      end
      events.push({
        fn = function()
          return Token.allDone()
        end,
        blocking = true, blockable = true, persistent = false,
        delay = 0, type = "poll"
      })
      events.push({
        fn = function()
          Camera:setIdle()
          hand:remove(card)
          _deck:add(card)
        end,
        blocking = true, blockable = true, persistent = false,
        delay = 0, type = "immediate"
      })
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
      local cx = SCALE_X * 1920
      local cy = SCALE_Y * 1080
      -- local cx = love.graphics.getWidth() / 2
      -- local cy = love.graphics.getHeight() / 2
      -- local cx = Dtor.area.x + Dtor.area.w / 2
      -- local cy = Dtor.area.y + Dtor.area.h / 2
      card:setZoneState("idle")
      card.current.x = cx
      card.current.y = cy
      card.target.x = cx
      card.target.y = cy
      Dtor.setTransitCard(card)
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
          Token.new_fling(sx, sy, areas.desk, endTurnFlingOptions(effect.type))
        end
        Dtor.popEntry()
        local idx   = slotIndices[1]
        Dtor.releaseSlot(idx)
        print("Token count before end turn scan:", Token.count())
        if Token.count() > 0 then
          sequences.scan(areas.scanner.right)
        end
        sequences.restoreCard(card, hand)
      end
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.1, type = "after",
  })
end

return sequences
