local nonRbxVersions = {
  ["Lua 5.4"] = true;
  ["Lua 5.3"] = true;
}

local meta = {}
local function include(moduleName) --must be called before Crystal variable is declared
  local module = nonRbxVersions[_VERSION] and require(moduleName) or require(script.Parent[moduleName])
  for k, v in pairs(module) do
    meta[k] = v
  end
end

include "String"
include "Array"
local Crystal = setmetatable({}, { __index = meta })

function Crystal.isA(value, type)
  if typeof(value) == "table" then
    eq = value.__class == type or (getmetatable(value) and getmetatable(value) == type or false)
    if value.__super then
      return eq or Crystal.isA(value.__super, type)
    else
      return eq
    end
  else
    return typeof(value) == type
  end
end

function Crystal.error(message, filename, line, pos)
  error(("[%s:%u:%u]: %s"):format(message, line, pos, filename), 2)
end

function Crystal.list(t)
  local i = 0
  return function()
    i = i + 1
    if i <= #t then
      return t[i]
    end
  end
end

function Crystal.range(from, to)
  local res = {}
  for i = from, to do
    table.insert(res, i)
  end
  return res
end

function Crystal.times(amount, callback)
  for i = 0, amount - 1 do
    callback(i)
  end
end

function Crystal.each_with_index(arr, callback)
  for i, v in pairs(arr) do
    callback(v, i)
  end
end

function Crystal.each(arr, callback)
  for v in Crystal.list(arr) do
    callback(v)
  end
end

function Crystal.to_s(val)
  return tostring(val)
end

local to_f = function(val)
  return tonumber(val)
end
Crystal.to_f = to_f
Crystal.to_f32 = to_f
Crystal.to_f64 = to_f

local to_i = function(val)
  local n = tonumber(val)
  return n ~= nil and n or nil
end
Crystal.to_i = to_i
Crystal.to_i32 = to_i
Crystal.to_i64 = to_i

function Crystal.as(value)
  return value
end

function Crystal.require(module)

end

return Crystal
