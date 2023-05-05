Person = NamedTuple(name: String, age: Int32, email: String?)
puts Person.new("bob", 30, "bob@bob.com").name
