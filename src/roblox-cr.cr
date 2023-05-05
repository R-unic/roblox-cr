require "./code-generator"

filename = "src/test.cr"
code = File.read(filename)
codegen = CodeGenerator.new(code)
puts codegen.generate
