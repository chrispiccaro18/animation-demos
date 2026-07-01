-- core/tutorial.lua
-- Tutorial overlay drawn inside the game canvas (not screen space).
-- Renders the vignette then a centered rich-text content box on top.

local Palette  = require("lib.palette")
local RichText = require("core.richText")
local Manifest = require("assets.manifest")

local M = {}

local FONT_SIZE    = 48
local BOX_W_D      = 2200
local PAD_X_D      = 80
local PAD_Y_D      = 64
local EXTRA_LEAD_D = 14
local PARA_GAP_D   = 44
local CORNER_R_D   = 28
local LINE_W_D     = 4
local BG_ALPHA     = 0.90
local SPRITE_GAP_D = 8

local _vignette = nil
local _tokens   = {}

local ARROW = "=>"

local PARAGRAPHS = {
  {
    "Your goal is to fulfill {c:positive|PROGRESS LEVEL} before {c:danger|THREAT LEVEL}.",
    "{progress} = {c:positive|PROGRESS}, {threat} = {c:danger|THREAT}",
    -- "Your goal is to fill {c:positive|PROGRESS} ({progress} " .. ARROW .. " {progressTick}) before {c:danger|THREAT}  {threat} " .. ARROW .. " {threatTick}.",
  },
  {
    "{c:draw|DISCARD} cards to gain {c:energy|RAM}. {c:draw|PLAY} cards by spending {c:energy|RAM}.",
    -- "{c:draw|DISCARD} cards to gain {c:energy|RAM}.",
    -- "{c:draw|PLAY} cards by spending {c:energy|RAM}.",
    "{ram} = {c:energy|RAM}",
  },
  {
    "Discarded cards also add their {c:warning|DTOR} effect to the {c:warning|DTOR} Queue.",
    "{dtor*5} = {c:warning|DTOR} effect",
  },
  {
    "When you {c:accent|END TURN}:",
    " - the top {c:warning|DTOR} effect triggers",
    " - active ENV effects trigger",
    " - that {c:warning|DTOR} card returns to the bottom of your draw pile",
    " - your hand refills",
  },
  {
    '"R" or three finger tap on touch resets the game. Feel free to experiment!',
  },
  {
    "Enter/Return or two finger tap on touch to toggle this message.",
  },
}

local function wrapRichText(str, font, maxW, spriteSize, gap)
  gap        = gap or 0
  spriteSize = spriteSize or font:getHeight()
  local segs = RichText.parse(str)

  -- Fast path: return original segments when the whole string fits.
  -- Preserves all original spacing (spaces around tokens, punctuation, etc.).
  if RichText.measure(segs, font, spriteSize, gap) <= maxW then
    return { segs }
  end

  -- Slow path: word-wrap for long text-heavy strings.
  local lines = {}
  local cur   = {}
  local curW  = 0

  local function flush()
    if #cur > 0 then lines[#lines + 1] = cur end
    cur  = {}
    curW = 0
  end

  local function addWord(type_, word, color)
    local content = curW > 0 and (" " .. word) or word
    local w       = font:getWidth(content)
    if curW > 0 and curW + w > maxW then
      flush()
      content = word
      w       = font:getWidth(word)
    end
    cur[#cur + 1] = { type = type_, content = content, color = color }
    curW = curW + w
  end

  local function addToken(seg)
    local w = spriteSize + gap
    if curW > 0 and curW + w > maxW then flush() end
    cur[#cur + 1] = seg
    curW = curW + w
  end

  for _, seg in ipairs(segs) do
    if seg.type == "text" or seg.type == "span" then
      for word in seg.content:gmatch("%S+") do
        addWord(seg.type, word, seg.color)
      end
    elseif seg.type == "token" then
      addToken(seg)
    end
  end
  flush()
  return lines
end

function M.load()
  local ok, v

  ok, v = pcall(Manifest.get, "board", "fullScreenVignette")
  if ok then _vignette = v end

  local function tryLoad(key, cat, name)
    ok, v = pcall(Manifest.get, cat, name)
    if ok then _tokens[key] = v end
  end

  tryLoad("progress",     "tokens", "progress")
  tryLoad("threat",       "tokens", "threat")
  tryLoad("ram",          "tokens", "ram")
  tryLoad("dtor",         "tokens", "dtorExample")
  tryLoad("progressTick", "ticks",  "progress")
  tryLoad("threatTick",   "ticks",  "threat")
  tryLoad("ramSlot",      "card",   "ramHole")
  tryLoad("dtorSlot",     "card",   "dtorSlot")
end

function M.draw()
  local canvas = love.graphics.getCanvas()
  local cw, ch = canvas:getDimensions()

  if _vignette then
    local vw, vh = _vignette:getDimensions()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(_vignette, 0, 0, 0, cw / vw, ch / vh)
  end

  local font    = Manifest.getFont(FONT_SIZE)
  local fontH   = font:getHeight()
  local lineH   = fontH + EXTRA_LEAD_D * SCALE_Y
  local padX    = PAD_X_D * SCALE_X
  local padY    = PAD_Y_D * SCALE_Y
  local paraGap = PARA_GAP_D * SCALE_Y
  local spriteS = fontH
  local gap     = SPRITE_GAP_D * SCALE_X
  local boxW    = BOX_W_D * SCALE_X
  local textW   = boxW - padX * 2

  local wrappedParas = {}
  for _, para in ipairs(PARAGRAPHS) do
    local wp = {}
    for _, str in ipairs(para) do
      for _, line in ipairs(wrapRichText(str, font, textW, spriteS, gap)) do
        wp[#wp + 1] = line
      end
    end
    wrappedParas[#wrappedParas + 1] = wp
  end

  local contentH = 0
  for i, para in ipairs(wrappedParas) do
    contentH = contentH + #para * lineH
    if i < #wrappedParas then
      contentH = contentH + paraGap
    end
  end
  local boxH = contentH + padY * 2
  local boxX = (cw - boxW) / 2
  local boxY = (ch - boxH) / 2

  local bg = Palette.tooltipBG
  love.graphics.setColor(bg[1], bg[2], bg[3], (bg[4] or 1) * BG_ALPHA)
  love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, CORNER_R_D * SCALE_X, CORNER_R_D * SCALE_Y)

  local prevLW = love.graphics.getLineWidth()
  love.graphics.setLineWidth(LINE_W_D * SCALE_X)
  local border = Palette.tooltipBorder
  love.graphics.setColor(border[1], border[2], border[3], border[4] or 1)
  love.graphics.rectangle("line", boxX, boxY, boxW, boxH, CORNER_R_D * SCALE_X, CORNER_R_D * SCALE_Y)
  love.graphics.setLineWidth(prevLW)

  local curY  = boxY + padY
  local nPara = #wrappedParas

  for pi, para in ipairs(wrappedParas) do
    local defKey = (pi == nPara) and "muted" or "tooltipBaseText"
    for _, lineSegs in ipairs(para) do
      RichText.draw(lineSegs, boxX + padX, curY, {
        font         = font,
        tokens       = _tokens,
        gap          = gap,
        spriteSize   = spriteS,
        defaultColor = defKey,
      })
      love.graphics.setFont(font)
      curY = curY + lineH
    end
    if pi < nPara then
      curY = curY + paraGap
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
end

return M
