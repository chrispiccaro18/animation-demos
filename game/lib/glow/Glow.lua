local GlowConfig   = require("lib.glow.GlowConfig")
local GlowRenderer = require("lib.glow.GlowRenderer")
local animation    = require("lib.animation")

local Glow = {}
Glow.__index = Glow

local _instance = nil

function Glow.load(canvasW, canvasH)
    local self = setmetatable({}, Glow)
    self.config            = GlowConfig
    self.items             = {}
    self.requests          = {}
    self.requestCount      = 0
    self.time              = 0
    self.qualityName       = GlowConfig.defaultQuality
    self._lastDebugBucket  = -1
    self.renderer          = GlowRenderer.new(GlowConfig, canvasW, canvasH)
    _instance = self
    return self
end

function Glow.get()
    return _instance
end

function Glow:setQuality(name, canvasW, canvasH)
    assert(self.config.quality[name], "Unknown glow quality tier: " .. tostring(name))
    self.qualityName = name
    self.renderer:setQuality(name, canvasW, canvasH)
end

function Glow:request(id, spec)
    if not self.config.enabled then return end
    if self.requestCount >= self.config.maxItems then return end
    spec.id = id
    self.requests[id] = spec
    self.requestCount = self.requestCount + 1
end

function Glow:setActive(id, active, spec)
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
function Glow:update(realDt)
    self.time = self.time + realDt

    for id, spec in pairs(self.requests) do
        local item = self.items[id]
        if not item then
            item = self:_newItem(id, spec)
            self.items[id] = item
        end
        item.spec         = spec
        item.targetAlpha  = spec.alpha or self.config.defaults.alpha
        item.seenThisFrame = true
    end

    for id, item in pairs(self.items) do
        local visible = item.seenThisFrame or item.persistent
        local target  = visible and item.targetAlpha or 0
        local speed   = target > item.alpha
            and self.config.fadeInSpeed
            or  self.config.fadeOutSpeed

        item.alpha = animation.expDecay(item.alpha, target, speed, realDt)

        if not visible and item.alpha <= self.config.removeAlphaThreshold then
            self.items[id] = nil
        else
            item.seenThisFrame = false
        end
    end

    self.requests     = {}
    self.requestCount = 0
end

-- Call inside the screenshake push/pop and gameCanvas block — see main.lua.
function Glow:render()
    if not self.config.enabled then return end
    if not self:hasVisibleItems() then return end
    self.renderer:render(self.items, self.time)
end

function Glow:hasVisibleItems()
    for _, item in pairs(self.items) do
        if item.alpha > self.config.removeAlphaThreshold then
            return true
        end
    end
    return false
end

function Glow:clearAll()
    self.items        = {}
    self.requests     = {}
    self.requestCount = 0
end

function Glow:_newItem(id, spec)
    return {
        id            = id,
        spec          = spec,
        alpha         = 0,
        targetAlpha   = spec.alpha or self.config.defaults.alpha,
        persistent    = false,
        seenThisFrame = false,
    }
end

return Glow
