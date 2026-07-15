-- Runtime window mode / resolution / vsync helper.
-- Shared by optionsMenu (live changes) and main.lua (boot-time restore of
-- persisted Settings) so there's one place that knows the setMode flags.
local WindowMode = {}

-- modeKey: "windowed" | "fullscreen" (exclusive) | "borderless" (desktop fullscreen)
function WindowMode.apply(modeKey, w, h)
  local _, _, flags = love.window.getMode()
  flags = flags or {}

  if modeKey == "fullscreen" then
    flags.fullscreen     = true
    flags.fullscreentype = "exclusive"
  elseif modeKey == "borderless" then
    flags.fullscreen     = true
    flags.fullscreentype = "desktop"
  else
    flags.fullscreen = false
  end

  -- LÖVE ignores w/h for "desktop" fullscreentype (uses desktop resolution),
  -- so passing the selected resolution there is harmless.
  love.window.setMode(w or love.graphics.getWidth(), h or love.graphics.getHeight(), flags)
end

-- Sorted (largest first), deduped list of { label = "WxH", value = {w=, h=} }
-- for the resolutions this display actually supports.
function WindowMode.listResolutions()
  local modes = love.window.getFullscreenModes()
  table.sort(modes, function(a, b)
    if a.width ~= b.width then return a.width > b.width end
    return a.height > b.height
  end)

  local seen = {}
  local list = {}
  for _, m in ipairs(modes) do
    local key = m.width .. "x" .. m.height
    if not seen[key] then
      seen[key] = true
      table.insert(list, { label = key, value = { w = m.width, h = m.height } })
    end
  end
  return list
end

function WindowMode.setVsync(enabled)
  love.window.setVSync(enabled and 1 or 0)
end

return WindowMode
