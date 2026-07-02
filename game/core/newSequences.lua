local events        = require("lib.events")
local particles     = require("core.particles")
local areas         = require("core.areas")
local progressBar   = require("core.progressBar")
local threatBar     = require("core.threatBar")
local envEffects    = require("core.envEffects")
local message       = require("core.message")
local Token         = require("core.token")
local Color = require("lib.color")
local Camera = require("core.camera")
local laser = require("core.laser")
local Dtor  = require("core.dtor")
local Audio = require("assets.audio")
local Deck = require("core.deck")
local Palette = require("lib.palette")

local COUNT_MIN = 10
local COUNT_MAX = 20

local sequences = {}

local _deck = nil
function sequences.setDeck(d) _deck = d end
function sequences.getDeck()   return _deck  end

local _hand = nil
function sequences.setHand(h) _hand = h end


local function discardFlingOptions()
  return {
    bounces = math.random(1, 3),
    target_rect = areas.discardDeskArea,
    base_scale = 1.25,
    delay = false,
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
local function endTurnFlingOptions(token_type, direction)
  local flingDirection = direction or "downward"
  return {
    type       = token_type,
    bounces    = math.random(1, 3),
    base_scale = 1.25,
    delay      = false,
    target_rect = areas.discardDeskArea,
    [flingDirection] = true,
  }
end

local ENV_EFFECT_DELAY = 0.35

local function pushAnimAndFling(index, tokenType, withDelay)
  events.push({
    fn = function() envEffects.triggerAnim(index) end,
    blocking = true, blockable = true, persistent = false,
    delay = withDelay and ENV_EFFECT_DELAY or 0,
    type  = withDelay and "after" or "immediate",
  })
  events.push({
    fn = function() return envEffects.animDone(index) end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll",
  })
  events.push({
    fn = function()
      local x, y = envEffects.getPosition(index)
      Token.new_fling(x, y, areas.desk, endTurnFlingOptions(tokenType, "rightward"))
      Audio.playImpactIn()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })
end

local function queueEnvEffects()
  pushAnimAndFling("negative", "threat",     false)
  if envEffects.isActive(1) then
    pushAnimAndFling(1,        "drawToHand", true)
  end
  if envEffects.isActive(2) then
    pushAnimAndFling(2,        "ram",        true)
  end
end

local function fireEnvThresholdCeremony()
  for _, t in ipairs(envEffects.checkTransitions()) do
    local ix, iy = envEffects.getPosition(t.index)
    envEffects.triggerThresholdAnim(t.index, t.gained)
    screenshake.triggerH(4)
    if t.gained then
      particles.emit("progress", ix, iy, 14, { speed = 900 })
      message.text      = "EFFECT ACTIVE"
      message.textColor = Palette.positive
    else
      particles.emit("threat", ix, iy, 10, { speed = 700 })
      message.text      = "EFFECT LOST"
      message.textColor = Palette.danger
    end
    message.current.scale = 1.5
    message.target.scale  = 1.0
    events.push({
      fn = function() message.text = "" end,
      blocking = false, blockable = false, persistent = false,
      delay = 1.5, type = "after",
    })
  end
end

local function terminalEvent(tokenType)
  return function(token)
    events.push({
      fn = function()
        if tokenType == "progress" then
          progressBar.increment()
          fireEnvThresholdCeremony()
          local pbCount = math.floor(8 + 12 * (progressBar.getCount() / progressBar.getMax()))
          particles.emit("progress", areas.progressDestination.x, areas.progressDestination.y, pbCount, {
            lifetimeMin   = 0.25,
            lifetimeMax   = 0.5,
            speed = 1000
          })
          Audio.playImpactOut("progress")
          token:triggerPop(token.scale * 2.5, 0.35, function()
            particles.emit("progress", areas.progressDestination.x, areas.progressDestination.y, pbCount)
            Audio.playImpactIn()
          end)
          screenshake.trigger(5, 0.2)
        elseif tokenType == "progressNegative" then
          progressBar.decrement()
          fireEnvThresholdCeremony()
          local pbCount = math.floor(8 + 12 * (progressBar.getCount() / progressBar.getMax()))
          particles.emit("progressNegative", areas.progressDestination.x, areas.progressDestination.y, pbCount, {
            lifetimeMin   = 0.25,
            lifetimeMax   = 0.5,
            speed = 1000
          })
          Audio.playImpactOut("progressNegative")
          token:triggerPop(token.scale * 2.5, 0.35, function()
            particles.emit("progressNegative", areas.progressDestination.x, areas.progressDestination.y, pbCount)
            Audio.playImpactIn()
          end)
          screenshake.trigger(5, 0.2)
        elseif tokenType == "threat" then
          threatBar.increment()
          local tbCount = math.floor(8 + 12 * (threatBar.getCount() / threatBar.getMax()))
          particles.emit("threat", areas.threatDestination.x, areas.threatDestination.y, tbCount, {
            lifetimeMin   = 0.25,
            lifetimeMax   = 0.5,
            speed = 1000
          })
          Audio.playImpactOut("threat")
          token:triggerPop(token.scale * 2.5, 0.35, function()
            particles.emit("threat", areas.threatDestination.x, areas.threatDestination.y, tbCount)
            Audio.playImpactIn()
          end)
          screenshake.trigger(5, 0.2)
        elseif tokenType == "threatNegative" then
          threatBar.decrement()
          local tbCount = math.floor(8 + 12 * (threatBar.getCount() / threatBar.getMax()))
          particles.emit("threatNegative", areas.threatDestination.x, areas.threatDestination.y, tbCount, {
            lifetimeMin   = 0.25,
            lifetimeMax   = 0.5,
            speed = 1000
          })
          Audio.playImpactOut("threatNegative")
          token:triggerPop(token.scale * 2.5, 0.35, function()
            particles.emit("threatNegative", areas.threatDestination.x, areas.threatDestination.y, tbCount)
            Audio.playImpactIn()
          end)
          screenshake.trigger(5, 0.2)
        elseif tokenType == "ram" then
          areas.addPoolChip(token.x, token.y)
          Audio.playRamImpact()
          token._remove = true
        elseif tokenType == "nullify" then
          token._remove = true
          Dtor.nullifyNextSlot()
          screenshake.triggerH(2)
          Audio.playNullify()
        elseif tokenType == "drawToHand" then
          token._remove = true
          sequences.dealCardToHand("terminalArrive", 0)
          screenshake.triggerH(2)
        elseif tokenType == "drawToDtor" then
          token._remove = true
          screenshake.triggerH(2)
          local dtorCard = _deck:deal()
          if not dtorCard then
            screenshake.triggerH(2)
            return
          end
          dtorCard.current.scale = 0.05
          Dtor.setTransitCard(dtorCard)

          events.push({
            fn = function()
              local cx = SCALE_X * 1920
              local cy = SCALE_Y * 1080
              dtorCard.target.x     = cx
              dtorCard.target.y     = cy
              dtorCard.target.scale = dtorCard.scales.hover
              dtorCard.drawShadow = false
              Camera:lookAt(dtorCard)
              Audio.playDeal()
            end,
            blocking = true, blockable = true, persistent = false,
            delay = 0, type = "immediate",
          }, "terminalArrive")

          events.push({
            fn = function()
              return dtorCard:isAtTarget()
            end,
            blocking = true, blockable = true, persistent = false,
            delay = 0, type = "poll",
          }, "terminalArrive")

          events.push({
            fn = function()
              Camera:setColor(Color("#9C2B2B"))
              local lensX, lensY = Camera:getLensPosition()
              laser.show(lensX, lensY, dtorCard.current.x, dtorCard.current.y)
              Audio.playLaserStart()
              screenshake.trigger(10, 0.25)
            end,
            blocking = true, blockable = true, persistent = false,
            delay = 0.5, type = "before",
          }, "terminalArrive")

          events.push({
            fn = function()
              return laser.isDone()
            end,
            blocking = true, blockable = true, persistent = false,
            delay = 0, type = "poll",
          }, "terminalArrive")

          events.push({
            fn = function()
              Audio.playImpactIn()
              Camera:setColor(Color("#D56E6E"))
              laser.hide()
              dtorCard:startDissolve()
              dtorCard.target.scale = dtorCard.scales.drag
              dtorCard:flingZone("dtorEffect", areas.desk, discardFlingOptions())
            end,
            blocking = true, blockable = true, persistent = false,
            delay = 0, type = "immediate",
          }, "terminalArrive")

          events.push({
            fn = function()
              return not Token.isActive()
            end,
            blocking = true, blockable = true, persistent = false,
            delay = 0, type = "poll",
          }, "terminalArrive")

          events.push({
            fn = function()
              Token.attractDone(
                "dtor",
                function(_t)
                  return Dtor.reserveSlot()
                end,
                {
                  target_rotation = 0,
                  target_scale    = 1.5,
                  initial_speed   = 700,
                  onArrive = function()
                    Audio.playImpactIn()
                  end,
                }
              )
            end,
            blocking = true, blockable = true, persistent = false,
            delay = 0, type = "immediate",
          }, "terminalArrive")

          events.push({
            fn = function()
              return Token.allDone() and not dtorCard:isDissolving()
            end,
            blocking = true, blockable = true, persistent = false,
            delay = 0, type = "poll",
          }, "terminalArrive")

          events.push({
            fn = function()
              local dtorTokens  = Token.removeDone("dtor")
              local slotIndices = {}
              for _, t in ipairs(dtorTokens) do
                if t.dest_meta and t.dest_meta.index then
                  Dtor.claimSlot(t.dest_meta.index, t.scale)
                  table.insert(slotIndices, t.dest_meta.index)
                end
              end
              if #slotIndices > 0 then
                Dtor.register(dtorCard, slotIndices)
                Dtor.showText()
              end
              Dtor.clearTransitCard()
            end,
            blocking = true, blockable = true, persistent = false,
            delay = 0.1, type = "after",
          }, "terminalArrive")

        elseif tokenType == "shuffle" then
          local moves = Dtor.beginShuffle()
          if not moves then
            screenshake.trigger(8, 0.25)
            token._remove = true
          else
            Dtor.hideText()
            local firstDtorSlot = Dtor.topSlot()
            particles.emit("shuffle", firstDtorSlot.x, firstDtorSlot.y, 15)
            local remaining = #moves
            local acc = Token.makeCascadeAccumulator(0.06)
            for _, move in ipairs(moves) do
              local m = move
              if m.fromOverflow and m.toOverflow then
                -- overflow→overflow: same visual position, update state immediately
                Dtor.area.slots[m.toIdx].occupied = true
                Dtor.area.slots[m.toIdx].reserved = false
                Dtor.area.slots[m.toIdx].scale    = m.scale
                remaining = remaining - 1
              else
                Token.new_attract(
                  m.fromX, m.fromY,
                  m.toX,   m.toY,
                  acc:next({
                    type            = "dtor",
                    base_scale      = m.scale or 1.5,
                    target_scale    = m.scale or 1.5,
                    subTokens       = m.subTokens,
                    initial_speed   = 100 * SCALE_X,
                    acceleration    = 200 * SCALE_X,
                    no_anticipation = true,
                    start_alpha     = m.fromOverflow and 0 or 1,
                    target_alpha    = m.toOverflow   and 0 or 1,
                    onArrive        = function(t)
                      Dtor.area.slots[m.toIdx].occupied = true
                      Dtor.area.slots[m.toIdx].reserved = false
                      Dtor.area.slots[m.toIdx].scale    = m.scale
                      Token.removeSingle(t)
                      remaining = remaining - 1
                      if remaining == 0 then Dtor.showText() end
                    end,
                  })
                )
              end
            end
            if remaining == 0 then Dtor.showText() end
            screenshake.triggerH(3)
            token:triggerPop(token.scale * 2.5, 0.35, function()
              Audio.playImpactIn()
              particles.emit("shuffle", firstDtorSlot.x, firstDtorSlot.y, 15)
            end)
          end
        end
        if progressBar.isFull() then
          gameOver = "win"
          message.text          = "SUCCESS"
          message.subtitle      = ""
          message.textColor     = { 0.4, 1, 0.6, 1 }
          message.current.scale = 6
          Audio.playSuccess()
        elseif threatBar.isFull() then
          gameOver = "loss"
          message.text          = "FAILURE"
          message.subtitle      = ""
          message.current.scale = 6
          message.textColor     = { 1, 0.3, 0.3, 1 }
          Audio.playFailure()
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
  startTerminalAttract("progressNegative", areas.progressDestination, acc)
  startTerminalAttract("threatNegative", areas.threatDestination, acc)
  startTerminalAttract("ram", areas.pool, acc)
  startTerminalAttract("nullify", Dtor.nextUnnullifiedSlot(), acc)
  startTerminalAttract("shuffle", Dtor.topSlot(), acc)
  startTerminalAttract("drawToDtor", _deck:centerPosition(), acc)
  startTerminalAttract("drawToHand", _deck:centerPosition(), acc)
end

function sequences.dealCardToHand(eventType, delay)
  if not eventType then eventType = "default" end
  if not delay then delay = 0.5 end
  events.push({
    fn = function()
      local card = _deck:deal()
      if card then
        card:resetToInitial(_deck.x, _deck.y)
        card.current.scale = 0.05
        _hand:add(card, false, true)
        Audio.playDeal()
      else
        print("no card to deal to hand")
      end
    end,
    blocking = true, blockable = true, persistent = false,
    delay = delay, type = "after",
  }, eventType)
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
      Audio.playScannerLoop()
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
      return Token.allQuiverDone()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll"
  })
  events.push({
    fn = function()
      Audio.stopScanner()
      terminalAttract()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
end

function sequences.restoreCard(card)
  events.push({
    fn = function()
      Dtor.setTransitCard(card)
      Audio.playRecombineCard()
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
      -- Dtor.compactSlots()
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
      local handSize = _hand:handSize()
      local handMax = 5
      local toDeal = math.min(handMax - handSize, 4)
      if toDeal < 0 then toDeal = 0 end
      -- local toDeal = 4
      for _ = 1, toDeal do
        sequences.dealCardToHand()
      end
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.1, type = "after",
  })
end

function sequences.discard(card, camera)
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
      card.target.x = areas.discard.x + areas.discard.w * 0.4
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
      Audio.playLaserStart()
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
      Audio.playImpactIn()
      camera:setColor(Color("#D56E6E"))
      laser.hide()
      card:startDissolve()
      card.target.scale = card.scales.drag
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
      Token.attractDone("ram", areas.pool, {
        onArrive = function()
          Audio.playRamImpact()
        end
      })
      Token.attractDone(
        "dtor",
        function(_token)
          return Dtor.reserveSlot()
        end,
        {
          target_rotation = 0,
          target_scale = 1.5,
          initial_speed = 700,
          onArrive = function()
            Audio.playImpactIn()
          end
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
          _hand:remove(card)
        end,
        blocking = true, blockable = true, persistent = false,
        delay = 0, type = "immediate"
      })
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate"
  })
end

function sequences.play(card, camera)
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
              Audio.playRamImpact()
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
      card.decay = 8
      card:enterSlot(471 * SCALE_Y)
      card.target.y = 440 * SCALE_Y + (card.h / 2) * SCALE_Y
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
  -- events.push({
  --   fn = function()
  --     card.target.x = card.current.x + 50 * SCALE_X
  --     card.target.y = 471 * SCALE_Y
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0.5, type = "before"
  -- })
  -- events.push({
  --   fn = function()
  --     return card:isAtTarget()
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0, type = "poll"
  -- })
  events.push({
    fn = function()
      card.decay = 12
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
      return card:isAtTarget()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll"
  })
  events.push({
    fn = function()
      _hand:setActiveCardDraw(false)
      _hand:remove(card)
      _deck:add(card)
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
          -- _hand:remove(card)
          -- _deck:add(card)
        end,
        blocking = true, blockable = true, persistent = false,
        delay = 0, type = "immediate"
      })
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate"
  })
end

function sequences.endTurn()

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
        Audio.playNullify()
        Dtor.popEntry()
        local idx = slotIndices[1]
        Dtor.releaseSlot(idx)
        Dtor.compactSlots()
        queueEnvEffects()
        sequences.scan(areas.scanner.right)
        events.push({
          fn = function()
            return Token.allDone() and not events.isRunning("terminalArrive")
          end,
          blocking = true, blockable = true, persistent = false,
          delay = 0, type = "poll",
        })
        sequences.restoreCard(card)
      else
        local sx, sy = Dtor.getTextCenter()
        for _, effect in ipairs(card.data.dtor or {}) do
          Token.new_fling(sx, sy, areas.desk, endTurnFlingOptions(effect.type))
        end
        Dtor.popEntry()
        local idx = slotIndices[1]
        Dtor.releaseSlot(idx)
        Dtor.compactSlots()
        events.push({
          fn = function()
            return Token.allDone()
          end,
          blocking = true, blockable = true, persistent = false,
          delay = 0, type = "poll",
        })
        queueEnvEffects()
        sequences.scan(areas.scanner.right)
        events.push({
          fn = function()
            return Token.allDone() and not events.isRunning("terminalArrive")
          end,
          blocking = true, blockable = true, persistent = false,
          delay = 0, type = "poll",
        })
        sequences.restoreCard(card)
      end
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.1, type = "after",
  })
end

return sequences
