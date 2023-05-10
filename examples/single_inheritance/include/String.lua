local mt = getmetatable("")

if not typeof then
  typeof = type
end
local function assertType(v, t)
  assert(typeof(v) == t, "Expected 'string', got '" .. typeof(v) .. "'")
end

if not string.split then
  string.split = function(s, delimiter)
    local result = {}
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
      table.insert(result, match)
    end
    return result
  end
end

mt.__add = function(a, b) --concatenate
  assertType(a, "string")
  assertType(b, "string")
  return a .. b
end

mt.__sub = function(a, b) --replace
  assertType(a, "string")
  assertType(b, "string")
  return a:gsub(b, "")
end

mt.__unm = function(s) --reverse
  assertType(s, "string")
  return s:reverse()
end

mt.__mul = function(s, amt) --repeat
  assertType(s, "string")
  assertType(amt, "number")
  return s:rep(amt)
end

mt.__div = function(a, b) --split
  assertType(a, "string")
  assertType(b, "string")
  return a:split(b)
end

mt.__mod = function(s, ...) --format
  assertType(s, "string")
  for _, formatter in pairs {...} do
   assertType(formatter, "string")
  end
  return s:format(...)
end
