require "./spec_helper"

def get_lua(source : String) : String
  CodeGenerator.new(source, GenerationMode::Module, testing: true).generate
end

describe CodeGenerator do
  describe "#generate" do
    it "should generate hello world" do
      lua = get_lua %q{
        puts "hello world"
      }
      lua.split('\n').last.should eq "print(\"hello world\")"
    end
    it "should check if instance member is method before calling" do
      lua = get_lua %q{
        class A
          @member : String = "yup"
        end
        A.new.member
      }
      lua.split('\n')[-2].should eq "local _ = (type(A.new().Member) == \"function\" and A.new():Member() or A.new().Member);"
    end
    it "should check if class member is method before calling" do
      lua = get_lua %q{
        class A
          @@member : String = "yup"
        end
        A.member
      }
      lua.split('\n')[-2].should eq "local _ = (type(A.Member) == \"function\" and A.Member() or A.Member);"
    end
    it "should check if referenced variable is method before calling" do
      lua = get_lua %q{
        def something
          puts "a"
        end
        something
      }
      lua.split('\n')[-2].should eq "local _ = (type(Something) == \"function\" and Something() or Something);"
    end
    it "should support basic single inheritance" do
      lua = get_lua %q{
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
      }

      lua_lines = lua.split '\n'
      # TODO: check lua output
    end
  end
end
