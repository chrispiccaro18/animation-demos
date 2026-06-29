local animation = require("lib.animation")

local GlowRenderer = {}
GlowRenderer.__index = GlowRenderer

function GlowRenderer.new(config, canvasW, canvasH)
    local self = setmetatable({}, GlowRenderer)
    self.config  = config
    self.quality = config.quality[config.defaultQuality]

    self.fullW = canvasW
    self.fullH = canvasH

    self.blurShader = nil
    self.sourceCanvas = nil
    self.tempCanvas   = nil
    self.outputBufs   = nil
    self.outWriteIdx  = 1
    self.canvasW = 0
    self.canvasH = 0
    self.lightCanvas    = nil
    self._gradientCache = {}

    self:_allocateCanvases()
    self:_loadShader()

    return self
end

function GlowRenderer:_allocateCanvases()
    local q = self.quality
    local w = math.max(1, math.floor(self.fullW * q.scale))
    local h = math.max(1, math.floor(self.fullH * q.scale))

    if w == self.canvasW and h == self.canvasH then return end

    if self.config.debug.logCanvasRecreate then
        print(string.format("[Glow] allocating canvases %dx%d (scale %.2f)", w, h, q.scale))
    end

    self.canvasW      = w
    self.canvasH      = h
    local fmt = love.graphics.getCanvasFormats()["rgba16f"] and "rgba16f" or "rgba8"
    self.sourceCanvas  = love.graphics.newCanvas(w, h, {format = fmt})
    self.tempCanvas    = love.graphics.newCanvas(w, h, {format = fmt})
    -- Double-buffered output: composite always reads from the buffer written in the
    -- PREVIOUS frame (guaranteed complete after GPU present/swap), never from one
    -- written this frame. Eliminates the GL texture-barrier hazard.
    self.outputBufs    = {
        love.graphics.newCanvas(w, h, {format = fmt}),
        love.graphics.newCanvas(w, h, {format = fmt}),
    }
    self.outWriteIdx   = 1   -- which outputBuf we write to this frame
    self.lightCanvas   = love.graphics.newCanvas(self.fullW, self.fullH, {format = fmt})
    self._gradientCache = {}
end

function GlowRenderer:_loadShader()
    if self.quality.useShaderBlur then
        local ok, result = pcall(love.graphics.newShader, "assets/glow_blur.fs")
        if ok then
            self.blurShader = result
        else
            print("[Glow] Failed to load glow_blur.fs, falling back to fake glow: " .. tostring(result))
            self.blurShader = nil
        end
    end
end

function GlowRenderer:setQuality(name, canvasW, canvasH)
    self.quality = self.config.quality[name]
    self.fullW   = canvasW or self.fullW
    self.fullH   = canvasH or self.fullH
    self.canvasW = 0
    self.canvasH = 0
    self:_allocateCanvases()
    self:_loadShader()
end

function GlowRenderer:render(items, time)
    local prevCanvas = love.graphics.getCanvas()
    local q = self.quality
    local hasLights = self.config.light.enabled and self:_hasLightItems(items)
    local drawOverlay = self:_shouldDrawOverlay(hasLights, items)

    if self.config.debug.directDraw then
        self:_renderDirect(items, time)
        return
    end

    if hasLights then
        self:_drawLightCanvas(items, time)
    end

    if q.useShaderBlur and self.blurShader then
        -- Double-buffer: write blur to outputBufs[writeIdx] this frame,
        -- composite from outputBufs[readIdx] (written last frame — guaranteed
        -- complete after GPU present/swap, no texture-barrier hazard).
        local writeIdx = self.outWriteIdx
        local readIdx  = 3 - writeIdx      -- alternates 1↔2

        self:_drawSourceCanvas(items, time)
        self:_blur(self.outputBufs[writeIdx])
        self.outWriteIdx = readIdx          -- swap for next frame

        -- restore canvas explicitly — push("all")/pop() must NOT be used here because
        -- LÖVE 11 restores the canvas binding on pop, which discards the composite draw
        love.graphics.setCanvas(prevCanvas)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setShader()
        self:_compositeLights(hasLights, drawOverlay)
        self:_composite(self.outputBufs[readIdx])
    else
        love.graphics.setCanvas(prevCanvas)
        self:_compositeLights(hasLights, drawOverlay)
        self:_renderFake(items, time)
    end

    if self.config.debug.drawSourceCanvas then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.sourceCanvas, 0, 0, 0, 1 / q.scale, 1 / q.scale)
    end

    -- leave canvas, color, blendmode clean for subsequent draws in love.draw
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("alpha")
    love.graphics.setShader()
end

function GlowRenderer:_drawSourceCanvas(items, time)
    local q = self.quality
    love.graphics.setCanvas(self.sourceCanvas)
    love.graphics.clear(0, 0, 0, 0)

    love.graphics.push()
    love.graphics.origin()        -- don't inherit screenshake or other transforms from love.draw
    love.graphics.scale(q.scale, q.scale)

    for _, item in pairs(items) do
        self:_drawSourceItem(item, time)
    end

    love.graphics.pop()
end

function GlowRenderer:_drawSourceItem(item, time)
    local spec  = item.spec
    local alpha = self:_computeAlpha(item, time)
    if alpha <= 0 then return end

    local color   = spec.color or self.config.defaults.color
    local lum     = spec.luminescence or self.config.defaults.luminescence
    love.graphics.setColor(color[1] * lum, color[2] * lum, color[3] * lum, (color[4] or 1) * alpha)

    local kind = spec.kind
    if kind == "rect" then
        local previousLineWidth = love.graphics.getLineWidth()
        local lineWidth = (spec.lineWidth or self.config.defaults.lineWidth) * SCALE_X
        love.graphics.setLineWidth(lineWidth)
        local r   = spec.radius or self.config.defaults.radius
        local rot = spec.rotation or 0
        if rot ~= 0 then
            love.graphics.push()
            love.graphics.translate(spec.cx, spec.cy)
            love.graphics.rotate(rot)
            love.graphics.rectangle("line", -(spec.w or 0) * 0.5, -(spec.h or 0) * 0.5, spec.w or 0, spec.h or 0, r, r)
            love.graphics.pop()
        else
            love.graphics.rectangle("line", spec.cx - (spec.w or 0) * 0.5, spec.cy - (spec.h or 0) * 0.5, spec.w or 0, spec.h or 0, r, r)
        end
        love.graphics.setLineWidth(previousLineWidth)

    elseif kind == "filledRect" then
        local r   = spec.radius or self.config.defaults.radius
        local rot = spec.rotation or 0
        if rot ~= 0 then
            love.graphics.push()
            love.graphics.translate(spec.cx, spec.cy)
            love.graphics.rotate(rot)
            love.graphics.rectangle("fill", -(spec.w or 0) * 0.5, -(spec.h or 0) * 0.5, spec.w or 0, spec.h or 0, r, r)
            love.graphics.pop()
        else
            love.graphics.rectangle("fill", spec.cx - (spec.w or 0) * 0.5, spec.cy - (spec.h or 0) * 0.5, spec.w or 0, spec.h or 0, r, r)
        end

    elseif kind == "circle" then
        local previousLineWidth = love.graphics.getLineWidth()
        local lineWidth = (spec.lineWidth or self.config.defaults.lineWidth) * SCALE_X
        love.graphics.setLineWidth(lineWidth)
        love.graphics.circle("line", spec.cx, spec.cy, spec.r)
        love.graphics.setLineWidth(previousLineWidth)

    elseif kind == "text" then
      if spec.drawFunc then
        spec.drawFunc()
      else
      if spec.font then love.graphics.setFont(spec.font) end
        love.graphics.print(spec.text, spec.x, spec.y)
      end

    elseif kind == "image" then
        love.graphics.draw(
            spec.image, spec.x, spec.y,
            spec.rotation or 0,
            spec.sx or 1, spec.sy or 1,
            spec.ox or 0, spec.oy or 0
        )

    elseif kind == "callback" and spec.draw then
        spec.draw(alpha, time, spec)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

function GlowRenderer:_blur(outputCanvas)
    local q = self.quality

    local src = self.sourceCanvas
    local dst = self.tempCanvas

    love.graphics.push()
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("alpha", "premultiplied")

    if not self.config.debug.disableBlur and self.blurShader then
        self.blurShader:send("canvasSize", {self.canvasW, self.canvasH})
        self.blurShader:send("radius", q.blurRadius * q.scale)
        love.graphics.setShader(self.blurShader)

        -- Ping-pong: each pass reads from src, writes to dst, then swaps.
        -- src and dst are always different canvases — no intra-pass read-after-write.
        for _ = 1, q.blurPasses do
            love.graphics.setCanvas(dst)
            love.graphics.clear(0, 0, 0, 0)
            love.graphics.draw(src, 0, 0)
            src, dst = dst, src
        end

        love.graphics.setShader()
    end
    -- src = final blur result (or sourceCanvas when disableBlur)

    -- Copy src into the designated output buffer for this frame.
    -- The composite reads from the OTHER output buffer (written the previous frame,
    -- guaranteed complete after GPU present/swap), so this write has no
    -- same-frame read hazard for the composite.
    love.graphics.setCanvas(outputCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.draw(src, 0, 0)

    love.graphics.pop()
end

function GlowRenderer:_composite(canvas)
    local q = self.quality
    -- canvas stores pre-multiplied data (r*a, g*a, b*a, a); "premultiplied" uses
    -- srcFactor=GL_ONE so the glow is added at full rgb intensity rather than scaled by a again
    love.graphics.setBlendMode(q.compositeBlend or "add", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvas, 0, 0, 0, 1 / q.scale, 1 / q.scale)
    love.graphics.setBlendMode("alpha")
end

-- D-key path: no canvas, no shader — draw additive rect directly to whatever canvas is current
function GlowRenderer:_renderDirect(items, time)
    love.graphics.setBlendMode("add")
    for _, item in pairs(items) do
        local spec  = item.spec
        local a     = self:_computeAlpha(item, time)
        local color = spec.color or self.config.defaults.color
        local r     = spec.radius or self.config.defaults.radius
        love.graphics.setColor(color[1] * a, color[2] * a, color[3] * a, 1.0)
        love.graphics.setLineWidth(spec.lineWidth or self.config.defaults.lineWidth)
        love.graphics.rectangle("line", spec.cx - spec.w * 0.5, spec.cy - spec.h * 0.5, spec.w, spec.h, r, r)
    end
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

function GlowRenderer:_renderFake(items, time)
    local fake = self.config.fakeGlow
    for _, item in pairs(items) do
        local spec = item.spec
        if spec.kind == "rect" then
            local a     = self:_computeAlpha(item, time)
            local color = spec.color or self.config.defaults.color
            local r     = spec.radius or self.config.defaults.radius

            love.graphics.setColor(color[1], color[2], color[3], fake.outerAlpha * a)
            love.graphics.setLineWidth(fake.outerLineWidth)
            love.graphics.rectangle("line", spec.cx - spec.w * 0.5, spec.cy - spec.h * 0.5, spec.w, spec.h, r, r)

            love.graphics.setColor(color[1], color[2], color[3], fake.innerAlpha * a)
            love.graphics.setLineWidth(fake.innerLineWidth)
            love.graphics.rectangle("line", spec.cx - spec.w * 0.5, spec.cy - spec.h * 0.5, spec.w, spec.h, r, r)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

function GlowRenderer:_hasLightItems(items)
    local threshold = self.config.removeAlphaThreshold
    for _, item in pairs(items) do
        if item.spec.light and item.alpha > threshold then
            return true
        end
    end
    return false
end

function GlowRenderer:_shouldDrawOverlay(hasLights, items)
    local mode = self.config.light.darkOverlayMode
    if mode == "alwaysOff" then return false end
    if mode == "alwaysOn"  then return true  end
    if mode == "lightOn"   then return hasLights end
    -- "glowOn": true if any item is visible
    if mode == "glowOn" then
        local threshold = self.config.removeAlphaThreshold
        for _, item in pairs(items) do
            if item.alpha > threshold then return true end
        end
        return false
    end
    return hasLights
end

local function _smoothstep(edge0, edge1, x)
    local t = math.max(0, math.min(1, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)
end

function GlowRenderer:_makeGradientImage(size)
    local data = love.image.newImageData(size, size)
    local cx = (size - 1) / 2
    local cy = (size - 1) / 2
    local maxRadius = size / 2
    data:mapPixel(function(x, y)
        local dx = x - cx
        local dy = y - cy
        local d = math.sqrt(dx * dx + dy * dy)
        local alpha = 1.0 - _smoothstep(0, maxRadius, d)
        return 1, 1, 1, alpha
    end)
    return love.graphics.newImage(data)
end

function GlowRenderer:_getGradient(radius)
    local size = radius * 2
    if not self._gradientCache[size] then
        self._gradientCache[size] = self:_makeGradientImage(size)
    end
    return self._gradientCache[size]
end

function GlowRenderer:_drawLightCanvas(items, time)
    love.graphics.setCanvas(self.lightCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setBlendMode("add")

    for _, item in pairs(items) do
        local spec  = item.spec
        local light = spec.light
        local alpha = light and self:_computeAlpha(item, time)

        if light and alpha > 0 then
            local lightAlpha = (light.alpha or 0.35) * alpha
            local radius = light.radius or 80 * SCALE_X
            local img = self:_getGradient(radius)
            local color = spec.color or self.config.defaults.color

            -- position + ellipse extents resolved together:
            -- light.x/y overrides position; light.w/h triggers ellipse for callbacks
            -- rect/filledRect derive both from spec geometry automatically
            local cx, cy, halfW, halfH
            if light.x and light.y then
                cx, cy = light.x, light.y
                if light.w and light.h then
                    halfW = light.w * 0.5 + radius
                    halfH = light.h * 0.5 + radius
                else
                    halfW = radius
                    halfH = radius
                end
            elseif spec.kind == "circle" then
                cx, cy  = spec.cx, spec.cy
                halfW   = radius
                halfH   = radius
            elseif spec.kind == "rect" or spec.kind == "filledRect" then
                cx      = spec.cx
                cy      = spec.cy
                halfW   = (spec.w or 0) * 0.5 + radius
                halfH   = (spec.h or 0) * 0.5 + radius
            else
                cx, cy  = spec.x or 0, spec.y or 0
                halfW   = radius
                halfH   = radius
            end

            love.graphics.setColor(color[1], color[2], color[3], lightAlpha)
            love.graphics.draw(img, cx, cy, spec.rotation or 0, halfW / radius, halfH / radius, radius, radius)
        end
    end

    love.graphics.pop()
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

-- drawOverlay controls the dark rect; hasLights controls the light bloom.
-- Both are independent: lights always composite when present, overlay is optional.
function GlowRenderer:_compositeLights(hasLights, drawOverlay)
    if not hasLights and not drawOverlay then return end
    local cfg = self.config.light

    if drawOverlay then
        love.graphics.setBlendMode("alpha")
        love.graphics.setColor(0, 0, 0, cfg.darkOverlayAlpha)
        love.graphics.rectangle("fill", 0, 0, self.fullW, self.fullH)
    end

    if hasLights then
        love.graphics.setBlendMode("add", "premultiplied")
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.lightCanvas)
    end

    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

function GlowRenderer:_computeAlpha(item, time)
    if self.config.debug.disablePulse then
        return item.alpha
    end

    local spec  = item.spec
    local pulse = spec.pulse
    if not pulse then return item.alpha end

    local cfg = self.config.pulse
    local speed = cfg.speed
    local pmin  = cfg.min
    local pmax  = cfg.max

    if type(pulse) == "table" then
        speed = pulse.speed or speed
        pmin  = pulse.min   or pmin
        pmax  = pulse.max   or pmax
    end

    local t      = animation.pulseValue(time * speed + (item.phaseOffset or 0))
    local factor = pmin + (pmax - pmin) * t
    return item.alpha * factor
end

return GlowRenderer
