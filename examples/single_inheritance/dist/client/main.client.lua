package.path = "/home/runic/Dev/crystal/roblox-cr/include/?.lua;" .. package.path
local Crystal = require("RuntimeLib")
--classdef
Animal = {} do
	Animal.__class = "Class"


	function Animal:Dog()
		return (type(self.Type) == "function" and self:Type() or self.Type) == "Dog"
	end
	function Animal.new(Type)
		local include = {}
		local meta = setmetatable(Animal, { __index = {} })
		meta.__class = "Animal"
		for _, mixin in pairs(include) do
			for k, v in pairs(mixin) do
				meta[k] = v
			end
		end
		local self = setmetatable({}, { __index = meta })
		self.accessors = setmetatable({}, { __index = meta.accessors or {} })
		self.getters = setmetatable({}, { __index = meta.getters or {} })
		self.setters = setmetatable({}, { __index = meta.setters or {} })
		self.writable = {}
		self.private = {}

		self.getters.Type
		 = Type

		return setmetatable(self, {
			__index = function(t, k)
				if not self.getters[k] and not self.accessors[k] and self.private[k] then
					return nil
				end
				return self.getters[k] or self.accessors[k] or Animal[k]
			end,
			__newindex = function(t, k, v)
				if t.writable[k] or self.writable[k] or meta.writable[k] then
					if self.setters[k] then
						self.setters[k] = v
					elseif self.accessors[k] then
						self.accessors[k] = v
					end
				else
					error("Attempt to assign to getter", 2)
				end
			end
		})
	end
end

--classdef
Dog = {} do
	Dog.__class = "Class"



	function Dog:Bark()
		return print("woof")
	end
	function Dog.new(Name, Breed)
		local include = {}
		local meta = setmetatable(Dog, { __index = Animal })
		meta.__super = Animal
		meta.__class = "Dog"
		for _, mixin in pairs(include) do
			for k, v in pairs(mixin) do
				meta[k] = v
			end
		end
		local self = setmetatable({}, { __index = meta })
		self.accessors = setmetatable({}, { __index = meta.accessors or {} })
		self.getters = setmetatable({}, { __index = meta.getters or {} })
		self.setters = setmetatable({}, { __index = meta.setters or {} })
		self.writable = {}
		self.private = {}

		local superInstance = self.__super.new("Dog")
		for k, v in pairs(superInstance) do
			self[k] = v
		end

		self.getters.Breed
		 = Breed

		self.getters.Name
		 = Name

		return setmetatable(self, {
			__index = function(t, k)
				if not self.getters[k] and not self.accessors[k] and self.private[k] then
					return nil
				end
				return self.getters[k] or self.accessors[k] or meta[k]
			end,
			__newindex = function(t, k, v)
				if t.writable[k] or self.writable[k] or meta.writable[k] then
					if self.setters[k] then
						self.setters[k] = v
					elseif self.accessors[k] then
						self.accessors[k] = v
					end
				else
					error("Attempt to assign to getter", 2)
				end
			end
		})
	end
end

Dog = Dog.new("Bentley", "Border Collie")

print(Crystal.isA(Dog, "Dog"))
print(Crystal.isA(Dog, "Animal"))
print((type(Dog.Name) == "function" and Dog:Name() or Dog.Name), (type(Dog.Type) == "function" and Dog:Type() or Dog.Type))
local _ = (type(Dog.Bark) == "function" and Dog:Bark() or Dog.Bark);

print((type(Dog.Dog) == "function" and Dog:Dog() or Dog.Dog))
