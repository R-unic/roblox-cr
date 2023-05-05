require "compiler/crystal/syntax"; include Crystal

class CodeGenerator
  @out = ""
  @level = 0
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
    when StringInterpolation
      node.expressions.each do |expr|
        if expr.is_a?(String)
          append expr
        else
          walk expr
        end
        append " .. " unless expr == node.expressions.last
      end
    when StringLiteral, CharLiteral
      append '"'.to_s
      append node.value.to_s
      append '"'.to_s
    when NumberLiteral
      append node.value
    when ArrayLiteral
      append "{"
      node.elements.each do |arr_value|
        walk arr_value
        append ", " unless arr_value == node.elements.last
      end
      append "}"
    when HashLiteral
      append "{"
      block

      node.entries.each do |entry|
        walk entry.key
        append " = "
        walk entry.value
        append ",\n#{"\t" * @level}" unless entry == node.entries.last
      end

      newline
      end_block
      append "}"
    when Assign
      append "local "
      target = walk node.target
      append " = "
      value = walk node.value
      newline
    when Crystal::Path
      append node.names.join "."
    when Block
      append "function("
      node.args.each { |arg| walk arg }
      append ")"
      block

      walk node.body

      newline
      end_block
      append "end"
    when Arg
      append node.name
    when Def
      append "local function "
      append node.name

      append "("
      node.args.each do |arg|
        walk arg
        append ", " unless arg == node.args.last
      end
      append ")"
      block

      walk node.body

      end_block
      append "end"
      newline
    when Call
      if is_bin_op?(node.name)
        walk_bin_op node
      elsif is_un_op?(node.name)
        append "("
        append node.name
        walk node.args.first
        append ")"
      elsif is_postfix?(node.name)
        walk_postfix node
      else
        check_fn = node.args.size < 1
        if check_fn
          append "local _ = " if @out.chars.last == '\n'
          append "(typeof("
          walk node.obj.not_nil! unless node.obj.nil?
          append "."
        else
          walk node.obj.not_nil! unless node.obj.nil?
          append ":" unless node.obj.nil?
        end

        def_name = node.name.gsub(/puts/, "print")
        append def_name
        if check_fn
          append ") == \"function\" and "
          walk node.obj.not_nil! unless node.obj.nil?
          append ":"
          append def_name
        end

        append "("
        node.args.each { |arg| walk arg }
        unless node.block.nil?
          append ", " unless check_fn
          walk node.block.not_nil!
        end
        append ")"

        if check_fn
          append " or "
          walk node.obj.not_nil! unless node.obj.nil?
          append "."
          append def_name
          append ")"
        else
          newline
        end
      end
    when Require
      append "require("
      walk node.string
      append ")"
      newline
    else
      puts node.class
    end
  end

  private def walk_bin_op(node : Call)
    walk node.obj.not_nil! unless node.obj.nil?
    op = node.name.chars.last.to_s
    left = node.name[-node.name.size..-2]

    append "." unless node.obj.nil?
    append left
    append " "
    append op
    append " "
    walk node.args.first
    newline if op == "="
  end

  private def walk_postfix(node : Call)
    left = node.name.chars.first.to_s
    right = node.name.chars.last.to_s

    append "("
    walk node.obj.not_nil!
    append left
    node.args.each { |arg| walk arg }
    append right
    append ")"
  end

  private def is_postfix?(name : String) : Bool
    name.match(/\[\]/) != nil
  end

  private def is_un_op?(name : String) : Bool
    name.match(/\!\~\@/) != nil
  end

  private def get_bin_op?(name : String) : Regex::MatchData | Nil
    name.match(/[\+\-\*\/\%\|\&\^\~\!\=\<\>\?\:\.]/)
  end

  private def is_bin_op?(name : String) : Bool
    get_bin_op?(name) != nil
  end

  private def end_block
    @level -= 1
    append("\t" * @level)
  end

  private def block
    @level += 1
    newline
    append("\t" * @level)
  end

  private def newline
    @out += "\n"
  end

  private def append(content : String)
    @out += content
  end
end
