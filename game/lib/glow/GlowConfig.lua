local GlowConfig = {}

GlowConfig.enabled = true
GlowConfig.defaultQuality = "medium"
GlowConfig.mobileWebQuality = "mobileWeb"

GlowConfig.maxItems = 32
GlowConfig.maxPersistentItems = 16

GlowConfig.fadeInSpeed  = 8.0
GlowConfig.fadeOutSpeed = 5.0
GlowConfig.removeAlphaThreshold = 0.01

GlowConfig.pulse = {
    enabledByDefault = false,
    speed = 1.0,
    min   = 0.75,
    max   = 1.0,
}

GlowConfig.defaults = {
    color     = {1, 1, 1, 1},
    alpha     = 1.0,
    radius    = 8,
    lineWidth = 12,
    textScale = 1.0,
}

-- Scale is relative to canvasW x canvasH (the fixed game canvas), not the window.
-- gammacorrect = false in conf.lua — if that ever changes, additive blend math changes too.
GlowConfig.quality = {
    high = {
        scale            = 1.0,
        blurPasses       = 3,
        blurRadius       = 1,
        blurSamples      = 9,
        compositeBlend   = "add",
        useShaderBlur    = true,
    },
    medium = {
        scale            = 0.5,
        blurPasses       = 2,
        blurRadius       = 1,
        blurSamples      = 7,
        compositeBlend   = "add",
        useShaderBlur    = true,
    },
    low = {
        scale            = 0.5,
        blurPasses       = 1,
        blurRadius       = 1,
        blurSamples      = 4,
        compositeBlend   = "add",
        useShaderBlur    = true,
    },
    mobileWeb = {
        scale            = 0.25,
        blurPasses       = 1,
        blurRadius       = 1,
        blurSamples      = 4,
        compositeBlend   = "add",
        useShaderBlur    = true,
    },
    fake = {
        scale            = 1.0,
        blurPasses       = 0,
        blurRadius       = 0,
        blurSamples      = 0,
        compositeBlend   = "alpha",
        useShaderBlur    = false,
    },
}

GlowConfig.fakeGlow = {
    outerLineWidth = 10,
    outerAlpha     = 0.15,
    innerLineWidth = 4,
    innerAlpha     = 0.35,
}

GlowConfig.debug = {
    drawSourceCanvas  = false,
    disableBlur       = false,
    disablePulse      = false,
    directDraw        = false,
    showBounds        = false,
    logCanvasRecreate = false,
}

return GlowConfig
