require "String"

local Crystal = {}

function Crystal.mixin(class, includes)
  print(getmetatable(class))
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
Crystal.to_f32 = to_f32
Crystal.to_f64 = to_f64

local to_i = function(val)
  return math.floor(tonumber(val))
end
Crystal.to_i = to_i
Crystal.to_i32 = to_i32
Crystal.to_i64 = to_i64

function Crystal.as(value)
  return value
end

function Crystal.require(module)

end

return Crystal
