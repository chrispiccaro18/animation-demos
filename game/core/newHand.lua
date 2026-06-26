local sequences   = require("core.newSequences")
local events      = require("lib.events")
local areas       = require("core.areas")
local Color       = require("lib.color")
local Camera      = require("core.camera")
local laser       = require("core.laser")
local actionQueue = require("core.actionQueue")
local Audio       = require("assets.audio")

local Hand      = {}
Hand.__index    = Hand

function Hand.new()
  return setmetatable({ cards = {}, _suppressActiveCard = false, _lastActiveCard = nil }, Hand)
end

function Hand:layout()
  local gap = 80 * SCALE_X
  local active = {}
  for _, card in ipairs(self.cards) do
    if not card._excluded then active[#active + 1] = card end
  end
  local cardW = active[1] and active[1].w * SCALE_X or 0
  local totalW = #active * cardW + math.max(#active - 1, 0) * gap
  local startX = (SCALE_X * 3840 - totalW) / 2
  local startY = SCALE_Y * 1760

  for i, card in ipairs(active) do
    card._startX = startX + (i - 1) * (cardW + gap)
    card._startY = startY
    card.target.x = card._startX
    card.target.y = card._startY
  end
end

function Hand:add(card, snap, layout)
  self.cards[#self.cards + 1] = card
  if layout == nil then layout = true end
  if layout then self:layout() end

  if snap then
    card.current.x = card._startX
    card.current.y = card._startY
  end
end

function Hand:remove(card)
  for i, c in ipairs(self.cards) do
    if c == card then
      table.remove(self.cards, i)
      break
    end
  end
  card._excluded = false
  self:layout()
end

function Hand:isDragging()
  for _, card in ipairs(self.cards) do
    if card.drag.is then return true end
  end
  return false
end

function Hand:handSize()
  return #self.cards
end

function Hand:unlockHand()
  for _, card in ipairs(self.cards) do
    if not card._excluded then
      card.hover.can    = true
      card.hover.is     = false
      card.target.scale = card.scales.idle
      card.drag.can     = true
      card.drag.is      = false
    end
  end
end

local function returnCardToHand(card, hand)
  card._excluded    = false
  card.hover.can    = true
  card.drag.can     = true
  card:setZoneState("idle")
  hand:layout()
  screenshake.triggerH()
  Audio.playError()
end

function Hand:update(mouseX, mouseY)
  local draggingCard = nil
  local hoveredCard = nil
  for _, card in ipairs(self.cards) do
    if card.drag.is then
      draggingCard = card; break
    end
  end

  local isDragTouch = draggingCard and draggingCard.drag.isTouch or false

  -- Suppress hover on siblings while a card is being dragged
  areas.pool.showText = draggingCard ~= nil
  if draggingCard then
    for _, card in ipairs(self.cards) do
      if card ~= draggingCard and not card._excluded then
        card.hover.can    = false
        card.hover.is     = false
        card.target.scale = card.scales.idle
      end
    end
  end

  -- Update area highlight colors
  if areas.mouseInPlay(mouseX, mouseY, isDragTouch) and draggingCard then
    areas.play.color = { 0.5, 0.5, 1, 1 }
    Camera:setColor(Color("#6ED59E"))
    draggingCard:setZoneState("play")
  elseif draggingCard and areas.cardInPlay(draggingCard) then
    areas.play.color = { 0.5, 0.5, 0.5, 1 }
  elseif areas.mouseInPlay(mouseX, mouseY) then
    areas.play.color = { 0.5, 0.5, 0.5, 1 }
  else
    areas.play.color = { 0.5, 0.5, 0.5, 1 }
  end

  if areas.mouseInDiscard(mouseX, mouseY, isDragTouch) and draggingCard then
    areas.discard.color = { 0.5, 0.5, 1, 1 }
    Camera:setColor(Color("#D56E6E"))
    draggingCard:setZoneState("discard")
  elseif draggingCard and areas.cardInDiscard(draggingCard) then
    areas.discard.color = { 0.5, 0.5, 0.5, 1 }
  elseif areas.mouseInDiscard(mouseX, mouseY) then
    areas.discard.color = { 0.5, 0.5, 0.5, 1 }
  else
    areas.discard.color = { 0.5, 0.5, 0.5, 1 }
  end

  if draggingCard and
    not areas.mouseInPlay(mouseX, mouseY, isDragTouch) and
    not areas.mouseInDiscard(mouseX, mouseY, isDragTouch) then
      Camera:setColor(Color("#88EDFF"))
      draggingCard:setZoneState("idle")
  end

  -- Reorder cards when dragged card center crosses a neighbor's layout center
  if draggingCard and mouseY > SCALE_Y * 1080 then
    local dragIdx
    for i, c in ipairs(self.cards) do
      if c == draggingCard then dragIdx = i; break end
    end
    if dragIdx then
      local dragCX = draggingCard.current.x + draggingCard.w / 2
      local swapped = false
      if dragIdx > 1 then
        local left = self.cards[dragIdx - 1]
        if not left._excluded and dragCX < left._startX + left.w / 2 then
          self.cards[dragIdx], self.cards[dragIdx - 1] = self.cards[dragIdx - 1], self.cards[dragIdx]
          self:layout()
          swapped = true
        end
      end
      if not swapped and dragIdx < #self.cards then
        local right = self.cards[dragIdx + 1]
        if not right._excluded and dragCX > right._startX + right.w / 2 then
          self.cards[dragIdx], self.cards[dragIdx + 1] = self.cards[dragIdx + 1], self.cards[dragIdx]
          self:layout()
        end
      end
    end
  end

  local hoverCandidate = nil
  if not draggingCard then
    for i = #self.cards, 1, -1 do
      local c = self.cards[i]
      if c.hover.can and not c.drag.is and c:containsPoint(mouseX, mouseY) and c:isAtTargetHeight() then
        hoverCandidate = c
        break
      end
    end
  end

  for _, card in ipairs(self.cards) do
    -- Release drag
    if card.drag.is and not love.mouse.isDown(1) then
      local wasTouch = card.drag.isTouch
      if wasTouch then
        -- card.current.y    = mouseY
        card.target.y     = mouseY - (card.h * SCALE_Y / 4)
        card.drag.isTouch = false
      end
      card.drag.is   = false
      card.drag.can  = true
      card.hover.is  = false
      card.hover.can = false
      card.target.scale = card.scales.idle
      -- card._excluded = true
      -- self:layout()

      if areas.mouseInPlay(mouseX, mouseY, wasTouch) then
        if actionQueue.isTerminal() then
          -- end turn already queued — return card immediately
          returnCardToHand(card, self)
        elseif not actionQueue.isRunning() and
          #areas.pool.chips < card.energy then
          returnCardToHand(card, self)
        --   card:setZoneState("idle")
        --   Camera:setColor(Color("#88EDFF"))
        --   Camera:setIdle()
        --   screenshake.triggerH()
        --   card._excluded = false
        --   self:layout()
        --   card.target.x = card._startX
        --   card.target.y = card._startY
        else
          local hand = self
          local pushed = actionQueue.push({
            card     = card,
            terminal = false,
            check    = function()
              if #areas.pool.chips < card.energy then return "rejectAll" end
              return "ok"
            end,
            onReject = function(item)
              returnCardToHand(item.card, hand)
            end,
            fn = function()
              sequences.play(card, Camera)
            end,
          })
          if pushed then
            card._excluded = true
            self:layout()
            card.hover.can = false
            card.hover.is  = false
            card.drag.can  = false
            local pending = actionQueue.pendingCards()
            local isNext  = #pending == 1 and actionQueue.activeCard() == nil
            card.target.scale = isNext and card.scales.hover or card.scales.idle
          end
        end

      elseif areas.mouseInDiscard(mouseX, mouseY, wasTouch) then
        if actionQueue.isTerminal() then
          -- end turn already queued — return card immediately
          returnCardToHand(card, self)
        else
          local hand = self
          local pushed = actionQueue.push({
            card     = card,
            terminal = false,
            onReject = function(item)
              returnCardToHand(item.card, hand)
            end,
            fn = function()
              sequences.discard(card, Camera)
            end,
          })
          if pushed then
            card._excluded = true
            self:layout()
            card.hover.can = false
            card.hover.is  = false
            card.drag.can  = false
            local pending = actionQueue.pendingCards()
            local isNext  = #pending == 1 and actionQueue.activeCard() == nil
            card.target.scale = isNext and card.scales.hover or card.scales.idle
          end
        end

      else
        card.target.x = card._startX
        card.target.y = card._startY
        card._excluded = false
        self:layout()
      end
      self:unlockHand()
    end

    -- Follow mouse while dragging
    if card.drag.is then
      card.target.x = mouseX - card.drag.offsetX
      card.target.y = mouseY - card.drag.offsetY
      card.mouseX = mouseX
      card.mouseY = mouseY
    end

    -- Hover scale
    if card.hover.can and not card.hover.is and card == hoverCandidate then
      card.hover.is     = true
      card.target.scale = card.scales.hover
      card.mouseX       = mouseX
      card.mouseY       = mouseY
      card.current.r =  math.rad(10)
      Audio.playHover()
    elseif card:containsPoint(mouseX, mouseY) and card.drag.is then
      card.target.scale = card.scales.drag
    elseif card ~= hoverCandidate and not card.drag.is and card.hover.can then
      card.hover.is     = false
      card.target.scale = card.scales.idle
    elseif card.hover.is then
      card.mouseX       = mouseX
      card.mouseY       = mouseY
    end

    if card.hover.is then hoveredCard = card end

    card:update()
  end

  -- Camera state: one decision after all cards are processed
  -- Skip while a sequence is running — it manages camera itself
  if not events.isRunning() then
    if draggingCard then
      if Camera.state ~= "followMouse" then Camera:followMouse() end
    elseif hoveredCard then
      if Camera.state ~= "lookAt" or Camera.stateData.targetCard ~= hoveredCard then
        Camera:lookAt(hoveredCard)
      end
    else
      if Camera.state ~= "idle" then Camera:setIdle() end
    end
  end
end

function Hand:setActiveCardDraw(visible)
  self._suppressActiveCard = not visible
end

function Hand:draw()
  local activeCard    = actionQueue.activeCard()
  if activeCard ~= self._lastActiveCard then
    self._suppressActiveCard = false
    self._lastActiveCard     = activeCard
  end
  local pendingCards  = actionQueue.pendingCards()
  local queued = {}
  if activeCard then queued[activeCard] = true end
  for _, card in ipairs(pendingCards) do queued[card] = true end

  for _, card in ipairs(self.cards) do
    if not card.drag.is and card.stationary and not queued[card] then card:draw() end
  end
  for _, card in ipairs(self.cards) do
    if not card.drag.is and not card.stationary and not queued[card] then card:draw() end
  end
  -- reverse order so queue[1] (next to process) is drawn on top
  for i = #pendingCards, 1, -1 do pendingCards[i]:draw() end
  if activeCard and not self._suppressActiveCard then activeCard:draw() end
  for _, card in ipairs(self.cards) do
    if not card.drag.is and card.hover.is and not queued[card] then card:draw() end
  end
end

function Hand:drawDragged()
  for _, card in ipairs(self.cards) do
    if card.drag.is then card:draw() end
  end
  laser.draw()
end

function Hand:mousepressed(x, y, button, istouch)
  for _, card in ipairs(self.cards) do
    if button == 1 and card:containsPoint(x, y) and card.drag.can then
      card.hover.is     = false
      card.drag.is      = true
      card.drag.can     = false
      card.drag.offsetX = x - card.current.x
      card.drag.isTouch = istouch == true
      card.drag.offsetY = istouch
        and (card.h * SCALE_Y)
        or  (y - card.current.y)
      Camera:followMouse()
      Audio.playDrag()
      return
    end
  end
end

return Hand
