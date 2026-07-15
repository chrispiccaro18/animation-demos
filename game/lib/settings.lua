local Serialize = require("lib.serialize")

-- Global, device-level settings (not tied to any profile): graphics quality,
-- audio volume, game speed. Lives at the save-dir root, independent of which
-- profile is active.
local Settings = {}

local PATH = "settings.lua"

local DEFAULTS = {
  glowQuality    = "medium",
  volume         = 0.5,
  speedIndex     = 1,
  playAction     = "drag",
  paletteVariant = "default",
  windowMode     = "windowed",
  resolutionW    = 1920,
  resolutionH    = 1080,
  vsync          = true,
  musicVolume    = 0.5,
  sfxVolume      = 0.5,
}

local _data = nil

function Settings.load()
  local data = Serialize.loadFile(PATH)
  _data = data or {}
  for k, v in pairs(DEFAULTS) do
    if _data[k] == nil then _data[k] = v end
  end
  return _data
end

function Settings.get()
  return _data or Settings.load()
end

-- Merges `patch` into the current settings and writes the result to disk.
function Settings.save(patch)
  local data = Settings.get()
  for k, v in pairs(patch or {}) do data[k] = v end
  local ok, err = love.filesystem.write(PATH, "return " .. Serialize.pretty(data) .. "\n")
  if not ok then print("[Settings] save failed: " .. tostring(err)) end
end

return Settings
