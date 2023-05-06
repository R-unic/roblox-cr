require "./code-generator"
require "./shared"

filename = "test.cr"
code = File.read(filename)
codegen = CodeGenerator.new(code, GenerationMode::Module)
File.write("test.lua", codegen.generate)
