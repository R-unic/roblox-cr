require "compiler/crystal/syntax"; include Crystal

# TODO: make lua library
class CodeGenerator
  @out = ""
  @level = 0
  @testing = true
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
    when Nop
    when TypeDeclaration
      walk node.var
    when Expressions
      node.expressions.each { |expr| walk expr }
    when Require # yeah im gonna have to make a custom require function
      append "require("
      walk node.string
      append ")"
      newline
    when Var, Global
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
    when NilLiteral
      append "nil"
    when SymbolLiteral
      append '"'.to_s
      append node.value.to_s.upcase
      append '"'.to_s
    when NumberLiteral, BoolLiteral
      append node.value.to_s
    when TupleLiteral
      append "{"
      if node.elements.all? { |e| e.is_a?(Var) || e.is_a?(Global) || e.is_a?(TypeDeclaration) }
        start_block

        append "new = function("
        walk_node_list node.elements
        append ")"
        start_block

        append "return {"
        start_block
        node.elements.each do |element|
          walk element
          append " = "
          walk element
          unless element == node.elements.last
            append ","
            newline
          end
        end
        end_block
        append "}"
        newline

        end_block
        append "end"
        newline

        end_block
      else
        walk_node_list node.elements
      end
      append "}"
      newline
    when ArrayLiteral
      append "{"
      walk_node_list node.elements
      append "}"
    when HashLiteral
      append "{"
      start_block

      node.entries.each do |entry|
        walk entry.key
        append " = "
        walk entry.value
        unless entry == node.entries.last
          append ","
          newline
        end
      end

      newline
      end_block
      append "}"
    when Generic
      walk_named_tuple node if (walk node.name) == "NamedTuple"
    when MultiAssign
      append "local "
      walk_node_list node.targets
      append " = "
      walk_node_list node.values
      newline
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
      walk_node_list node.args
      append ")"
      start_block

      walk node.body

      newline
      end_block
      append "end"
    when NamedArgument
      walk node.value
    when Arg
      append node.name
    when Def
      append "local function "
      append node.name

      append "("
      walk_node_list node.args
      append ")"
      start_block

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
        check_fn = node.args.size < 1 && node.name != "new"
        call_op = node.name == "new" ? "." : ":"
        if check_fn
          append "local _ = " if @out.chars.last == '\n'
          append "(type#{!@testing ? "of" : ""}("
          walk node.obj.not_nil! unless node.obj.nil?
          append "."
        else
          walk node.obj.not_nil! unless node.obj.nil?
          append call_op unless node.obj.nil?
        end

        def_name = node.name.gsub(/puts/, "print")
        append def_name
        if check_fn
          append ") == \"function\" and "
          walk node.obj.not_nil! unless node.obj.nil?
          append call_op
          append def_name
        end

        append "("
        walk_node_list node.args
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
        # else
        #   newline
        end
      end
    when ClassDef
      walk_class_def node
    else
      puts node.class
    end
  end

  private def walk_named_tuple(node : Generic)
    @out = @out.gsub(/NamedTuple/, "")
    append "{"
    start_block

    append "new = function("
    unless node.named_args.nil?
      node.named_args.not_nil!.each do |arg_name|
        append arg_name.name
        append ", " unless arg_name == node.named_args.not_nil!.last
      end
    end
    append ")"
    start_block

    append "return {"
    start_block
    unless node.named_args.nil?
      node.named_args.not_nil!.each do |arg_name|
        append arg_name.name
        append " = "
        append arg_name.name
        unless arg_name == node.named_args.not_nil!.last
          append ","
          newline
        end
      end
    end
    newline
    end_block
    append "}"
    newline

    end_block
    append "end"
    newline

    end_block
    append "}"
    newline
  end

  private def walk_class_def(node : ClassDef)
    append "--classdef" # comment for readability and such
      newline
      walk node.name
      append " = {} do"
      start_block

      append "local include = {}"; newline
      append "local idxMeta = setmetatable(Dog, { __index = {} })"; newline
      append "idxMeta.__type = \""; walk node.name; append "\""; newline

      append "for mixin in ruby.list(include) do"
      start_block
      append "for k, v in pairs(mixin) do"
      start_block
      append "idxMeta[k] = v"
      end_block
      newline
      append "end"

      end_block
      newline
      append "end"

      newline
      append "local self = setmetatable({}, { __index = idxMeta })"; newline
      append "self.accessors = setmetatable({}, { __index = idxMeta.accessors or {} })"; newline
      append "self.getters = setmetatable({}, { __index = idxMeta.getters or {} })"; newline
      append "self.setters = setmetatable({}, { __index = idxMeta.setters or {} })"; newline
      append "self.writable = {}"; newline
      append "self.private = {}"; newline
      append "setmetatable(self, {"; start_block

      append "__index = function(t, k)"; start_block
      append "if not self.attr_reader[k] and not self.attr_accessor[k] and self.private[k] then"; start_block
      append "return nil"

      end_block
      newline
      append "end"; newline
      append "return self.attr_reader[k] or self.attr_accessor[k] or "
      walk node.name; append "[k]"
      end_block
      newline
      append "end"; newline

      append "__newindex = function(t, k, v)"; start_block
      append "if t.writable[k] or self.writable[k] or idxMeta.writable[k] then"; start_block
      append "if self.attr_writer[k] then"; start_block
      append "self.attr_writer[k] = v"; end_block; newline
      append "elseif self.attr_accessor[k] then"; start_block
      append "self.attr_accessor[k] = v"; end_block;

      newline
      append "end"; end_block

      newline
      append "else"; start_block
      append "error()"; end_block

      newline
      append "end"; end_block


      newline
      append "end"; end_block

      newline
      append "})"; end_block

      newline
      append "end"; newline
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

  private def walk_node_list(args : Array(ASTNode))
    args.each do |arg|
      walk arg
      append ", " unless arg == args.last
    end
  end

  private def end_block
    @level -= 1
    append("\t" * @level)
  end

  private def start_block
    @level += 1
    newline
  end

  private def newline
    @out += "\n#{"\t" * @level}"
  end

  private def append(content : String)
    @out += content
    content
  end
end
