local sequences = require("core.newSequences")
local areas     = require("core.areas")
local Color  = require("lib.color")
local Camera = require("core.camera")
local events = require("lib.events")
local laser  = require("core.laser")

local Hand      = {}
Hand.__index    = Hand

function Hand.new()
  return setmetatable({ cards = {}, discardQueue = {}, deck = nil }, Hand)
end

function Hand:layout()
  local gap = 80 * SCALE_X
  local active = {}
  for _, card in ipairs(self.cards) do
    if not card._excluded then active[#active + 1] = card end
  end
  local cardW = active[1] and active[1].w * SCALE_X or 0
  local totalW = #active * cardW + math.max(#active - 1, 0) * gap
  local startX = (love.graphics.getWidth() - totalW) / 2
  local startY = love.graphics.getHeight() - 400 * SCALE_Y

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

  -- self:layout()
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

function Hand:discardQueueSize()
  return #self.discardQueue
end

function Hand:unlockHand()
  for _, card in ipairs(self.cards) do
    card.hover.can    = true
    card.hover.is     = false
    card.target.scale = card.scales.idle
    card.drag.can     = true
    card.drag.is      = false
  end
end

function Hand:update(mouseX, mouseY)
  local draggingCard = nil
  local hoveredCard = nil
  for _, card in ipairs(self.cards) do
    if card.drag.is then
      draggingCard = card; break
    end
  end

  -- Suppress hover on siblings while a card is being dragged
  if draggingCard then
    for _, card in ipairs(self.cards) do
      if card ~= draggingCard then
        card.hover.can    = false
        card.hover.is     = false
        card.target.scale = card.scales.idle
      end
    end
  end

  -- Update area highlight colors
  if areas.mouseInPlay(mouseX, mouseY) and draggingCard then
    areas.play.color = { 0.5, 0.5, 1, 1 }
    Camera:setColor(Color("#6ED59E"))
    draggingCard:setZoneState("play")
  elseif draggingCard and areas.cardInPlay(draggingCard) then
    areas.play.color = { 0.5, 0.5, 0.5, 1 }
    -- areas.play.color = {1, 1, 1, 1}
  elseif areas.mouseInPlay(mouseX, mouseY) then
    areas.play.color = { 0.5, 0.5, 0.5, 1 }
    -- areas.play.color = {0.5, 1, 0.5, 1}
  else
    areas.play.color = { 0.5, 0.5, 0.5, 1 }
  end

  if areas.mouseInDiscard(mouseX, mouseY) and draggingCard then
    areas.discard.color = { 0.5, 0.5, 1, 1 }
    Camera:setColor(Color("#D56E6E"))
    draggingCard:setZoneState("discard")
  elseif draggingCard and areas.cardInDiscard(draggingCard) then
    areas.discard.color = { 0.5, 0.5, 0.5, 1 }
    -- areas.discard.color = {1, 1, 1, 1}
  elseif areas.mouseInDiscard(mouseX, mouseY) then
    areas.discard.color = { 0.5, 0.5, 0.5, 1 }
    -- areas.discard.color = {0.5, 1, 0.5, 1}
  else
    areas.discard.color = { 0.5, 0.5, 0.5, 1 }
  end

  if draggingCard and
    not areas.mouseInPlay(mouseX, mouseY) and
    not areas.mouseInDiscard(mouseX, mouseY) then
      Camera:setColor(Color("#88EDFF"))
      draggingCard:setZoneState("idle")
  end

  -- Reorder cards when dragged card center crosses a neighbor's layout center
  if draggingCard and mouseY > love.graphics.getHeight() / 2 then
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

  for _, card in ipairs(self.cards) do
    -- Release drag
    if card.drag.is and not love.mouse.isDown(1) then
      card.drag.is   = false
      card.drag.can  = true
      card._excluded = true
      self:layout()
      if areas.mouseInPlay(mouseX, mouseY) then
        if #areas.pool.chips < card.energy then
          card:setZoneState("idle")
          Camera:setColor(Color("#88EDFF"))
          Camera:setIdle()
          screenshake.triggerH()
          card._excluded = false
          self:layout()
          card.target.x = card._startX
          card.target.y = card._startY
        else
          print("enough ram", #areas.pool.chips)
          card._excluded = true
          card.hover.can = false
          card.hover.is  = false
          card.drag.can  = false
          sequences.play(card, Camera, self)
        end
      --   if #areas.pool.chips < 2 then
      --     screenshake.triggerH()
      --     card._excluded = false
      --     self:layout()
      --     card.target.x = card._startX
      --     card.target.y = card._startY
      --   else
      --     sequences.play(card, areas, self.deck,
      --       function()
      --         self:unlockHand()
      --       end,
      --       function()
      --         self:remove(card)
      --         if self.deck then self.deck:add(card) end
      --         self:unlockHand()
      --       end
      --     )
      --   end
      elseif areas.mouseInDiscard(mouseX, mouseY) then
        table.insert(self.discardQueue, card)
        card._excluded = true
        card.hover.can = false
        card.hover.is  = false
        card.drag.can  = false
        sequences.discard(card, Camera, self)
        -- table.insert(self.discardQueue, card)
        -- -- c._excluded = true
        -- -- self:layout()
        -- sequences.discard(card, areas,
        --   function()
        --     self:unlockHand()
        --   end,
        --   function()
        --     self:remove(card)
        --   end
        -- )
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
    if card.hover.can and not card.hover.is and not card.drag.is and card:containsPoint(mouseX, mouseY) then
      card.hover.is     = true
      card.target.scale = card.scales.hover
      card.mouseX       = mouseX
      card.mouseY       = mouseY
      card.current.r =  math.rad(10)
      -- card:shake(8, 0.25)
    elseif card:containsPoint(mouseX, mouseY) and card.drag.is then
      card.target.scale = card.scales.drag
    elseif not card:containsPoint(mouseX, mouseY) and not card.drag.is and card.hover.can then
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

function Hand:draw()
  -- draw stationary cards first, then non dragging cards, then dragging cards on top
  for _, card in ipairs(self.cards) do
    if not card.drag.is and card.stationary then card:draw() end
  end
  for _, card in ipairs(self.cards) do
    if not card.drag.is and not card.stationary then card:draw() end
  end
  for _, card in ipairs(self.cards) do
    if not card.drag.is and card.hover.is then card:draw() end
  end
  for _, card in ipairs(self.cards) do
    if card.drag.is then card:draw() end
  end

  laser.draw()
end

function Hand:mousepressed(x, y, button)
  for _, card in ipairs(self.cards) do
    if button == 1 and card:containsPoint(x, y) and card.drag.can then
      card.hover.is     = false
      card.drag.is      = true
      card.drag.can     = false
      card.drag.offsetX = x - card.current.x
      card.drag.offsetY = y - card.current.y
      Camera:followMouse()
      return
    end
  end
end

return Hand
