package.path = "/home/runic/Dev/crystal/roblox-cr/include/?.lua;" .. package.path
local Crystal = require("RuntimeLib")
function Fib(N)
	return (N <= 1 and N or Fib(N - 1) + Fib(N - 2))
end

print(Fib(10))