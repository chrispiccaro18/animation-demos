local AssetManifest = require("assets.manifest")
local animation     = require("lib.animation")

local message = {
  text         = "",
  subtitle     = "",
  textColor    = { 1, 1, 1, 1 },
  subtitleColor = { 1, 1, 1, 0.7 },
  current      = { scale = 1 },
  target       = { scale = 1 },
}

local messageFont  = nil
local subtitleFont = nil
local W, H

function message.load()
  W             = SCALE_X * 3840
  H             = SCALE_Y * 2160
  messageFont   = AssetManifest.getFont(240)
  subtitleFont  = AssetManifest.getFont(120)
end

function message.update(dt)
  message.current.scale = animation.expDecay(message.current.scale, message.target.scale, 18, dt)
end

function message.draw()
  if not (messageFont and message.text ~= "") then return end
  local s        = message.current.scale
  local prevFont = love.graphics.getFont()
  love.graphics.setFont(messageFont)
  local textW = messageFont:getWidth(message.text)
  local textH = messageFont:getHeight()
  love.graphics.push()
  love.graphics.translate(W / 2, H / 2)
  love.graphics.scale(s, s)
  love.graphics.setColor(message.textColor)
  love.graphics.print(message.text, -textW / 2, -textH / 2)
  if subtitleFont and message.subtitle ~= "" then
    love.graphics.setFont(subtitleFont)
    local subW = subtitleFont:getWidth(message.subtitle)
    love.graphics.setColor(message.subtitleColor)
    love.graphics.print(message.subtitle, -subW / 2, textH / 2 + 20)
  end
  love.graphics.pop()
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setFont(prevFont)
end

return message
