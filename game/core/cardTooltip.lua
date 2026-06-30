-- Card-specific tooltip: header + description per unique token type, play → discard → dtor.
-- Anchors to card top-right; box appears to the right, top-aligned.
-- Arrow sits in the gap between card edge and box left.

local Palette   = require("lib.palette")
local RichText  = require("core.richText")
local animation = require("lib.animation")
local Manifest  = require("assets.manifest")

local M = {}

-- ── Config ────────────────────────────────────────────────────────────────────

local BG_ALPHA    = 1.0    -- base background alpha for box
local DELAY       = 0.15   -- seconds hovered before tooltip appears
local FADE_SPEED  = 16      -- expDecay lambda for alpha transitions
local TOTAL_GAP_X = 24     -- design units: card right → tooltip left (arrow fills this)
local ARROW_H     = 38     -- design units: rendered arrow height (width scales from aspect)
local PAD_X       = 20     -- design units: horizontal padding inside box
local PAD_Y       = 18     -- design units: vertical padding inside box
local LINE_GAP    = 10     -- design units: extra vertical space between each text line
local ENTRY_GAP   = 14     -- design units: extra space below each token entry
local CORNER_R    = 8      -- design units: box rounded-corner radius
local FONT_SIZE   = 48     -- design font size (must be in Manifest.fonts)

-- ── Token data ────────────────────────────────────────────────────────────────

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
  shuffle          = "draw",
  progressNegative = "positiveNeg",
  threatNegative   = "threatNeg",
  drawToHand       = "draw",
  drawToDtor       = "draw",
  dtor             = "warning",
  ram              = "energy",
}

-- ── State ─────────────────────────────────────────────────────────────────────

local _requests      = {}
local _prevIds       = {}
local _timers        = {}
local _alphas        = {}
local _layouts       = {}
local _lastLayouts   = {}
local _extendedHover = {}
local _retired       = {}  -- ids fading out; persists until alpha < 0.01
local _tokens        = {}

-- ── Helpers ───────────────────────────────────────────────────────────────────

function M.load()
  for name in pairs(TOKEN_DESC) do
    local ok, img = pcall(Manifest.get, "tokens", name)
    if ok then _tokens[name] = img end
  end
end

local function collectTokenTypes(data)
  local seen, types = {}, {}
  -- guard each zone against nil so ipairs doesn't stop early on missing discard
  for _, zone in ipairs({ data.play or {}, data.discard or {}, data.dtor or {} }) do
    for _, effect in ipairs(zone) do
      if effect.type and not seen[effect.type] then
        seen[effect.type] = true
        types[#types + 1] = effect.type
      end
    end
  end
  return types
end

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

local function computeLayout(card, glowFns, alpha)
  local font  = Manifest.getFont(FONT_SIZE)
  local fontH = font:getHeight()
  local lineH = fontH + LINE_GAP * SCALE_Y
  local padX  = PAD_X * SCALE_X
  local padY  = PAD_Y * SCALE_Y
  local cs    = card.current.scale

  -- Box width = card screen width; text wraps inside horizontal padding
  local cardScrW = card.offsetX * 2 * cs * SCALE_X
  local bw       = cardScrW
  local textW    = bw - padX * 2

  -- Arrow geometry
  local arrowImg = Manifest.get("tooltip", "arrow")
  local aiw, aih = arrowImg:getDimensions()
  local arrowH_s = ARROW_H * SCALE_Y
  local arrowW_s = (aiw / aih) * arrowH_s
  local gapScr   = TOTAL_GAP_X * SCALE_X

  -- Anchor: card top-right in screen coords
  local topX = card.current.x + card.offsetX * cs * SCALE_X
  local topY = card.current.y - card.offsetY * cs * SCALE_Y
  local ox   = topX + gapScr
  local oy   = topY + (10 * SCALE_Y)

  -- Build per-token entries
  local types   = collectTokenTypes(card.data)
  local entries = {}
  local cursor  = padY

  for _, t in ipairs(types) do
    local colorKey   = TOKEN_COLOR[t] or "tooltipBaseText"
    local name       = TOKEN_NAME[t] or t
    local desc       = TOKEN_DESC[t] or t
    local headerSegs = RichText.parse("{c:" .. colorKey .. "|" .. name .. "} {" .. t .. "}")
    local descLines  = wrapText(desc, font, textW)
    local entryH     = lineH * (1 + #descLines) + ENTRY_GAP * SCALE_Y

    entries[#entries + 1] = {
      tokenType  = t,
      headerSegs = headerSegs,
      descLines  = descLines,
      glowFn     = glowFns and glowFns[t],
      yOffset    = cursor,
      entryH     = entryH,
      headerRect = {
        x = ox + padX,
        y = oy + cursor,
        w = bw - padX * 2,
        h = lineH,
      },
      hovered = false,
    }
    cursor = cursor + entryH
  end

  local bh = cursor + padY

  return {
    entries  = entries,
    bw       = bw,
    bh       = bh,
    ox       = ox,
    oy       = oy,
    alpha    = alpha,
    font     = font,
    fontH    = fontH,
    lineH    = lineH,
    padX     = padX,
    padY     = padY,
    arrowImg = arrowImg,
    arrowX   = ox - arrowW_s,
    arrowY   = oy,
    arrowW   = arrowW_s,
    arrowH   = arrowH_s,
    arrowIW  = aiw,
    arrowIH  = aih,
    zoneLeft  = topX,
    zoneRight = ox + bw + padX,
    zoneTop   = oy - padY,
    zoneBot   = oy + bh + padY,
  }
end

-- ── Public API ────────────────────────────────────────────────────────────────

function M.isExtendedHover(id)
  return _extendedHover[id] == true
end

function M.clear()
  _prevIds = {}
  for _, req in ipairs(_requests) do _prevIds[req.id] = true end
  _requests = {}
  _layouts  = {}
end

-- glowFns: optional table mapping tokenType → function(glow), e.g. TOKEN_TERMINAL
function M.request(id, card, glowFns)
  if not _prevIds[id] then
    _timers[id] = (_alphas[id] or 0) > 0.05 and DELAY or 0
  end
  _requests[#_requests + 1] = { id = id, card = card, glowFns = glowFns }
end

function M.update(mx, my)
  local dt        = realDt
  _extendedHover  = {}
  local activeIds = {}
  for _, req in ipairs(_requests) do activeIds[req.id] = true end

  -- Newly un-hovered → start fading; re-hovered → cancel fade
  for id in pairs(_prevIds) do
    if not activeIds[id] then _retired[id] = true end
  end
  for id in pairs(activeIds) do _retired[id] = nil end

  -- Active tooltips
  for _, req in ipairs(_requests) do
    local id   = req.id
    local card = req.card
    _timers[id] = (_timers[id] or 0) + dt
    local target = (_timers[id] >= DELAY) and 1.0 or 0.0
    _alphas[id]  = animation.expDecay(_alphas[id] or 0, target, FADE_SPEED, dt)
    local alpha  = _alphas[id]

    if alpha > 0.01 then
      local L = computeLayout(card, req.glowFns, alpha)
      for _, entry in ipairs(L.entries) do
        local hr = entry.headerRect
        entry.hovered = mx >= hr.x and mx <= hr.x + hr.w
                    and my >= hr.y and my <= hr.y + hr.h
      end
      _lastLayouts[id] = L
      _layouts[#_layouts + 1] = L
      _extendedHover[id] = mx >= L.zoneLeft and mx <= L.zoneRight
                       and my >= L.zoneTop  and my <= L.zoneBot
    end
  end

  -- Retired tooltips: fade out across frames until alpha reaches zero
  local done = {}
  for id in pairs(_retired) do
    _alphas[id] = animation.expDecay(_alphas[id] or 0, 0, FADE_SPEED, dt)
    local alpha = _alphas[id]
    if alpha <= 0.01 then
      done[#done + 1] = id
    elseif _lastLayouts[id] then
      local L  = _lastLayouts[id]
      L.alpha  = alpha
      _layouts[#_layouts + 1] = L
      _extendedHover[id] = mx >= L.zoneLeft and mx <= L.zoneRight
                       and my >= L.zoneTop  and my <= L.zoneBot
    end
  end
  -- Clean up fully-faded entries and reset their timers so next hover starts fresh
  for _, id in ipairs(done) do
    _retired[id] = nil
    _timers[id]  = 0
  end
end

-- Call from collectGlowRequests, after all requests are processed.
function M.collectGlowRequests(glow)
  for _, L in ipairs(_layouts) do
    for _, entry in ipairs(L.entries) do
      if entry.hovered and entry.glowFn then
        entry.glowFn(glow)
      end
    end
  end
end

function M.draw()
  for _, L in ipairs(_layouts) do
    local alpha = L.alpha
    local bg    = Palette.tooltipBG
    local bgA   = (bg[4] or 1) * BG_ALPHA * alpha

    -- Arrow
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(L.arrowImg, L.arrowX, L.arrowY, 0,
      L.arrowW / L.arrowIW, L.arrowH / L.arrowIH)

    -- Background box
    love.graphics.setColor(bg[1], bg[2], bg[3], bgA)
    love.graphics.rectangle("fill", L.ox, L.oy, L.bw, L.bh,
      CORNER_R * SCALE_X, CORNER_R * SCALE_Y)

    -- Border
    local border = Palette.tooltipBorder
    love.graphics.setColor(border[1], border[2], border[3], (border[4] or 1) * alpha)
    love.graphics.rectangle("line", L.ox, L.oy, L.bw, L.bh,
      CORNER_R * SCALE_X, CORNER_R * SCALE_Y)

    local tc = Palette.tooltipBaseText

    for _, entry in ipairs(L.entries) do
      local headerY = L.oy + entry.yOffset

      -- Header: "Name [icon]" — RichText handles colored name + token sprite
      RichText.draw(entry.headerSegs, L.ox + L.padX, headerY, {
        font       = L.font,
        tokens     = _tokens,
        alpha      = alpha,
        gap        = 6 * SCALE_X,
        spriteSize = L.fontH,
      })
      -- RichText restores the previous font; re-set for description lines below
      love.graphics.setFont(L.font)

      -- Description lines (plain, tooltipBaseText)
      love.graphics.setColor(tc[1], tc[2], tc[3], (tc[4] or 1) * alpha)
      for j, descLine in ipairs(entry.descLines) do
        love.graphics.print(descLine, L.ox + L.padX, headerY + L.lineH * j)
      end
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
end

return M
