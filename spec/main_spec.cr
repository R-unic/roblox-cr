require "./spec_helper"

def get_lua_lines(source : String) : Array(String)
  result = CodeGenerator.new(source, GenerationMode::Module, testing: true)
    .generate
    .split('\n')
    .map(&.strip)
    .select { |line| line != "" }

  result.shift
  result.shift
  result
end

describe CodeGenerator do
  describe "#generate" do
    it "should generate hello world" do
      lines = get_lua_lines %q{
        puts "hello world"
      }
      lines.shift.should eq "print(\"hello world\")"
    end
    it "should check if instance member is method before calling" do
      lines = get_lua_lines %q{
        class A
          @member : String = "yup"
        end
        A.new.member
      }
      lines.last.should eq "local _ = (type(A.new().Member) == \"function\" and A.new():Member() or A.new().Member);"
    end
    it "should check if class member is method before calling" do
      lines = get_lua_lines %q{
        class A
          @@member : String = "yup"
        end
        A.member
      }
      lines.last.should eq "local _ = (type(A.Member) == \"function\" and A.Member() or A.Member);"
    end
    it "should check if referenced variable is method before calling" do
      lines = get_lua_lines %q{
        def something
          puts "a"
        end
        something
      }

      lines.shift.should eq "function Something()"
      lines.shift.should eq "return print(\"a\")"
      lines.shift.should eq "end"
      lines.shift.should eq "local _ = (type(Something) == \"function\" and Something() or Something);"
    end
    it "should support basic single inheritance" do
      lines = get_lua_lines %q{
        def fib(n : Int) : Int
          n <= 1 ? n : (fib(n - 1) + fib(n - 2))
        end

        puts fib 10 #=> 55
      }

      lines.shift.should eq "function Fib(N)"
      lines.shift.should eq "return (N <= 1 and N or Fib(N - 1) + Fib(N - 2))"
      lines.shift.should eq "end"
      lines.shift.should eq "print(Fib(10))"
    end
  end
end
