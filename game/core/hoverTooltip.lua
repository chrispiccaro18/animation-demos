-- Tooltips for static hover zones (env icons, dtor areas, etc.)
--
-- Box sizing: min width = max(half card width, title text width + padding).
-- Anchor Y is always the desired TOP of the box (callers compute this).
--
-- Content formats (mutually exclusive per request):
--   data.effects = { { type = string }, ... }
--     → deduplicated per token type; each unique type renders as:
--         Header: colored name + token sprite  (RichText)
--         Body:   description text, wrapped
--   data.lines = { string, ... }
--     → plain wrapped text; used for non-token tooltips (env icons, area fallback)
--
-- Positioning by side:
--   "right" → box left = anchorX + gap (arrow points left toward anchor)
--   "left"  → box right = anchorX - gap (arrow points right, rotated 180°)
--   "below" → box top = anchorY + gap, centred on anchorX; no arrow
--
-- Usage:
--   hoverTooltip.load()          -- call once after Manifest.load()
--   hoverTooltip.clear()         -- each frame, before requests
--   hoverTooltip.request(id, data)
--   hoverTooltip.update()        -- after all requests; reads realDt
--   hoverTooltip.draw()          -- after glow:renderTop()

local Palette   = require("lib.palette")
local RichText  = require("core.richText")
local Manifest  = require("assets.manifest")
local animation = require("lib.animation")

local M = {}

-- ── Config ────────────────────────────────────────────────────────────────────

local BG_ALPHA       = 0.95
local DELAY          = 0.4
local FADE_SPEED     = 8
local TOTAL_GAP      = 24    -- design units: anchor edge → box edge (arrow fills this)
local ARROW_H        = 38    -- design units: rendered arrow height (width from aspect ratio)
local PAD_X          = 16    -- design units: horizontal padding inside box
local PAD_Y          = 14    -- design units: vertical padding inside box
local TITLE_BODY_GAP = 6     -- design units: gap between title and first content row
local ENTRY_LINE_GAP = 10    -- design units: extra leading between lines within an entry
local ENTRY_GAP      = 14    -- design units: extra space after each token entry
local BODY_LEAD      = 4     -- design units: extra leading between plain body lines
local LINE_WIDTH  = 4
local CORNER_R    = 24
local FONT_SIZE      = 48    -- must be loaded in Manifest.fonts
local CARD_BASE_W    = 1200  -- native px width of card-base.png (half = minimum box width)

-- ── Token data (mirrors cardTooltip) ─────────────────────────────────────────

local TOKEN_NAME = {
  progress         = "Progress",
  threat           = "Threat",
  nullify          = "Nullify",
  shuffle          = "Shuffle",
  progressNegative = "Negative Progress",
  threatNegative   = "Negative Threat",
  drawToHand       = "Draw To Hand",
  drawToDtor       = "Draw To Dtor",
  dtor             = "Dtor",
  ram              = "RAM",
}

local TOKEN_DESC = {
  progress         = "Increase system progress",
  threat           = "Increase threat level",
  nullify          = "Nullify Dtor effect",
  shuffle          = "Shuffle Dtor",
  progressNegative = "Decrease system progress",
  threatNegative   = "Decrease threat level",
  drawToHand       = "Draw a card to hand",
  drawToDtor       = "Draw a card to Dtor",
  dtor             = "Trigger Dtor effects",
  ram              = "RAM cost",
}

local TOKEN_COLOR = {
  progress         = "positive",
  threat           = "danger",
  nullify          = "nullify",
  shuffle          = "warning",
  progressNegative = "positiveNeg",
  threatNegative   = "threatNeg",
  drawToHand       = "draw",
  drawToDtor       = "warning",
  dtor             = "warning",
  ram              = "energy",
}

-- ── State ─────────────────────────────────────────────────────────────────────

local _tokens   = {}
local _requests = {}
local _prevIds  = {}
local _timers   = {}
local _alphas   = {}
local _lastData = {}
local _layouts  = {}
local _retired  = {}

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function wrapText(text, font, maxWidth)
  local result, current = {}, ""
  for word in text:gmatch("%S+") do
    local candidate = current == "" and word or (current .. " " .. word)
    if font:getWidth(candidate) <= maxWidth then
      current = candidate
    else
      if current ~= "" then result[#result + 1] = current end
      current = word
    end
  end
  if current ~= "" then result[#result + 1] = current end
  return #result > 0 and result or { text }
end

-- ── Layout ────────────────────────────────────────────────────────────────────

local function computeLayout(data, alpha)
  local font         = Manifest.getFont(FONT_SIZE)
  local fontH        = font:getHeight()
  local entryLineH   = fontH + ENTRY_LINE_GAP * SCALE_Y
  local bodyLH       = fontH + BODY_LEAD      * SCALE_Y
  local padX         = PAD_X          * SCALE_X
  local padY         = PAD_Y          * SCALE_Y
  local titleBodyGap = TITLE_BODY_GAP * SCALE_Y
  local entryG       = ENTRY_GAP      * SCALE_Y
  local gap          = TOTAL_GAP      * SCALE_X

  -- Arrow dimensions
  local arrowImg         = Manifest.get("tooltip", "arrow")
  local arrowIW, arrowIH = arrowImg:getDimensions()
  local arrowH_s         = ARROW_H * SCALE_Y
  local arrowW_s         = (arrowIW / arrowIH) * arrowH_s

  -- Box width: max(half card width, title without wrapping)
  local halfCardW = CARD_BASE_W / 2 * SCALE_X
  local titleW    = font:getWidth(data.title or "") + padX * 2
  local bw        = math.max(halfCardW, titleW)
  local textW     = bw - padX * 2

  -- Build content rows, tracking a Y cursor from box top
  local cursor       = padY + fontH + titleBodyGap  -- space consumed by title
  local entries      = {}   -- token-entry format
  local wrappedLines = {}   -- plain-line format

  if data.effects and #data.effects > 0 then
    local seen = {}
    for _, eff in ipairs(data.effects) do
      local t = eff.type
      if t and not seen[t] then
        seen[t] = true
        local colorKey   = TOKEN_COLOR[t] or "tooltipBaseText"
        local name       = TOKEN_NAME[t] or t
        local desc       = TOKEN_DESC[t] or ""
        local headerSegs = RichText.parse("{c:" .. colorKey .. "|" .. name .. "} {" .. t .. "}")
        local descLines  = wrapText(desc, font, textW)
        local entryH     = entryLineH * (1 + #descLines) + entryG
        entries[#entries + 1] = {
          headerSegs = headerSegs,
          descLines  = descLines,
          yOffset    = cursor,
        }
        cursor = cursor + entryH
      end
    end
  else
    for _, line in ipairs(data.lines or {}) do
      for _, seg in ipairs(wrapText(line, font, textW)) do
        wrappedLines[#wrappedLines + 1] = seg
      end
    end
    cursor = cursor + #wrappedLines * bodyLH
  end

  local bh = cursor + padY

  -- Box position
  local side = data.side or "right"
  local ox, oy
  if side == "right" then
    ox = data.anchorX + gap
    oy = data.anchorY
  elseif side == "left" then
    ox = data.anchorX - gap - bw
    oy = data.anchorY
  else  -- "below"
    ox = data.anchorX - bw / 2
    oy = data.anchorY + gap
  end
  if oy < padY then oy = padY end

  -- Arrow
  local arrow = nil
  if side == "right" then
    arrow = {
      x  = ox - arrowW_s, y  = oy,
      r  = 0,
      sx = arrowW_s / arrowIW, sy = arrowH_s / arrowIH,
      ix = 0, iy = 0,
    }
  elseif side == "left" then
    arrow = {
      x  = ox + bw + arrowW_s / 2, y = oy + arrowH_s / 2,
      r  = math.pi,
      sx = arrowW_s / arrowIW, sy = arrowH_s / arrowIH,
      ix = arrowIW / 2, iy = arrowIH / 2,
    }
  end

  return {
    ox           = ox, oy           = oy,
    bw           = bw, bh           = bh,
    alpha        = alpha,
    font         = font, fontH        = fontH,
    entryLineH   = entryLineH, bodyLH = bodyLH,
    padX         = padX, padY         = padY,
    titleBodyGap = titleBodyGap,
    title        = data.title, titleColor = data.titleColor,
    entries      = entries, wrappedLines = wrappedLines,
    arrowImg     = arrowImg, arrow        = arrow,
    arrowYOffset = data.arrowYOffset or 0,
  }
end

-- ── Public API ────────────────────────────────────────────────────────────────

function M.load()
  for name in pairs(TOKEN_DESC) do
    local ok, img = pcall(Manifest.get, "tokens", name)
    if ok then _tokens[name] = img end
  end
end

function M.clear()
  _prevIds = {}
  for _, req in ipairs(_requests) do _prevIds[req.id] = true end
  _requests = {}
  _layouts  = {}
end

function M.request(id, data)
  if not _prevIds[id] then
    _timers[id] = (_alphas[id] or 0) > 0.05 and DELAY or 0
  end
  _lastData[id] = data
  _requests[#_requests + 1] = { id = id, data = data }
end

function M.update()
  local dt      = realDt
  local activeIds = {}
  for _, req in ipairs(_requests) do activeIds[req.id] = true end

  for id in pairs(_prevIds) do
    if not activeIds[id] then _retired[id] = true end
  end
  for id in pairs(activeIds) do _retired[id] = nil end

  for _, req in ipairs(_requests) do
    local id = req.id
    _timers[id] = (_timers[id] or 0) + dt
    local target = (_timers[id] >= DELAY) and 1.0 or 0.0
    _alphas[id]  = animation.expDecay(_alphas[id] or 0, target, FADE_SPEED, dt)
    if _alphas[id] > 0.01 then
      _layouts[#_layouts + 1] = computeLayout(req.data, _alphas[id])
    end
  end

  local done = {}
  for id in pairs(_retired) do
    _alphas[id] = animation.expDecay(_alphas[id] or 0, 0, FADE_SPEED, dt)
    if _alphas[id] <= 0.01 then
      done[#done + 1] = id
    elseif _lastData[id] then
      _layouts[#_layouts + 1] = computeLayout(_lastData[id], _alphas[id])
    end
  end
  for _, id in ipairs(done) do
    _retired[id]  = nil
    _timers[id]   = 0
    _lastData[id] = nil
  end
end

function M.draw()
  if #_layouts == 0 then return end

  local bg     = Palette.tooltipBG
  local border = Palette.tooltipBorder
  local tc     = Palette.tooltipBaseText

  for _, L in ipairs(_layouts) do
    local a = L.alpha

    -- Arrow (drawn first so box border overlaps the join)
    if L.arrow then
      local ar = L.arrow
      love.graphics.setColor(1, 1, 1, a)
      love.graphics.draw(L.arrowImg, ar.x, ar.y + L.arrowYOffset, ar.r, ar.sx, ar.sy, ar.ix, ar.iy)
    end

    -- Background
    love.graphics.setColor(bg[1], bg[2], bg[3], (bg[4] or 1) * BG_ALPHA * a)
    love.graphics.rectangle("fill", L.ox, L.oy, L.bw, L.bh,
      CORNER_R * SCALE_X, CORNER_R * SCALE_Y)

    -- Border
    local previousLineWidth = love.graphics.getLineWidth()
    love.graphics.setLineWidth(LINE_WIDTH * SCALE_X)
    love.graphics.setColor(border[1], border[2], border[3], (border[4] or 1) * a)
    love.graphics.rectangle("line", L.ox, L.oy, L.bw, L.bh,
      CORNER_R * SCALE_X, CORNER_R * SCALE_Y)
    love.graphics.setLineWidth(previousLineWidth)

    love.graphics.setFont(L.font)

    -- Title
    local tc2 = L.titleColor or tc
    love.graphics.setColor(tc2[1], tc2[2], tc2[3], (tc2[4] or 1) * a)
    love.graphics.print(L.title or "", L.ox + L.padX, L.oy + L.padY)

    -- Token entries (effects format)
    for _, entry in ipairs(L.entries) do
      local headerY = L.oy + entry.yOffset
      RichText.draw(entry.headerSegs, L.ox + L.padX, headerY, {
        font       = L.font,
        tokens     = _tokens,
        alpha      = a,
        gap        = 6 * SCALE_X,
        spriteSize = L.fontH,
      })
      love.graphics.setFont(L.font)
      love.graphics.setColor(tc[1], tc[2], tc[3], (tc[4] or 1) * a)
      for j, descLine in ipairs(entry.descLines) do
        love.graphics.print(descLine, L.ox + L.padX, headerY + L.entryLineH * j)
      end
    end

    -- Plain body lines (lines format)
    if #L.wrappedLines > 0 then
      love.graphics.setColor(tc[1], tc[2], tc[3], (tc[4] or 1) * a)
      local bodyTop = L.oy + L.padY + L.fontH + L.titleBodyGap
      for i, line in ipairs(L.wrappedLines) do
        love.graphics.print(line, L.ox + L.padX, bodyTop + (i - 1) * L.bodyLH)
      end
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
end

return M
