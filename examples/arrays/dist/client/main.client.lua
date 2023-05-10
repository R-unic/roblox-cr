local Crystal = require(game.Players.LocalPlayer.PlayerScripts.Crystal.include.RuntimeLib)
Names = {"john", "bob", "billy", "willy-wanker jorgenson", "jimmy jorgenson"}

print(Names:Join(", "))
print((typeof(Names.Map) == "function" and Names:Map(function(Arg0)
	Arg0:Endswith("jorgenson")
end) or Names.Map):Join(", "))
print(Names[1])
print(Names[Crystal.range(0, 3)])