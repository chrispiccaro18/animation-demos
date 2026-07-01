-- Inline rich text renderer.
--
-- Syntax:
--   {tokenType}             token sprite          e.g. {progress}
--   {tokenType:colorHint}   tinted token sprite   e.g. {progress:danger}
--   {tokenType*N}           scaled token sprite   e.g. {dtor*2}
--   {tokenType*N:colorHint} scaled + tinted       e.g. {dtor*2:warning}
--   {c:colorName|text}      colored text span     e.g. {c:positive|+2}
--
-- Color and token tags are atomic (no open/close pairs) so translated strings
-- can freely reorder them without risk of mismatched delimiters.
--
-- Color names are semantic (positive, danger, warning, muted) rather than
-- visual so palette changes and accessibility modes don't require touching
-- every string.
--
-- Spacing around token sprites is controlled by whitespace in the string.
-- opts.gap adds a fixed number of canvas px after every token sprite if
-- you prefer not to rely on string spaces.

local Palette = require("lib.palette")

local RichText = {}

-- All palette color entries are available as color names in markup.
-- Override per-call via opts.colors; merge is shallow (key wins over default).
-- Points at Palette.colors (the raw color-only table) so pairs() never
-- picks up palette methods when building the per-draw merge.
RichText.defaultColors = Palette.colors

-- Parse a rich text string into an ordered segment list.
-- Segment shapes:
--   { type = "text",  content = string }
--   { type = "span",  content = string, color = colorName }
--   { type = "token", tokenType = string, scale = number|nil, colorHint = colorName|nil }
function RichText.parse(str)
  local segments = {}
  local i = 1

  while i <= #str do
    local tagStart = str:find("{", i, true)

    if not tagStart then
      local tail = str:sub(i)
      if #tail > 0 then
        table.insert(segments, { type = "text", content = tail })
      end
      break
    end

    if tagStart > i then
      table.insert(segments, { type = "text", content = str:sub(i, tagStart - 1) })
    end

    local tagEnd = str:find("}", tagStart, true)
    if not tagEnd then
      -- unclosed tag — emit literally and stop
      table.insert(segments, { type = "text", content = str:sub(tagStart) })
      break
    end

    local tag = str:sub(tagStart + 1, tagEnd - 1)

    -- {c:colorName|text content}
    local colorName, spanText = tag:match("^c:([%w_]+)|(.+)$")
    if colorName then
      table.insert(segments, { type = "span", content = spanText, color = colorName })
    else
      -- Token tags: {tokenType}, {tokenType:colorHint}, {tokenType*N}, {tokenType*N:colorHint}
      local tokenType, scale, colorHint

      -- {tokenType*N:colorHint}
      tokenType, scale, colorHint = tag:match("^([%w_]+)%*([%d%.]+):([%w_]+)$")
      if not tokenType then
        -- {tokenType*N}
        tokenType, scale = tag:match("^([%w_]+)%*([%d%.]+)$")
      end
      if not tokenType then
        -- {tokenType:colorHint}
        tokenType, colorHint = tag:match("^([%w_]+):([%w_]+)$")
      end
      if not tokenType then
        -- {tokenType}
        tokenType = tag:match("^([%w_]+)$")
      end

      if tokenType then
        table.insert(segments, {
          type      = "token",
          tokenType = tokenType,
          scale     = scale and tonumber(scale) or nil,
          colorHint = colorHint,
        })
      else
        -- unrecognized — preserve the literal braces
        table.insert(segments, { type = "text", content = "{" .. tag .. "}" })
      end
    end

    i = tagEnd + 1
  end

  return segments
end

-- Measure the total rendered width of a parsed segment list in canvas pixels.
--   font        love.Font
--   spriteSize  canvas px for token sprites  (default: font:getHeight())
--   gap         canvas px appended after each token sprite  (default: 0)
function RichText.measure(segments, font, spriteSize, gap)
  gap        = gap or 0
  spriteSize = spriteSize or font:getHeight()
  local w = 0
  for i, seg in ipairs(segments) do
    if seg.type == "text" or seg.type == "span" then
      w = w + font:getWidth(seg.content)
    elseif seg.type == "token" then
      local next = segments[i + 1]
      local skipGap = not next or (
        (next.type == "text" or next.type == "span") and next.content:sub(1, 1):match("%s")
      )
      w = w + spriteSize * (seg.scale or 1) + (skipGap and 0 or gap)
    end
  end
  return w
end

-- Draw a parsed segment list at canvas position (x, y).
--
-- opts fields:
--   font         love.Font   required
--   tokens       table       { tokenType = love.Image, ... }
--   colors       table       color overrides merged over RichText.defaultColors
--   defaultColor string      palette key for unstyled text  (default: "default")
--   spriteSize   number      token sprite size in canvas px (default: font:getHeight())
--   gap          number      canvas px appended after each token sprite (default: 0)
--   alpha        number      global alpha multiplier applied to all colors (default: 1)
function RichText.draw(segments, x, y, opts)
  opts = opts or {}
  local font        = opts.font
  local tokens      = opts.tokens or {}
  local gap         = opts.gap or 0
  local lineH       = font and font:getHeight() or 16
  local spriteSize  = opts.spriteSize or lineH
  local defaultKey  = opts.defaultColor or "default"
  local globalAlpha = opts.alpha or 1

  local palette = {}
  for k, v in pairs(RichText.defaultColors) do palette[k] = v end
  if opts.colors then
    for k, v in pairs(opts.colors) do palette[k] = v end
  end

  local function resolveColor(key)
    local c = palette[key] or palette["default"] or { 1, 1, 1, 1 }
    return { c[1], c[2], c[3], (c[4] or 1) * globalAlpha }
  end

  local prevFont = love.graphics.getFont()
  if font then love.graphics.setFont(font) end

  local cx = x

  for i, seg in ipairs(segments) do
    if seg.type == "text" then
      love.graphics.setColor(resolveColor(defaultKey))
      love.graphics.print(seg.content, cx, y)
      cx = cx + font:getWidth(seg.content)

    elseif seg.type == "span" then
      love.graphics.setColor(resolveColor(seg.color))
      love.graphics.print(seg.content, cx, y)
      cx = cx + font:getWidth(seg.content)

    elseif seg.type == "token" then
      local img = tokens[seg.tokenType]
      if img then
        local iw, ih    = img:getDimensions()
        local thisSize  = spriteSize * (seg.scale or 1)
        local s         = thisSize / math.max(iw, ih)
        local drawW     = iw * s
        local drawH     = ih * s
        local drawY     = y + (lineH - drawH) / 2   -- vertically center on line
        love.graphics.setColor(resolveColor(seg.colorHint or "default"))
        love.graphics.draw(img, cx, drawY, 0, s, s)
        -- Skip gap when the next segment already starts with whitespace,
        -- or when there is no next segment (trailing gap is wasted).
        local next = segments[i + 1]
        local skipGap = not next or (
          (next.type == "text" or next.type == "span") and next.content:sub(1, 1):match("%s")
        )
        cx = cx + drawW + (skipGap and 0 or gap)
      end
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setFont(prevFont)
end

-- Convenience: parse and draw in one call.
-- Use RichText.parse() separately when the string doesn't change per-frame.
function RichText.drawString(str, x, y, opts)
  RichText.draw(RichText.parse(str), x, y, opts)
end

return RichText
