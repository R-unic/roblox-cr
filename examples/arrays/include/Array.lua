local Crystal = {}

local function assertType(v, t, expect)
  assert(typeof(v) == t, "Expected '" .. t .. "', got '" .. typeof(v) .. "'")
end

function Crystal.array(t)
  assertType(t, "table")
  for i in pairs(t) do
    assertType(i, "number")
  end
end

return Crystal
