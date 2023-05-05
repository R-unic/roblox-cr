require "compiler/crystal/syntax"; include Crystal

filename = "src/test.cr"
code = File.read(filename)
parser = ::Parser.new(code)
ast = parser.parse

def walk(node : ASTNode)
  case node
  when Crystal::Expressions
    node.expressions.each { |expr| walk expr }
  else
    puts node.class
  end
end

walk ast

