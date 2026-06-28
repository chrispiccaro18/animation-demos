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

    if self.config.debug.directDraw then
        self:_renderDirect(items, time)
        return
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
        self:_composite(self.outputBufs[readIdx])
    else
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
        love.graphics.setLineWidth(spec.lineWidth or self.config.defaults.lineWidth)
        local r = spec.radius or self.config.defaults.radius
        love.graphics.rectangle("line", spec.x, spec.y, spec.w, spec.h, r, r)

    elseif kind == "filledRect" then
        local r = spec.radius or self.config.defaults.radius
        love.graphics.rectangle("fill", spec.x, spec.y, spec.w, spec.h, r, r)

    elseif kind == "circle" then
        love.graphics.setLineWidth(spec.lineWidth or self.config.defaults.lineWidth)
        love.graphics.circle("line", spec.cx, spec.cy, spec.r)

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
        love.graphics.rectangle("line", spec.x, spec.y, spec.w, spec.h, r, r)
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
            love.graphics.rectangle("line", spec.x, spec.y, spec.w, spec.h, r, r)

            love.graphics.setColor(color[1], color[2], color[3], fake.innerAlpha * a)
            love.graphics.setLineWidth(fake.innerLineWidth)
            love.graphics.rectangle("line", spec.x, spec.y, spec.w, spec.h, r, r)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
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

    local t      = math.sin(time * speed) * 0.5 + 0.5
    local factor = pmin + (pmax - pmin) * t
    return item.alpha * factor
end

return GlowRenderer
