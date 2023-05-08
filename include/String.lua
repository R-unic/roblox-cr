local mt = getmetatable("")

mt.__add = function (s1, s2) --concatenate via __add
  return s1 .. s2
end
