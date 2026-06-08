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
  w = areas.desk.w * 0.3,
  h = areas.desk.h * 0.5,
}

local discardDeskFullRect = {
  x = areas.desk.x + areas.desk.w / 2,
  y = areas.desk.y,
  w = areas.desk.w / 2,
  h = areas.desk.h,
}

function sequences.discard(card, camera, hand)
  events.push({
    fn = function()
      card.hover.can = false
      card.hover.is  = false
      card.drag.can  = false
      card.drag.is   = false
      card.target.scale = card.scales.hover
      card.drawShadow = false
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
      return math.abs(card.current.y - card.target.y) < 1 and
              math.abs(card.current.x - card.target.x) < 1
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
      Token.new_fling(
        card.current.x,
        card.current.y,
        discardDeskFullRect,
        {
          bounces = math.random(2, 3),
          type = "ram",
          target_rect = discardDeskArea,
          delay = false,
        }
      )
      Token.new_fling(
        card.current.x,
        card.current.y,
        discardDeskFullRect,
        {
          bounces = math.random(2, 3),
          type = "ram",
          target_rect = discardDeskArea,
          delay = false,
        }
      )
      Token.new_fling(
        card.current.x,
        card.current.y,
        discardDeskFullRect,
        {
          bounces = math.random(2, 3),
          type = "ram",
          target_rect = discardDeskArea,
          delay = false,
        }
      )
      Token.new_fling(
        card.current.x,
        card.current.y,
        discardDeskFullRect,
        {
          bounces = math.random(2, 3),
          type = "progress",
          target_rect = discardDeskArea,
          delay = false,
        }
      )
      Token.new_fling(
        card.current.x,
        card.current.y,
        discardDeskFullRect,
        {
          bounces = math.random(2, 3),
          type = "threat",
          target_rect = discardDeskArea,
          delay = false,
        }
      )
      Token.new_fling(
        card.current.x,
        card.current.y,
        discardDeskFullRect,
        {
          bounces = math.random(2, 3),
          type = "nullify",
          target_rect = discardDeskArea,
          delay = false,
        }
      )
      Token.new_fling(
        card.current.x,
        card.current.y,
        discardDeskFullRect,
        {
          bounces = math.random(2, 3),
          type = "dtor",
          target_rect = discardDeskArea,
          delay = false,
        }
      )
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
      card.hover.can = false
      card.hover.is  = false
      card.drag.can  = false
      card.drag.is   = false
      card.target.scale = card.scales.hover
      card.drawShadow = false
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
      return math.abs(card.current.y - card.target.y) < 1 and
              math.abs(card.current.x - card.target.x) < 1
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
      local ramChips = areas.consumePoolChips(3)
      if #ramChips < 3 then
        print("not enough ram to play card, returning to hand", #ramChips)
        for _, chip in ipairs(ramChips) do
          areas.addPoolChip(chip.x, chip.y)
        end
        card:returnToIdle()
        Camera:setIdle()
      else
        print("enough ram to play card", #ramChips)
        local ramPartPosition = card:getPartPositionById("topEnergyHoles")
        for i, chip in ipairs(ramChips) do
          Token.new_attract(
            chip.x,
            chip.y,
            ramPartPosition.x,
            -- card.current.x + (270 * SCALE_X) + ((i - 1) * (109 * SCALE_X)),
            ramPartPosition.y,
            {
              type = "ram",
              target_scale = 1,
            }
          )
        end
      end
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "immediate"
  })
  -- events.push({
  --   fn = function()
  --     return laser.isDone()
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0, type = "poll"
  -- })
  -- events.push({
  --   fn = function()
  --     camera:setColor(Color("#D56E6E"))
  --     laser.hide()
  --     card:startDissolve()
  --     Token.new_fling(
  --       card.current.x,
  --       card.current.y,
  --       discardDeskFullRect,
  --       {
  --         bounces = math.random(2, 3),
  --         type = "ram",
  --         target_rect = discardDeskArea,
  --         delay = false,
  --       }
  --     )
  --     Token.new_fling(
  --       card.current.x,
  --       card.current.y,
  --       discardDeskFullRect,
  --       {
  --         bounces = math.random(2, 3),
  --         type = "ram",
  --         target_rect = discardDeskArea,
  --         delay = false,
  --       }
  --     )
  --     Token.new_fling(
  --       card.current.x,
  --       card.current.y,
  --       discardDeskFullRect,
  --       {
  --         bounces = math.random(2, 3),
  --         type = "ram",
  --         target_rect = discardDeskArea,
  --         delay = false,
  --       }
  --     )
  --     Token.new_fling(
  --       card.current.x,
  --       card.current.y,
  --       discardDeskFullRect,
  --       {
  --         bounces = math.random(2, 3),
  --         type = "progress",
  --         target_rect = discardDeskArea,
  --         delay = false,
  --       }
  --     )
  --     Token.new_fling(
  --       card.current.x,
  --       card.current.y,
  --       discardDeskFullRect,
  --       {
  --         bounces = math.random(2, 3),
  --         type = "threat",
  --         target_rect = discardDeskArea,
  --         delay = false,
  --       }
  --     )
  --     Token.new_fling(
  --       card.current.x,
  --       card.current.y,
  --       discardDeskFullRect,
  --       {
  --         bounces = math.random(2, 3),
  --         type = "nullify",
  --         target_rect = discardDeskArea,
  --         delay = false,
  --       }
  --     )
  --     Token.new_fling(
  --       card.current.x,
  --       card.current.y,
  --       discardDeskFullRect,
  --       {
  --         bounces = math.random(2, 3),
  --         type = "dtor",
  --         target_rect = discardDeskArea,
  --         delay = false,
  --       }
  --     )
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0, type = "immediate"
  -- })
  -- events.push({
  --   fn = function()
  --     return not Token.isActive()
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0, type = "poll"
  -- })
  -- events.push({
  --   fn = function()
  --     Token.attractDone("ram", areas.pool)
  --     Token.attractDone(
  --       "dtor",
  --       function(_token)
  --         return areas.reserveDtorSlot()
  --       end,
  --       {
  --         target_rotation = 0,
  --         target_scale = 1.5,
  --         initial_speed = 700,
  --       }
  --     )
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0, type = "immediate"
  -- })
  -- events.push({
  --   fn = function()
  --     return Token.allDone()
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0, type = "poll"
  -- })
  -- events.push({
  --   fn = function()
  --     local ramTokens = Token.removeDone("ram")
  --     for _, t in ipairs(ramTokens) do
  --       areas.addPoolChip(t.x, t.y)
  --     end
  --     local dtorTokens = Token.removeDone("dtor")
  --     for _, t in ipairs(dtorTokens) do
  --       if t.dest_meta and t.dest_meta.index then
  --         areas.claimDtorSlot(t.dest_meta.index, t.scale)
  --       end
  --     end
  --     areas.scanner.right.active = true
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 1.5, type = "after"
  -- })
  -- events.push({
  --   fn = function()
  --     Token.attractDone("progress", areas.progressDestination, { target_scale = 1.5 })
  --     Token.attractDone("threat", areas.threatDestination , { target_scale = 1.5 })
  --     Token.attractDone("nullify", areas.nextUnnullifiedDtorSlot(), { target_scale = 1.5 })
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0.5, type = "after"
  -- })
  -- events.push({
  --   fn = function()
  --     return Token.allDone()
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0, type = "poll"
  -- })
  -- events.push({
  --   fn = function()
  --     local removedTokens = Token.removeDone()
  --     for _, t in ipairs(removedTokens) do
  --       if t.token_type == "progress" then
  --         areas.progressBar.count = math.min(areas.progressBar.count + 1, 5)
  --       elseif t.token_type == "threat" then
  --         areas.threatBar.count = math.min(areas.threatBar.count + 1, 5)
  --       elseif t.token_type == "nullify" then
  --         areas.nullifyNextDtorSlot()
  --       end
  --     end
  --     -- card.current.x = love.graphics.getWidth() + 400 * SCALE_X
  --     Camera:setIdle()
  --     hand:remove(card)
  --   end,
  --   blocking = true, blockable = true, persistent = false,
  --   delay = 0, type = "immediate"
  -- })
end

return sequences
