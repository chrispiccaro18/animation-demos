local events        = require("lib.events")
local projectiles   = require("core.projectiles")
local animation    = require("lib.animation")
local areas       = require("core.areas")
local Token       = require("core.token")
local Color = require("lib.color")

local sequences = {}

local discardDeskArea = {
  x = areas.desk.x + areas.desk.w * 0.6,
  y = areas.desk.y + areas.desk.h * 0.25,
  w = areas.desk.w * 0.3,
  h = areas.desk.h * 0.5,
}

function sequences.discard(card, camera, laser)
  events.push({
    fn = function()
      card.hover.can = false
      card.hover.is  = false
      card.drag.can  = false
      card.drag.is   = false
      card.target.scale = card.scales.hover
      card.drawShadow = false
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
      laser.hidden = false
      laser.origin.x = lensX
      laser.origin.y = lensY
      laser.target.x = card.current.x
      laser.target.y = card.current.y
      screenshake.trigger(10, 0.25)
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0.5, type = "after"
  })
  events.push({
    fn = function()
      laser.hidden = true
      laser.origin.x = 0
      laser.origin.y = 0
      laser.target.x = 0
      laser.target.y = 0
      card:startDissolve()
      Token.new_fling(
        card.current.x,
        card.current.y,
        discardDeskArea,
        {
          bounces = math.random(2, 3),
          type = "ram",
        }
      )
      Token.new_fling(
        card.current.x,
        card.current.y,
        discardDeskArea,
        {
          bounces = math.random(2, 3),
          type = "ram",
        }
      )
      Token.new_fling(
        card.current.x,
        card.current.y,
        discardDeskArea,
        {
          bounces = math.random(2, 3),
          type = "ram",
        }
      )
      Token.new_fling(
        card.current.x,
        card.current.y,
        discardDeskArea,
        {
          bounces = math.random(2, 3),
          type = "progress",
        }
      )
      Token.new_fling(
        card.current.x,
        card.current.y,
        discardDeskArea,
        {
          bounces = math.random(2, 3),
          type = "threat",
        }
      )
      Token.new_fling(
        card.current.x,
        card.current.y,
        discardDeskArea,
        {
          bounces = math.random(2, 3),
          type = "nullify",
        }
      )
      Token.new_fling(
        card.current.x,
        card.current.y,
        discardDeskArea,
        {
          bounces = math.random(2, 3),
          type = "dtor",
        }
      )
    end,
    blocking = true, blockable = true, persistent = false,
    delay = 0, type = "before"
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
      camera:setColor(Color("#D56E6E"))
      Token.attractDone("ram", areas.pool)
      Token.attractDone(
        "dtor",
        function(_token)
          return areas.claimDtorSlot()
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
end

return sequences
