require "compiler/crystal/syntax"; include Crystal

class CodeGenerator
  @out = ""
  @ast : ASTNode

  def initialize(source : String)
    parser = Parser.new(source)
    @ast = parser.parse
  end

  def generate
    walk @ast
    @out
  end

  private def walk(node : ASTNode | Number | String)
    case node
    when Expressions
      node.expressions.each { |expr| walk expr }
    when Var
      append node.name
    when Number
      append node.to_s
    when String
      append '"'.to_s
      append node.to_s
      append '"'.to_s
    when NumberLiteral
      append node.value
    when StringLiteral, CharLiteral
      append '"'.to_s
      append node.value.to_s
      append '"'.to_s
    when ArrayLiteral
      append "{"
      node.elements.each do |arr_value|
        walk arr_value
        append ", " unless arr_value == node.elements.last
      end
      append "}"
    when HashLiteral
      append "{\n\t"
      node.entries.each do |entry|
        walk entry.key
        append " = "
        walk entry.value
        append ",\n\t" unless entry == node.entries.last
      end
      append "\n}"
    when Assign
      append "local "
      target = walk node.target
      append " = "
      value = walk node.value
      newline
    else
      puts node.class
    end
  end

  private def newline
    @out += "\n"
  end

  private def append(content : String)
    @out += content
  end
end

filename = "src/test.cr"
code = File.read(filename)
codegen = CodeGenerator.new(code)
puts codegen.generate
