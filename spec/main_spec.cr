require "./spec_helper"

def get_lua(source : String)
  CodeGenerator.new(source, GenerationMode::Module, testing: true).generate
end

describe CodeGenerator do
  # TODO: Write tests
  describe "#generate" do
    it "should check if instance member is method before calling" do
      lua = get_lua %(
        class A
          @member : String = "yup"
        end
        A.new.member
      )
      lua.split('\n')[-2].should eq "local _ = (type(A.new().member) == \"function\" and A.new():member() or A.new().member)"
    end
    it "should check if class member is method before calling" do
      lua = get_lua %(
        class A
          @@member : String = "yup"
        end
        A.member
      )
      lua.split('\n')[-2].should eq "local _ = (type(A.member) == \"function\" and A.member() or A.member)"
    end
    it "should check if referenced variable is method before calling" do
      lua = get_lua %(
        def something
          puts "a"
        end
        something
      )
      lua.split('\n')[-2].should eq "local _ = (type(something) == \"function\" and something() or something)"
    end
  end
end
