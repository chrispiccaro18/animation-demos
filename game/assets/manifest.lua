local Manifest = {}

local basePath = "assets/"

Manifest.board = {
  base = {
    path = basePath .. "proto/board.png"
  },
  dtorRow = {
    path = basePath .. "proto/dtor-row.png"
  },
  fullScreenVignette = {
    path = basePath .. "proto/vignette.png"
  }
}

Manifest.card = {
  back = {
    path = basePath .. "proto/kilo-card-back.png"
  },
  base = {
    path = basePath .. "proto/card-base.png"
  },
  ramHole = {
    path = basePath .. "proto/ram-hole.png"
  },
  tokenHole = {
    path = basePath .. "proto/token-hole.png"
  },
  dtorSlot = {
    path = basePath .. "proto/dtor-slot-alt.png"
  },
  line = {
    path = basePath .. "proto/card-line2.png"
  },
  playLine = {
    path = basePath .. "proto/card-play-line2.png"
  },
  discardLine = {
    path = basePath .. "proto/card-discard-line.png"
  },
  emptyNullifySlot = {
    path = basePath .. "proto/empty-nullify-dtor.png"
  }
}

Manifest.tokens = {
  ram = {
    path = basePath .. "proto/ram-chip.png"
  },
  progress = {
    path = basePath .. "proto/progress-token.png"
  },
  progressNegative = {
    path = basePath .. "proto/progress-token-negative.png"
  },
  threat = {
    path = basePath .. "proto/threat-token.png"
  },
  threatNegative = {
    path = basePath .. "proto/threat-token-negative.png"
  },
  nullify = {
    path = basePath .. "proto/nullify-token.png"
  },
  shuffle = {
    path = basePath .. "proto/shuffle-token.png"
  },
  dtor = {
    path = basePath .. "proto/dtor-token.png"
  },
  drawToDtor = {
    path = basePath .. "proto/draw-to-dtor.png"
  },
  drawToHand = {
    path = basePath .. "proto/draw-to-hand.png"
  }
}

Manifest.endTurn = {
  idle = {
    path = basePath .. "proto/end-turn-idle.png"
  },
  hover = {
    path = basePath .. "proto/end-turn-hover.png"
  },
  down = {
    path = basePath .. "proto/end-turn-down2.png"
  }
}

Manifest.ticks = {
  progress = {
    path = basePath .. "proto/progress-tick.png"
  },
  threat = {
    path = basePath .. "proto/threat-tick.png"
  }
}

Manifest.camera = {
  base = {
    path = basePath .. "proto/camera-base.png"
  },
  lens = {
    path = basePath .. "proto/camera-lens.png"
  },
  ring = {
    path = basePath .. "proto/camera-ring.png"
  }
}

Manifest.envEffects = {
  positive = {
    path = basePath .. "proto/env-effect-positive.png"
  },
  positiveInactive = {
    path = basePath .. "proto/env-effect-positive-inactive.png"
  },
  negative = {
    path = basePath .. "proto/env-effect-negative.png"
  }
}

local fontPath = basePath .. "proto/NotoSans-Medium.ttf"
local fontDesignSizes = { 24, 32, 48, 72, 120, 240 }

function Manifest.load()
  local isWeb = love.system.getOS() == "Web"
  for _, category in pairs(Manifest) do
    if type(category) == "table" then
      for _, asset in pairs(category) do
        if type(asset) == "table" and asset.path then
          asset.image = love.graphics.newImage(asset.path, { mipmaps = not isWeb })
        end
      end
    end
  end
  Manifest.fonts = {}
  for _, size in ipairs(fontDesignSizes) do
    Manifest.fonts[size] = love.graphics.newFont(fontPath, math.floor(size * SCALE_X))
  end
end

function Manifest.getFont(designSize)
  assert(Manifest.fonts[designSize], "No font loaded for design size: " .. tostring(designSize))
  return Manifest.fonts[designSize]
end

function Manifest.get(category, name)
  assert(category, "Category must be provided")
  assert(name, "Name must be provided")
  assert(Manifest[category] and Manifest[category][name], "Asset not found: " .. tostring(category) .. "." .. tostring(name))
  return Manifest[category][name].image
end


return Manifest
