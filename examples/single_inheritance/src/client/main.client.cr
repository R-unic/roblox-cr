class Animal
  getter type : String

  def initialize(@type)
  end

  def dog?
    type == "Dog"
  end
end

class Dog < Animal
  getter name : String
  getter breed : String

  def initialize(@name, @breed)
    super "Dog"
  end

  def bark
    puts "woof"
  end
end

dog = Dog.new "Bentley", "Border Collie"
puts dog.is_a?(Dog)
puts dog.is_a?(Animal)
puts dog.name, dog.type
dog.bark
puts dog.dog?
