local Crystal = require(game.Players.LocalPlayer.PlayerScripts.Crystal.include.RuntimeLib)
function Fib(N)
	return (N < 1 and N or Fib(N - 1) + Fib(N - 2))
end

print(Fib(10))