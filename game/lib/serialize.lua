local Serialize = {}

-- Serializes a Lua value (numbers/strings/booleans/nested tables, no cycles,
-- no functions) into readable `return {...}`-style Lua source.
function Serialize.pretty(v, indent)
  indent = indent or 0
  local pad  = string.rep("    ", indent)
  local ipad = string.rep("    ", indent + 1)
  local t = type(v)
  if t == "number"  then return tostring(v) end
  if t == "string"  then return string.format("%q", v) end
  if t == "boolean" then return tostring(v) end
  if t ~= "table"   then return "nil" end
  if next(v) == nil then return "{}" end

  -- Pure sequential array (integer keys 1..n, no gaps)?
  local maxN, isArr = 0, true
  for k in pairs(v) do
    if type(k) ~= "number" or k ~= math.floor(k) or k < 1 then
      isArr = false; break
    end
    if k > maxN then maxN = k end
  end
  if isArr then
    local count = 0
    for _ in pairs(v) do count = count + 1 end
    if count ~= maxN then isArr = false end
  end

  if isArr then
    local hasNested = false
    for i = 1, maxN do
      if type(v[i]) == "table" then hasNested = true; break end
    end
    if not hasNested then
      local parts = {}
      for i = 1, maxN do parts[i] = Serialize.pretty(v[i], 0) end
      return "{ " .. table.concat(parts, ", ") .. " }"
    end
    local lines = {}
    for i = 1, maxN do
      lines[i] = ipad .. Serialize.pretty(v[i], indent + 1)
    end
    return "{\n" .. table.concat(lines, ",\n") .. ",\n" .. pad .. "}"
  end

  -- Dict-style: sort keys for stable output
  local parts = {}
  for k, val in pairs(v) do
    local key = (type(k) == "string" and k:match("^[%a_][%w_]*$"))
                and k or ("[" .. Serialize.pretty(k, 0) .. "]")
    parts[#parts + 1] = ipad .. key .. " = " .. Serialize.pretty(val, indent + 1)
  end
  table.sort(parts)
  return "{\n" .. table.concat(parts, ",\n") .. ",\n" .. pad .. "}"
end

-- Loads a Lua-source file previously written by Serialize.pretty (or any
-- `return {...}` file). Returns (table, nil) on success, (nil, err) on failure.
function Serialize.loadFile(path)
  if not love.filesystem.getInfo(path) then return nil, "not found" end
  local ok, result = pcall(function() return love.filesystem.load(path)() end)
  if not ok or type(result) ~= "table" then
    return nil, "load failed"
  end
  return result, nil
end

return Serialize
