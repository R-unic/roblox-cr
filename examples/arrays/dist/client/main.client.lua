package.path = "/home/runic/Dev/crystal/roblox-cr/include/?.lua;" .. package.path
local Crystal = require("RuntimeLib")
Names = Crystal.array {"john", "bob", "billy", "willy-wanker jorgenson", "jimmy jorgenson"}

print(Names:Join(", "))
print((type(Names.Map) == "function" and Names:Map(function(Arg0)
	Arg0:EndsWith("jorgenson")
end) or Names.Map):Join(", "))
print(Names[(1) - 1])
print(Names[(Crystal.range(0, 3)) - 1])
Hash = {
	["value"] = true
}

print(Hash[("value")])