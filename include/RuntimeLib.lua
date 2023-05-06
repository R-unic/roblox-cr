local Crystal = {}

function Crystal.list(t)
  local i = 0
  return function()
    i += 1
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

function Crystal.require(module)

end

return Crystal
