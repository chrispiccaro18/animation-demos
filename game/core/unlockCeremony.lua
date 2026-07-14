local AssetManifest = require("assets.manifest")
local Palette       = require("lib.palette")
local Button         = require("core.button")
local animation      = require("lib.animation")
local Audio          = require("assets.audio")
local hoverTooltip   = require("core.hoverTooltip")

-- Full-screen celebration shown when a level-complete crosses a token-unlock
-- threshold (see main.lua's gameOver == "levelComplete" handling). Runs
-- ahead of cardPickScreen: main.lua calls M.show(tokenTypes, onDone), and
-- onDone (wired to cardPickScreen.show(...)) fires once the player presses
-- CONTINUE and the fade-out finishes.
--
-- Self-contained dt-driven phase state machine rather than lib/events --
-- the global event queues aren't ticked while this screen gates
-- love.update (same reason cardPickScreen doesn't drive its own reveal via
-- events either; see main.lua).
local M = {}

local TITLE_Y     = 450
local TITLE_SIZE  = 120
local ICON_Y      = 1100
local ICON_SIZE   = 320
local ICON_GAP    = 60
local ICON_HOVER_BUFFER = 20
local NAME_GAP    = 30
local NAME_SIZE   = 48
local CONTINUE_Y  = 1720
local CONTINUE_W  = 560
local CONTINUE_H  = 180

local ICON_IN_RATE   = 10
local ALPHA_RATE     = 6
local FADE_DONE_EPS  = 0.02

local _active     = false
local _phase      = nil -- "showing" | "hiding"
local _onDone     = nil
local _icons      = {}
local _titleText  = ""
local _titleCurrent = { scale = 6, alpha = 0 }
local _titleTarget  = { scale = 1, alpha = 1 }

local _titleFont = nil
local _nameFont  = nil

local _continueBtn  = nil
local _continueBtnX = 0
local _continueBtnY = 0
local _continueBtnW = 0
local _continueBtnH = 0

local function beginHide()
  if not _active or _phase == "hiding" then return end
  _phase = "hiding"
  _titleTarget.alpha = 0
  for _, icon in ipairs(_icons) do icon.target.alpha = 0 end
end

function M.load()
  _titleFont = AssetManifest.getFont(TITLE_SIZE)
  _nameFont  = AssetManifest.getFont(NAME_SIZE)

  local cw = SCALE_X * 3840
  _continueBtnW = CONTINUE_W * SCALE_X
  _continueBtnH = CONTINUE_H * SCALE_Y
  _continueBtnX = (cw - _continueBtnW) / 2
  _continueBtnY = CONTINUE_Y * SCALE_Y
  _continueBtn = Button.new(_continueBtnX, _continueBtnY, _continueBtnW, _continueBtnH, "CONTINUE", 72, beginHide)
end

local function layoutIcons(tokenTypes)
  local cw = SCALE_X * 3840
  local n  = #tokenTypes
  local totalW = n * ICON_SIZE + (n - 1) * ICON_GAP
  local startX = (cw - totalW * SCALE_X) / 2 + (ICON_SIZE * SCALE_X) / 2
  local icons = {}
  for i, tokenType in ipairs(tokenTypes) do
    icons[#icons + 1] = {
      tokenType = tokenType,
      asset     = AssetManifest.get("tokens", tokenType),
      name      = hoverTooltip.getTokenName(tokenType),
      x         = startX + (i - 1) * (ICON_SIZE + ICON_GAP) * SCALE_X,
      y         = ICON_Y * SCALE_Y,
      hovered   = false,
      current   = { scale = 0, alpha = 0 },
      target    = { scale = 1, alpha = 1 },
    }
  end
  return icons
end

-- tokenTypes: array of newly-unlocked token type strings (see
-- core/unlocks.lua's Unlocks.newlyUnlocked). onDone: called once the
-- ceremony finishes hiding itself.
function M.show(tokenTypes, onDone)
  _active    = true
  _phase     = "showing"
  _onDone    = onDone
  _icons     = layoutIcons(tokenTypes)

  _titleText = (#tokenTypes > 1)
    and (#tokenTypes .. " TOKENS UNLOCKED")
    or "TOKEN UNLOCKED"
  _titleCurrent.scale = 6
  _titleCurrent.alpha = 0
  _titleTarget.scale  = 1
  _titleTarget.alpha  = 1

  Audio.playSuccess()
end

function M.isActive() return _active end

function M.update(dt, mx, my)
  if not _active then return end

  _titleCurrent.scale = animation.expDecay(_titleCurrent.scale, _titleTarget.scale, ICON_IN_RATE, dt)
  _titleCurrent.alpha = animation.expDecay(_titleCurrent.alpha, _titleTarget.alpha, ALPHA_RATE, dt)

  local hw = (ICON_SIZE * SCALE_X) / 2 + ICON_HOVER_BUFFER
  local hh = (ICON_SIZE * SCALE_Y) / 2 + ICON_HOVER_BUFFER
  for _, icon in ipairs(_icons) do
    icon.current.scale = animation.expDecay(icon.current.scale, icon.target.scale, ICON_IN_RATE, dt)
    icon.current.alpha = animation.expDecay(icon.current.alpha, icon.target.alpha, ALPHA_RATE, dt)
    icon.hovered = _phase == "showing"
      and mx and my
      and math.abs(mx - icon.x) <= hw and math.abs(my - icon.y) <= hh
  end

  if _phase == "showing" then
    _continueBtn:update(mx, my)
  end

  if _phase == "hiding" and _titleCurrent.alpha <= FADE_DONE_EPS then
    local onDone = _onDone
    _active    = false
    _phase     = nil
    _icons     = {}
    _onDone    = nil
    _titleText = ""
    if onDone then onDone() end
  end
end

function M.collectGlowRequests(glow)
  if not _active then return end
  for _, icon in ipairs(_icons) do
    if icon.asset then
      local iw, ih = icon.asset:getDimensions()
      glow:request("unlockCeremony-" .. icon.tokenType, {
        kind  = "image",
        image = icon.asset,
        x     = icon.x,
        y     = icon.y,
        sx    = icon.current.scale * SCALE_X,
        sy    = icon.current.scale * SCALE_Y,
        ox    = iw / 2,
        oy    = ih / 2,
        color = Palette.accent,
        alpha = icon.current.alpha * 0.6,
        pulse = { speed = 1.5, min = 0.3, max = 1.0 },
        light = { radius = iw * SCALE_X / 2, alpha = icon.current.alpha * 0.35 },
      }, "top")
    end
  end
  if _phase == "showing" then
    glow:request("unlockCeremony-continue", {
      kind  = "rect",
      cx    = _continueBtnX + _continueBtnW * 0.5,
      cy    = _continueBtnY + _continueBtnH * 0.5,
      w     = _continueBtnW,
      h     = _continueBtnH,
      color = Palette.accent,
      alpha = 0.55,
      pulse = { speed = 1.5, min = 0.2, max = 1.0 },
      light = { radius = 60 * SCALE_X, alpha = 0.4 },
    }, "top")
  end
end

function M.collectTooltipRequests()
  if not _active then return end
  for _, icon in ipairs(_icons) do
    if icon.hovered then
      hoverTooltip.request("unlockCeremony_" .. icon.tokenType, {
        effects = { { type = icon.tokenType } },
        anchorX = icon.x,
        anchorY = icon.y + (ICON_SIZE * SCALE_Y) / 2,
        side    = "below",
      })
    end
  end
end

function M.draw()
  if not _active then return end

  local cw = SCALE_X * 3840
  local ch = SCALE_Y * 2160

  love.graphics.setColor(Palette.void)
  -- love.graphics.setColor(0, 0, 0, 0.78)
  love.graphics.rectangle("fill", 0, 0, cw, ch)
  love.graphics.setColor(1, 1, 1, 1)

  if _titleFont and _titleText ~= "" then
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(_titleFont)
    local tw = _titleFont:getWidth(_titleText)
    local th = _titleFont:getHeight()
    love.graphics.push()
    love.graphics.translate(cw / 2, TITLE_Y * SCALE_Y + th / 2)
    love.graphics.scale(_titleCurrent.scale, _titleCurrent.scale)
    love.graphics.setColor(Palette.accent[1], Palette.accent[2], Palette.accent[3], _titleCurrent.alpha)
    love.graphics.print(_titleText, -tw / 2, -th / 2)
    love.graphics.pop()
    love.graphics.setFont(prevFont)
    love.graphics.setColor(1, 1, 1, 1)
  end

  for _, icon in ipairs(_icons) do
    local a = icon.current.alpha
    if a > 0.01 then
      local sz = ICON_SIZE * SCALE_X * icon.current.scale
      love.graphics.setColor(Palette.accent[1], Palette.accent[2], Palette.accent[3], a)
      love.graphics.setLineWidth(3 * math.max(SCALE_X, SCALE_Y))
      love.graphics.rectangle("line", icon.x - sz / 2, icon.y - sz / 2, sz, sz, 8 * SCALE_X, 8 * SCALE_Y)
      love.graphics.setLineWidth(1)

      if icon.asset then
        local iw, ih = icon.asset:getDimensions()
        local s = math.min(sz * 0.70 / iw, sz * 0.70 / ih)
        love.graphics.setColor(1, 1, 1, a)
        love.graphics.draw(icon.asset, icon.x, icon.y, 0, s, s, iw / 2, ih / 2)
      end

      -- if _nameFont then
      --   local prevFont = love.graphics.getFont()
      --   love.graphics.setFont(_nameFont)
      --   local nw = _nameFont:getWidth(icon.name)
      --   love.graphics.setColor(1, 1, 1, a)
      --   love.graphics.print(icon.name, icon.x - nw / 2, icon.y + sz / 2 + NAME_GAP * SCALE_Y)
      --   love.graphics.setFont(prevFont)
      -- end
    end
  end

  if _phase == "showing" then _continueBtn:draw() end

  love.graphics.setColor(1, 1, 1, 1)
end

function M.mousepressed(mx, my, btn)
  if not _active or btn ~= 1 or _phase ~= "showing" then return false end
  return _continueBtn:mousepressed(mx, my, btn)
end

function M.touchpressed(tx, ty)
  return M.mousepressed(tx, ty, 1)
end

return M
