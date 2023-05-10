local Crystal = {}

local function assertType(v, t, expect)
  assert(typeof(v) == t, "Expected '" .. t .. "', got '" .. typeof(v) .. "'")
end

function Crystal.array(t)
  t = t or {}
  assertType(t, "table")
  for i in pairs(t) do
    assertType(i, "number")
  end

  local base = t
  local self = {}

  function self:Shift()
    return table.remove(base, 1)
  end

  function self:Pop()
    return table.remove(base, #base)
  end

  function self:Push(element)
    table.insert(base, element)
    return element
  end

  function self:Join(delim)
    return table.concat(t, delim)
  end

  function self:Map(transform)
    local res = Crystal.array()
    for i, v in pairs(base) do
      res[i] = transform(v, i)
    end
    return res
  end

  local meta = {}
  function meta.__bshl(_, element)
    self:Push(element)
  end

  return setmetatable(self, {
    __index = function(t, k)
      return base[k] or t[k] or meta[k]
    end
  })
end

return Crystal
