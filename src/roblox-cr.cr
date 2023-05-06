require "./code-generator"

filename = "test.cr"
code = File.read(filename)
codegen = CodeGenerator.new(code)
File.write("test.lua", codegen.generate)
