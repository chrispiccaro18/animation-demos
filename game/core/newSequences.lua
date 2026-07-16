local events        = require("lib.events")
local particles     = require("core.particles")
local areas         = require("core.areas")
local progressBar   = require("core.progressBar")
local threatBar     = require("core.threatBar")
local Run           = require("core.run")
local Profile       = require("core.profile")
local Escalation    = require("core.escalation")
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
local Shatter = require("core.shatter")
local Debris  = require("core.debris")
local ActionQueue = require("core.actionQueue")

local COUNT_MIN = 10
local COUNT_MAX = 20

local sequences = {}

local _deck = nil
function sequences.setDeck(d) _deck = d end
function sequences.getDeck()   return _deck  end

local _hand = nil
function sequences.setHand(h) _hand = h end

-- Sandbox drives terminalEvent (progress/threat/etc.) the same way real play
-- does, but a sandbox session isn't a real run — level-complete/failure
-- ceremony (message, sound, Run.levelComplete()) must not fire from it.
local _sandboxMode = false
function sequences.setSandboxMode(v) _sandboxMode = v end


local function discardFlingOptions()
  return {
    bounces = math.random(1, 3),
    target_rect = areas.flingTarget,
    base_scale = 1.25,
    delay = false,
  }
end
local function playFlingOptions()
  return {
    bounces = math.random(1, 3),
    target_rect = areas.flingTarget,
    delay = false,
    base_scale = 1.25,
    downward = true
  }
end

local function endTurnFlingOptions(token_type, direction, acc)
  local flingDirection = direction or "downward"

  return {
    type       = token_type,
    bounces    = math.random(1, 3),
    base_scale = 1.25,
    delay      = acc and acc:nextDelay() or false,
    target_rect = areas.flingTarget,
    [flingDirection] = true,
  }
end

local function beginningOfTurnFlingOptions(token_type, direction, acc)
  local flingDirection = direction or "downward"

  return {
    type       = token_type,
    bounces    = math.random(1, 3),
    base_scale = 1.25,
    delay      = acc and acc:nextDelay() or false,
    target_rect = areas.flingTarget,
    [flingDirection] = true,
  }
end

local ENV_EFFECT_DELAY = 0.35

-- local function pushAnimAndFling(index, tokenType, withDelay)
--   events.push({
--     fn = function() envEffects.triggerAnim(index) end,
--     blocking = false, blockable = true, persistent = false,
--     delay = withDelay and ENV_EFFECT_DELAY or 0,
--     type  = withDelay and "after" or "immediate",
--   })
--   -- events.push({
--   --   fn = function() return envEffects.animDone(index) end,
--   --   blocking = true, blockable = true, persistent = false,
--   --   delay = 0, type = "poll",
--   -- })
--   events.push({
--     fn = function()
--       local x, y = envEffects.getPosition(index)
--       Token.new_fling(x, y, areas.desk, endTurnFlingOptions(tokenType, "rightward"))
--       Audio.playImpactIn()
--     end,
--     blocking = false, blockable = true, persistent = false,
--     delay = 0, type = "immediate",
--   })
-- end

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
    message.current.scale = 6
    message.target.scale  = 1.0
    events.push({
      fn = function() message.text = "" end,
      blocking = false, blockable = false, persistent = false,
      delay = 1.5, type = "after",
    })
  end
end

local OUTCOME_VANISH_DURATION = 0.25
local OUTCOME_FLOURISH_HOLD   = 1.2
local OUTCOME_BURST2_DELAY    = 0.45 -- time after the first burst that the second fires

-- Guards against a second progress/threat token (still arriving in the
-- same cascade) re-triggering this while the first is already resolving.
local _outcomeResolving = false

-- Fires once a progress/threat token tips a bar to full: cuts every other
-- token's animation short (Token.vanishAllExcept), waits for the board to
-- actually settle (scoring token's pop finishes, cancelled tokens finish
-- vanishing), then plays a distinct win/loss flourish, holds, and only
-- then flips the global `gameOver` -- main.lua reacts to that by clearing
-- the board (resetBoardState) and handing off to the unlock ceremony/card
-- picker (win) or gameOverScreen (loss).
local function resolveOutcome(kind, token)
  if _outcomeResolving then return end
  _outcomeResolving = true

  Token.vanishAllExcept(token, OUTCOME_VANISH_DURATION)

  events.push({
    fn = function()
      return not Token.isActive() and not Token.anyPopActive() and not Token.anyVanishActive()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll",
  }, "terminalArrive")

  events.push({
    fn = function()
      local cx, cy = SCALE_X * 1920, SCALE_Y * 1080
      if kind == "levelComplete" then
        Run.levelComplete()
        message.text          = "LEVEL COMPLETE"
        message.subtitle      = ""
        message.textColor     = { 0.4, 1, 0.6, 1 }
        message.current.scale = 6
        message.target.scale  = 1.0
        message.current.alpha = 1.0
        message.target.alpha  = 1.0
        Audio.playSuccess()
        particles.emit("progress", cx, cy, 60, { speed = 450 })
        screenshake.trigger(6, 0.4)
        Camera:setColor(Color("#6ED59E"))
      else
        message.text          = "FAILURE"
        message.subtitle      = ""
        message.textColor     = { 1, 0.3, 0.3, 1 }
        message.current.scale = 6
        message.target.scale  = 1.0
        message.current.alpha = 1.0
        message.target.alpha  = 1.0
        Audio.playFailure()
        particles.emit("threat", cx, cy, 60, { speed = 450 })
        screenshake.trigger(14, 0.5)
        Camera:setColor(Color("#9C2B2B"))
      end
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  }, "terminalArrive")

  -- Second burst, staggered after the first so the flourish reads as two
  -- beats instead of one flat pop.
  events.push({
    fn = function()
      local cx, cy = SCALE_X * 1920, SCALE_Y * 1080
      local burstType = kind == "levelComplete" and "progress" or "threat"
      particles.emit(burstType, cx, cy, 90, { speed = 1200 })
      screenshake.triggerH(kind == "levelComplete" and 4 or 8)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = OUTCOME_BURST2_DELAY, type = "before",
  }, "terminalArrive")
  events.push({
    fn = function()
      local cx, cy = SCALE_X * 1920, SCALE_Y * 1080
      local burstType = kind == "levelComplete" and "progress" or "threat"
      particles.emit(burstType, cx, cy, 90, { speed = 2000 })
      screenshake.triggerH(kind == "levelComplete" and 4 or 8)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = OUTCOME_BURST2_DELAY, type = "before",
  }, "terminalArrive")

  events.push({
    fn = function()
      gameOver = kind
      _outcomeResolving = false
    end,
    blocking = true, blockable = true, persistent = false,
    delay = math.max(OUTCOME_FLOURISH_HOLD - OUTCOME_BURST2_DELAY, 0), type = "before",
  }, "terminalArrive")
end

local function terminalEvent(tokenType)
  return function(token)
    events.push({
      fn = function()
        if tokenType == "progress" then
          progressBar.increment()
          -- fireEnvThresholdCeremony()
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
          -- fireEnvThresholdCeremony()
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
              dtorCard:startShatter(Shatter.pickPattern())
              dtorCard.target.scale = dtorCard.scales.drag
            end,
            blocking = true, blockable = true, persistent = false,
            delay = 0, type = "immediate",
          }, "terminalArrive")

          events.push({
            fn = function()
              return dtorCard:isCrackDone()
            end,
            blocking = true, blockable = true, persistent = false,
            delay = 0, type = "poll",
          }, "terminalArrive")
          events.push({
            fn = function()
              dtorCard:triggerShatterExplode()
              dtorCard:flingZone("dtorEffect", areas.desk, discardFlingOptions())
              Debris.spawn(dtorCard.current.x, dtorCard.current.y, 5)
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
        if _sandboxMode then
          -- no level-complete/failure ceremony in sandbox
        elseif progressBar.isFull() then
          resolveOutcome("levelComplete", token)
        elseif threatBar.isFull() then
          resolveOutcome("loss", token)
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

-- drawToDtor's terminal ceremony (deal a card, laser zap, shatter, attract
-- into a Dtor slot) drives the same Camera/laser singletons that
-- sequences.play/discard do. The token's attract-flight toward the deck
-- (before terminalEvent's ceremony even starts pushing to "terminalArrive")
-- is pure Token physics with nothing on any events queue, so ActionQueue's
-- underlyingDone() can read as idle mid-flight and let a dropped card start
-- a concurrent play/discard that fights the ceremony over those singletons.
-- Routing the whole flight+ceremony through ActionQueue — with a poll event
-- holding "terminalArrive" busy for the flight portion — closes that gap:
-- a card dropped mid-sequence queues behind it instead of racing it.
local function startDrawToDtorCeremony(target, acc)
  local function begin()
    startTerminalAttract("drawToDtor", target, acc)
    events.push({
      fn = function() return Token.allDone("drawToDtor") end,
      blocking = true, blockable = true, persistent = false,
      delay = 0, type = "poll",
    }, "terminalArrive")
  end

  if ActionQueue.isTerminal() then
    -- Reached during endTurn/beginTurn's own terminal ActionQueue item
    -- (main.lua's End Turn push sets terminal=true for the whole
    -- resolution). ActionQueue.push refuses new items while terminal, which
    -- would silently drop this and strand the token. Player input is
    -- already blocked during this phase (isTerminal() checks in
    -- newHand.lua), so there's no concurrent action to guard against here —
    -- just run the ceremony directly.
    begin()
  else
    ActionQueue.push({ fn = begin })
  end
end

local function resolveTerminalDestination(tokenType)
  if tokenType == "progress" or tokenType == "progressNegative" then
    return areas.progressDestination
  elseif tokenType == "threat" or tokenType == "threatNegative" then
    return areas.threatDestination
  elseif tokenType == "ram" then
    return areas.pool
  elseif tokenType == "nullify" then
    return Dtor.nextUnnullifiedSlot()
  elseif tokenType == "shuffle" then
    return Dtor.topSlot()
  elseif tokenType == "drawToDtor" or tokenType == "drawToHand" then
    return _deck:centerPosition()
  end
end

-- Shared accumulator for immediate-settle tokens; reset at the start of
-- each play/discard so each card's effects cascade cleanly. Sandbox tokens
-- settle independently of play/discard, so it also needs a way to reset
-- this itself (see core/sandbox.lua) — otherwise the delay this accumulator
-- hands out only ever grows, across the whole session.
local _immediateAcc = Token.makeCascadeAccumulator()
function sequences.resetImmediateAcc() _immediateAcc = Token.makeCascadeAccumulator() end

-- Reserves an ActionQueue slot the instant a drawToDtor token is created
-- (Token.new_fling), before it even starts flinging — not just once it
-- settles. A token created outside any already-_active action (beginTurn's
-- escalation cascade on turn 1, called directly from main.lua's
-- resetGame() rather than through endTurn's terminal ActionQueue item; or a
-- sandbox icon fling) otherwise leaves ActionQueue idle for the token's
-- entire flight. A card the player drops in that window would claim
-- _active first and run to completion before the token even lands, instead
-- of stacking behind it (the "discard finishes, then drawToDtor plays"
-- ordering bug). The poll tracks Token.allDone("drawToDtor") continuously
-- through fling -> settle -> attract -> ceremony-start; it's safe to hold a
-- single poll across that whole span because the fling-settle -> attract
-- remount (in Token.registerImmediateSettle below) happens synchronously
-- within the same Token.updateAll() call, before this poll is ever
-- evaluated -- see core/token.lua's immediate-settle handling.
Token.registerImmediateCreate({ "drawToDtor" }, function(_token)
  if ActionQueue.isTerminal() then
    -- Already inside endTurn's terminal window, which blocks player input
    -- on its own (see actionQueue.isTerminal() checks in newHand.lua) —
    -- nothing to reserve, and ActionQueue.push would silently no-op anyway.
    return
  end
  ActionQueue.push({
    fn = function()
      events.push({
        fn = function() return Token.allDone("drawToDtor") end,
        blocking = true, blockable = true, persistent = false,
        delay = 0, type = "poll",
      }, "terminalArrive")
    end,
  })
end)

-- Token types that skip the end-of-turn scan: on fling-settle they
-- immediately start their terminal attract animation toward the same
-- destination as the regular end-of-turn path, then fire the effect on arrival.
Token.registerImmediateSettle({ "drawToHand", "nullify", "shuffle", "drawToDtor" }, function(token)
  local dest = resolveTerminalDestination(token.token_type)
  if dest then
    startTerminalAttract(token.token_type, dest, _immediateAcc)
  end
end)

local function terminalAttract()
  local acc = Token.makeCascadeAccumulator()
  startTerminalAttract("progress", areas.progressDestination, acc)
  startTerminalAttract("threat", areas.threatDestination, acc)
  startTerminalAttract("progressNegative", areas.progressDestination, acc)
  startTerminalAttract("threatNegative", areas.threatDestination, acc)
  startTerminalAttract("ram", areas.pool, acc)
  startTerminalAttract("nullify", Dtor.nextUnnullifiedSlot(), acc)
  startTerminalAttract("shuffle", Dtor.topSlot(), acc)
  startDrawToDtorCeremony(_deck:centerPosition(), acc)
  startTerminalAttract("drawToHand", _deck:centerPosition(), acc)
end

-- Affect token types that modify other tokens before regular terminals fire.
-- Order matters: multipliers run before the flipper so counts are resolved first.
local PRE_TERMINAL_ORDER = { "multiplyAll", "multiplyThreat", "multiplyProgress", "flip" }

local MULTIPLY_ALL_TYPES      = { "progress", "progressNegative", "threat", "threatNegative",
                                   "drawToHand", "drawToDtor", "nullify", "shuffle", "ram" }
local MULTIPLY_THREAT_TYPES   = { "threat", "threatNegative" }
local MULTIPLY_PROGRESS_TYPES = { "progress", "progressNegative" }
local FLIP_TYPES              = { "progress", "progressNegative", "threat", "threatNegative",
                                   "drawToHand", "drawToDtor" }
local FLIP_MAP = {
  progress         = "progressNegative",
  progressNegative = "progress",
  threat           = "threatNegative",
  threatNegative   = "threat",
  drawToHand       = "drawToDtor",
  drawToDtor       = "drawToHand",
}

local function multiplyOnVisit(affectToken, target)
  local count = affectToken.value or 2
  for _ = 1, count - 1 do
    Token.new_fling(target.x, target.y, areas.desk, {
      type        = target.tokenType,
      bounces     = math.random(1, 2),
      target_rect = areas.flingTarget,
      base_scale  = 1.25,
      delay       = false,
    })
  end
  particles.emit(target.tokenType, target.x, target.y, 4, { speed = 400 })
  screenshake.triggerH(1)
end

local function flipOnVisit(_, target)
  if target.ref and not target.ref._remove then
    local newType = FLIP_MAP[target.ref.token_type]
    if newType then
      Token.mutateOne(target.ref, newType)
      particles.emit(newType, target.x, target.y, 4, { speed = 300 })
    end
  end
end

local function preTerminalAttract(tokenType)
  if tokenType == "multiplyAll" then
    Token.startChainForType("multiplyAll", MULTIPLY_ALL_TYPES, multiplyOnVisit)
  elseif tokenType == "multiplyThreat" then
    Token.startChainForType("multiplyThreat", MULTIPLY_THREAT_TYPES, multiplyOnVisit)
  elseif tokenType == "multiplyProgress" then
    Token.startChainForType("multiplyProgress", MULTIPLY_PROGRESS_TYPES, multiplyOnVisit)
  elseif tokenType == "flip" then
    Token.startChainForType("flip", FLIP_TYPES, flipOnVisit)
  end
end

local function startPreTerminalPipeline()
  for _, tokenType in ipairs(PRE_TERMINAL_ORDER) do
    local t = tokenType
    events.push({
      fn = function() preTerminalAttract(t) end,
      blocking = true, blockable = true, persistent = false,
      delay = 0, type = "immediate",
    })
    -- chain tokens set done=false while traveling; spawned flings set done=false
    -- until settled — allDone() gates the next phase correctly for both
    events.push({
      fn = function() return Token.allDone() end,
      blocking = true, blockable = true, persistent = false,
      delay = 0, type = "poll",
    })
  end
  events.push({
    fn = function() terminalAttract() end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })
end

function sequences.dealCardToHand(eventType, delay)
  if not eventType then eventType = "default" end
  if not delay then delay = 0.25 end
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
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after",
  })
  -- Push pipeline events here (not inside an fn callback) so they land in the
  -- queue before any caller-pushed events (e.g. endTurn's poll + restoreCard).
  startPreTerminalPipeline()
end

function sequences.restoreCard(card)
  events.push({
    fn = function()
      Dtor.setTransitCard(card)
      Audio.playRecombineCard()
      card:restoreAllSlots()
      card:startReverseShatter(Shatter.pickPattern())
      Debris.attractAll(card.current.x, card.current.y)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })

  events.push({
    fn = function()
      return card:isAssembleDone()
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

function sequences.discard(card, camera)
  _immediateAcc = Token.makeCascadeAccumulator()
  events.push({
    fn = function()
      card:lock()
      card.target.scale = card.scales.hover
      Camera:lookAt(card)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after"
  })
  -- events.push({
  --   fn = function()
  --     card.target.x = areas.discard.x + areas.discard.w * 0.4
  --     card.target.y = areas.discard.current.y + areas.discard.h
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0, type = "immediate"
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
      card:startShatter(Shatter.pickPattern())
      card.target.scale = card.scales.drag
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate"
  })
  -- events.push({
  --   fn = function()
  --     card:flingZone("bottomEnergy", areas.desk, discardFlingOptions())
  --     card:flingZone("discardEffect",  areas.desk, discardFlingOptions())
  --     card:flingZone("dtorEffect",     areas.desk, discardFlingOptions())
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0.15, type = "before"
  -- })
  events.push({
    fn = function()
      return card:isCrackDone()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll"
  })
  events.push({
    fn = function()
      card:triggerShatterExplode()
      card:flingZone("bottomEnergy", areas.desk, discardFlingOptions())
      card:flingZone("discardEffect",  areas.desk, discardFlingOptions())
      card:flingZone("dtorEffect",     areas.desk, discardFlingOptions())
      Debris.spawn(card.current.x, card.current.y, 5)
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
      -- if Token.count() > 0 then
      --   sequences.scan(areas.scanner.right)
      -- end
      events.push({
        fn = function()
          return Token.allDone() and card:isShatterDone()
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
  _immediateAcc = Token.makeCascadeAccumulator()
  events.push({
    fn = function()
      card:lock()
      card.target.scale = card.scales.hover
      Camera:lookAt(card)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after"
  })
  -- events.push({
  --   fn = function()
  --     card.target.x = areas.play.x + areas.play.w * 0.6
  --     card.target.y = areas.play.y + areas.play.h * 0.75
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0, type = "immediate"
  -- })
  -- events.push({
  --   fn = function()
  --     return card:isAtTarget(1)
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0, type = "poll"
  -- })
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
      -- card.decay = 8
      card:enterSlot(471 * SCALE_Y)
      -- card.target.y = 440 * SCALE_Y + (card.h / 2) * SCALE_Y
      card.target.x = areas.play.x + areas.play.w * 0.6 + 50 * SCALE_X
      -- card.target.x = card.current.x + 50 * SCALE_X
      card.target.y = 471 * SCALE_Y
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "before"
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
      -- card.decay = 12
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
      -- if Token.count() > 0 then
      --   sequences.scan(areas.scanner.left)
      -- end
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

function sequences.beginTurn()
  events.push({
    fn = function()
      areas.endTurn.frozen = true
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate",
  })

  events.push({
    fn = function()
      local toDeal = math.min(5 - _hand:handSize(), 4)
      if toDeal < 0 then toDeal = 0 end
      for _ = 1, toDeal do
        sequences.dealCardToHand()
      end
      events.push({
        fn = function()
          areas.endTurn.frozen = false
          local drawPile = {}
          for _, card in ipairs(_deck.cards) do
            drawPile[#drawPile + 1] = card.deckIndex
          end
          local handCards = {}
          for _, card in ipairs(_hand.cards) do
            handCards[#handCards + 1] = card.deckIndex
          end
          Run.saveTurn({
            progress = progressBar.getCount(),
            threat   = threatBar.getCount(),
            ram      = #areas.pool.chips,
            drawPile = drawPile,
            hand     = handCards,
            dtor     = Dtor.getSaveData(),
          })
        end,
        blocking = true, blockable = true, persistent = false,
        delay = 0, type = "immediate",
      })

      local level = Run.getLevel()
      local turn  = Run.nextTurn()

      if level > 0 then
        local flingAcc = Token.makeCascadeAccumulator()
        -- Pre-compute each token's launch delay so the env anim can hold at peak
        -- until the final token is flung. The last delay is the time (from the
        -- first fling) until the last token launches.
        local flingDelays = {}
        for i = 1, level do flingDelays[i] = flingAcc:nextDelay() end
        local holdDuration = flingDelays[level] or 0

        -- Trigger the anim once, pinned at full scale for the whole cascade.
        events.push({
          fn = function() envEffects.triggerAnim("negative", holdDuration) end,
          blocking = false, blockable = true, persistent = false,
          delay = 0, type = "immediate",
        })

        local deckId = Run.getDeckType()
        local highestLevel = Profile.getHighestLevelReached(deckId)
        local sequence = Escalation.pickSequence(deckId, level, turn, Run.getRunSeed(), highestLevel)

        for i = 1, level do
          local d = flingDelays[i]
          events.push({
            fn = function()
              local x, y = envEffects.getPosition("negative")
              local tokenType = sequence[i]
              local opts = endTurnFlingOptions(tokenType, "rightward")
              opts.delay = d
              Token.new_fling(x, y, areas.desk, opts)
              Audio.playImpactIn()
            end,
            blocking = false, blockable = true, persistent = false,
            delay = 0, type = "immediate",
          })
        end
        events.push({
          fn = function() return Token.allDone() end,
          blocking = true, blockable = true, persistent = false,
          delay = 0, type = "poll",
        })
        -- sequences.scan(areas.scanner.both)
        events.push({
          fn = function()
            Token.attractDone("ram", areas.pool, {
            onArrive = function()
              Audio.playRamImpact()
            end
          })
          end,
          blocking = true, blockable = true, persistent = false,
          delay = 0, type = "immediate",
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
          end,
          blocking = true, blockable = true, persistent = false,
          delay = 0.1, type = "after"
        })
      end
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.25, type = "before",
  })
end

function sequences.endTurn()
  if not Dtor.hasEntry() then
    events.push({
      fn = function() Camera:setIdle() end,
      blocking = true, blockable = true, persistent = false,
      delay = 0, type = "immediate",
    })
    sequences.scan(areas.scanner.both)
      events.push({
        fn = function()
          return Token.allDone() and not events.isRunning("terminalArrive")
        end,
        blocking = true, blockable = true, persistent = false,
        delay = 0, type = "poll",
      })
    sequences.beginTurn()
    return
  end

  local entry = Dtor.peekEntry()
  if not entry then
    -- Camera:setIdle()
    sequences.scan(areas.scanner.both)
      events.push({
        fn = function()
          return Token.allDone() and not events.isRunning("terminalArrive")
        end,
        blocking = true, blockable = true, persistent = false,
        delay = 0, type = "poll",
      })
    sequences.beginTurn()
    return
  end

  local card        = entry.card
  local slotIndices = entry.slotIndices

  events.push({
    fn = function()
      local cx = SCALE_X * 1920
      local cy = SCALE_Y * 1080
      card:setZoneState("idle")
      card.current.x = cx
      card.current.y = cy
      card.target.x  = cx
      card.target.y  = cy
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
        sequences.scan(areas.scanner.both)
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
        -- local flingAcc = Token.makeCascadeAccumulator()
        for _, effect in ipairs(card.data.dtor or {}) do
          local opts = endTurnFlingOptions(effect.type, nil)
          opts.value = effect.value
          Token.new_fling(sx, sy, areas.desk, opts)
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
        sequences.scan(areas.scanner.both)
        events.push({
          fn = function()
            return Token.allDone() and not events.isRunning("terminalArrive")
          end,
          blocking = true, blockable = true, persistent = false,
          delay = 0, type = "poll",
        })
        sequences.restoreCard(card)
      end
      sequences.beginTurn()
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.1, type = "after",
  })
end

function sequences.score()
  _immediateAcc = Token.makeCascadeAccumulator()
  events.push({
    fn       = function() return Token.allDone() end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "poll",
  })
  startPreTerminalPipeline()
end

return sequences
