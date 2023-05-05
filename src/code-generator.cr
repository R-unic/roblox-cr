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

  private def walk(node : ASTNode | Float64 | String)
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
      newline
      append "}"
    when Assign
      append "local "
      target = walk node.target
      append " = "
      value = walk node.value
      newline
    when Call
      if is_bin_op?(node.name)
        append "("
        walk node.args[0]
        append node.name
        walk node.args[1]
        append ")"
      elsif is_un_op?(node.name)
        append "("
        append node.name
        walk node.args.first
        append ")"
      elsif is_postfix?(node.name)
        left = node.name.chars.first.to_s
        right = node.name.chars.last.to_s

        append "("
        walk node.obj.not_nil!
        append left
        node.args.each { |arg| walk arg }
        append right
        append ")"
      else
        append node.name.gsub(/puts/, "print")
        append "("
        node.args.each { |arg| walk arg }
        append ")"
      end
    else
      puts node.class
    end
  end

  private def is_postfix?(name : String) : Bool
    name.match(/\[\]/) != nil
  end

  private def is_un_op?(name : String) : Bool
    name.match(/\!\~\@/) != nil
  end

  private def is_bin_op?(name : String) : Bool
    name.match(/[\+\-\*\/\%\|\&\^\~\!\=\<\>\?\:\.]/) != nil
  end

  private def newline
    @out += "\n"
  end

  private def append(content : String)
    @out += content
  end
end
