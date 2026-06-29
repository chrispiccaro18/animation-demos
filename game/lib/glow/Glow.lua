local GlowConfig   = require("lib.glow.GlowConfig")
local GlowRenderer = require("lib.glow.GlowRenderer")
local animation    = require("lib.animation")

-- ──────────────────────────────────────────────────────────────────────────────
-- GlowLayer: single-layer glow manager
-- ──────────────────────────────────────────────────────────────────────────────
local GlowLayer = {}
GlowLayer.__index = GlowLayer

function GlowLayer.new(canvasW, canvasH)
    local self = setmetatable({}, GlowLayer)
    self.config           = GlowConfig
    self.items            = {}
    self.requests         = {}
    self.requestCount     = 0
    self.time             = 0
    self.qualityName      = GlowConfig.defaultQuality
    self._lastDebugBucket = -1
    self.renderer         = GlowRenderer.new(GlowConfig, canvasW, canvasH)
    return self
end

function GlowLayer:setQuality(name, canvasW, canvasH)
    assert(self.config.quality[name], "Unknown glow quality tier: " .. tostring(name))
    self.qualityName = name
    self.renderer:setQuality(name, canvasW, canvasH)
end

function GlowLayer:request(id, spec)
    if not self.config.enabled then return end
    if self.requestCount >= self.config.maxItems then return end
    spec.id = id
    self.requests[id] = spec
    self.requestCount = self.requestCount + 1
end

function GlowLayer:setActive(id, active, spec)
    if active then
        local item = self.items[id]
        if not item then
            item = self:_newItem(id, spec)
            self.items[id] = item
        end
        item.spec        = spec
        item.persistent  = true
        item.targetAlpha = spec.alpha or self.config.defaults.alpha
    else
        local item = self.items[id]
        if item then
            item.persistent  = false
            item.targetAlpha = 0
        end
    end
end

-- Always pass realDt — glow fades must be unaffected by game speed.
function GlowLayer:update(realDt)
    self.time = self.time + realDt

    for id, spec in pairs(self.requests) do
        local item = self.items[id]
        if not item then
            item = self:_newItem(id, spec)
            self.items[id] = item
        end
        item.spec          = spec
        item.targetAlpha   = spec.alpha or self.config.defaults.alpha
        item.seenThisFrame = true
    end

    for id, item in pairs(self.items) do
        local visible  = item.seenThisFrame or item.persistent
        local target   = visible and item.targetAlpha or 0
        local spec     = item.spec
        local fadingIn = target > item.alpha
        local fadeCtrl = fadingIn and spec.fadeIn or spec.fadeOut

        if fadeCtrl == false then
            item.alpha = target
        else
            local defaultSpeed = fadingIn and self.config.fadeInSpeed or self.config.fadeOutSpeed
            local speed = type(fadeCtrl) == "number" and fadeCtrl or defaultSpeed
            item.alpha = animation.expDecay(item.alpha, target, speed, realDt)
        end

        if not visible and item.alpha <= self.config.removeAlphaThreshold then
            self.items[id] = nil
        else
            item.seenThisFrame = false
        end
    end

    self.requests     = {}
    self.requestCount = 0
end

function GlowLayer:render()
    if not self.config.enabled then return end
    if not self:hasVisibleItems() then return end
    self.renderer:render(self.items, self.time)
end

function GlowLayer:hasVisibleItems()
    for _, item in pairs(self.items) do
        if item.alpha > self.config.removeAlphaThreshold then
            return true
        end
    end
    return false
end

function GlowLayer:clearAll()
    self.items        = {}
    self.requests     = {}
    self.requestCount = 0
end

function GlowLayer:_newItem(id, spec)
    local targetAlpha = spec.alpha or self.config.defaults.alpha
    local startAlpha  = 0
    local phaseOffset = 0

    if spec.pulse then
        -- new pulse items snap to full brightness and align phase to max — no fade-in from nothing
        local speed  = (type(spec.pulse) == "table" and spec.pulse.speed) or self.config.pulse.speed
        startAlpha   = targetAlpha
        phaseOffset  = math.pi * 0.5 - self.time * speed
    end

    return {
        id            = id,
        spec          = spec,
        alpha         = startAlpha,
        targetAlpha   = targetAlpha,
        phaseOffset   = phaseOffset,
        persistent    = false,
        seenThisFrame = false,
    }
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Glow: three-layer facade
--
--   bottom  just above the board, below all game elements
--   mid     above game elements, below dragged/hovered cards  (default)
--   top     above everything
--
-- request / setActive accept an optional layer name (3rd / 4th arg).
-- Omitting it routes to "mid".
-- ──────────────────────────────────────────────────────────────────────────────
local Glow = {}
Glow.__index = Glow

local _instance = nil

function Glow.load(canvasW, canvasH)
    local self = setmetatable({}, Glow)
    self.bottom      = GlowLayer.new(canvasW, canvasH)
    self.mid         = GlowLayer.new(canvasW, canvasH)
    self.top         = GlowLayer.new(canvasW, canvasH)
    self.qualityName = GlowConfig.defaultQuality
    _instance = self
    return self
end

function Glow.get()
    return _instance
end

function Glow:setQuality(name, canvasW, canvasH)
    self.qualityName = name
    self.bottom:setQuality(name, canvasW, canvasH)
    self.mid:setQuality(name, canvasW, canvasH)
    self.top:setQuality(name, canvasW, canvasH)
end

function Glow:request(id, spec, layer)
    self[layer or "mid"]:request(id, spec)
end

function Glow:setActive(id, active, spec, layer)
    self[layer or "mid"]:setActive(id, active, spec)
end

function Glow:update(realDt)
    self.bottom:update(realDt)
    self.mid:update(realDt)
    self.top:update(realDt)
end

function Glow:renderBottom() self.bottom:render() end
function Glow:renderMid()    self.mid:render()    end
function Glow:renderTop()    self.top:render()    end

function Glow:clearAll()
    self.bottom:clearAll()
    self.mid:clearAll()
    self.top:clearAll()
end

return Glow
