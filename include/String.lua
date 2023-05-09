local mt = getmetatable("")

if not typeof then
  typeof = type
end
local function _assertType(v, t, message)
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
  _assertType(a, "string")
  _assertType(b, "string")
  return a .. b
end

mt.__sub = function(a, b) --replace
  _assertType(a, "string")
  _assertType(b, "string")
  return a:gsub(b, "")
end

mt.__mul = function(s, amt) --repeat
  _assertType(a, "string")
  _assertType(b, "string")
  return s:rep(amount)
end

mt.__div = function(a, b) --split
  _assertType(a, "string")
  _assertType(b, "string")
  return a:split(b)
end

mt.__mod = function(s, ...) --format
  _assertType(s, "string")
  for _, formatter in pairs() do
   _assertType(formatter, "string")
  end
  return s:format(...)
end
