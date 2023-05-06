require "compiler/crystal/syntax"; include Crystal
require "./shared"

class CodeGenerator
  @ast : ASTNode?
  @out = ""
  @level = 0
  @testing = true
  @macros = [
    "times", "each", "each_with_index",
    "to_s", "to_f64", "to_f32", "to_f", "to_i64", "to_i32", "to_i", "as"
  ]

  def initialize(source : String, @generation_mode : GenerationMode)
    begin
      parser = Parser.new(source)
      @ast = parser.parse
    rescue ex : Exception
      puts "Crystal compilation error: #{ex.message}"
    end
  end

  def generate
    append_dependencies
    walk @ast.not_nil! unless @ast.nil?
    @out
  end

  def append_dependencies
    append "local Crystal = require("
    unless @testing
      case @generation_mode
      when GenerationMode::Client
        append "game.Players.LocalPlayer.PlayerScripts"
      when GenerationMode::Server
        append "game.ServerScriptService"
      when GenerationMode::Module
        append "game.ReplicatedStorage"
      end
      append ".Crystal.include.RuntimeLib)"
    else
      append "\"./include/RuntimeLib\")"
    end
    newline
  end

  private def walk(node : ASTNode | Float64 | String,
    class_member : Bool? = nil,
    class_node : ClassDef? = nil
  )
    case node
    when Nop
    when TypeDeclaration
      walk node.var
    when Expressions
      node.expressions.each { |expr| walk expr, class_member, class_node }
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
    when RangeLiteral
      append "Crystal.range("
      walk node.from
      append ", "
      walk node.to
      append ")"
    when StringLiteral, CharLiteral, RegexLiteral
      append '"'.to_s
      append node.value.to_s
      append '"'.to_s
    when NilLiteral
      append "nil"
    when SymbolLiteral
      append '"'.to_s
      append node.value.to_s.upcase
      append '"'.to_s
    when NumberLiteral
      append node.value.to_s
      node.value
    when BoolLiteral
      append node.value.to_s
      node.value
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

      end_block
      newline
      append "end"
    when NamedArgument
      walk node.value
    when Arg
      append node.name
    when Def
      if class_member ? node.name != "initialize" : true
        append "local " if class_member.nil?
        append "function "
        if class_member
          walk class_node.not_nil!.name
          puts node.body
          append ":"
        end
        unless node.receiver.nil?
          walk node.receiver.not_nil!
          append "."
        end
        append node.name

        append "("
        walk_node_list node.args
        append ")"
        start_block

        walk node.body

        end_block
        newline
        append "end"
        newline
      end
    when Not
      append "not "
      walk node.exp
    when And
      walk node.left
      append " and "
      walk node.right
    when Or
      walk node.left
      append " or "
      walk node.right
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
      elsif node.name == "getter" || node.name == "setter" || node.name == "property"
        append node.name
        append "(self, "
        walk node.args.first.to_s.split(" : ").first
        append ")"
        newline
      else
        walk_fn_call node
      end
    when ClassDef
      walk_class_def node
    when InstanceVar
      chop 6 # remove the "local" from the previous Assign node
      append "self."
      puts node.visibility
      case node.visibility
      when Visibility::Public

      else
        append "private."
      end
      append node.name.gsub(/@/, "")
    when ClassVar
      append "#{class_node.not_nil!.name}."
      append node.name.gsub(/@/, "")
    when If
      append "if "
      walk node.cond
      append " then"
      start_block

      walk node.then

      end_block
      newline
      append "else"
      start_block

      walk node.else

      end_block
      newline
      append "end"
    else
      puts node.class
    end
  end

  private def walk_class_def(_class : ClassDef)
    append "--classdef" # comment for readability and such
    newline
    walk _class.name
    append " = {} do"
    start_block

    walk _class.body, class_member: true, class_node: _class unless _class.body.is_a?(Call)
    walk_class_ctor _class

    newline
    append "end"; newline
  end

  private def walk_class_ctor(_class : ClassDef)
    append "function "; walk _class.name; append ".new("
    append ")"
    start_block

    append "local include = {}"; newline
    append "local meta = setmetatable("; walk _class.name; append ", { __index = {} })"; newline
    append "meta.__class = \""; walk _class.name; append "\""; newline

    append "for "
    append "_, " if @testing
    append "mixin in "
    append @testing ? "pairs" : "Crystal.list"
    append "(include) do"
    start_block
    append "for k, v in pairs(mixin) do"
    start_block
    append "meta[k] = v"
    end_block
    newline
    append "end"

    end_block
    newline
    append "end"

    newline
    append "local self = setmetatable({}, { __index = meta })"; newline
    append "self.accessors = setmetatable({}, { __index = meta.accessors or {} })"; newline
    append "self.getters = setmetatable({}, { __index = meta.getters or {} })"; newline
    append "self.setters = setmetatable({}, { __index = meta.setters or {} })"; newline
    append "self.writable = {}"; newline
    append "self.private = {}"; newline

    # Find a Def node with the name "initialize"
    newline
    initializer_def = _class.body.is_a?(Expressions) ?
      _class.body.as(Expressions).expressions.find { |expr| expr.is_a?(Def) && expr.as(Def).name == "initialize" }
      : (_class.body.is_a?(Def) && _class.body.as(Def).name == "initialize" ? _class.body.as(Def) : nil)

    unless initializer_def.nil?
      walk _class.body unless _class.body.as(Expressions).expressions.pop.is_a?(Def)
      walk initializer_def.as(Def).body
    end

    newline
    append "return setmetatable(self, {"; start_block

    append "__index = function(t, k)"; start_block
    append "if not self.getters[k] and not self.accessors[k] and self.private[k] then"; start_block
    append "return nil"

    end_block
    newline
    append "end"; newline
    append "return self.getters[k] or self.accessors[k] or "
    walk _class.name; append "[k]"
    end_block
    newline
    append "end,"; newline

    append "__newindex = function(t, k, v)"; start_block
    append "if t.writable[k] or self.writable[k] or meta.writable[k] then"; start_block
    append "if self.setters[k] then"; start_block
    append "self.setters[k] = v"; end_block; newline
    append "elseif self.accessors[k] then"; start_block
    append "self.accessors[k] = v"; end_block;

    newline
    append "end"; end_block

    newline
    append "else"; start_block
    append "error(\"Attempt to assign to getter\")"; end_block

    newline
    append "end"; end_block

    newline
    append "end"; end_block

    newline
    append "})"; end_block

    newline
    append "end"
    end_block
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

  private def walk_call_args(node : Call, last : Bool)
    walk_node_list node.args
    unless node.block.nil?
      append ", " unless last
      walk node.block.not_nil!
    end
  end

  private def walk_fn_call(node : Call)
    def_name = node.name.gsub(/puts/, "print")
    check_fn = node.args.size < 1 && def_name != "new"
    if @macros.includes?(def_name)
      append "Crystal."
      append def_name
      append "("
      walk node.obj.not_nil! unless node.obj.nil?
      append ", " unless node.obj.nil? || check_fn
      walk_call_args node, check_fn
      append ")"
    else
      call_op = def_name == "new" ? "." : ":"
      if check_fn
        append "local _ = " if @out.chars.last == '\n'
        append "(type#{!@testing ? "of" : ""}("
        walk node.obj.not_nil! unless node.obj.nil?
        append "."
      else
        walk node.obj.not_nil! unless node.obj.nil?
        append call_op unless node.obj.nil?
      end

      append def_name
      if check_fn
        append ") == \"function\" and "
        walk node.obj.not_nil! unless node.obj.nil?
        append call_op
        append def_name
      end

      append "("
      walk_call_args node, check_fn
      append ")"
      if check_fn
        append " or "
        walk node.obj.not_nil! unless node.obj.nil?
        append "."
        append def_name
        append ")"
      end
    end
  end

  private def walk_bin_op(node : Call)
    match = get_bin_op?(node.name)
    walk node.obj.not_nil! unless node.obj.nil?
    op = match.not_nil![0].to_s
    left = node.name[-node.name.size..-2]

    unless node.obj.nil? || left == "" || !match.nil?
      append "."
      append left
    end

    append " "
    append op
    append " "
    walk node.args.first
    newline if op == "="
  end

  # Walk postfix operators such as `[]`
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
    /==/.match(name) || name.match(/[\+\-\*\/\%\|\&\^\~\!\=\<\>\?\:\.]/)
  end

  private def is_bin_op?(name : String) : Bool
    get_bin_op?(name) != nil
  end

  # Walks a list of nodes appending a comma between each
  private def walk_node_list(args : Array(ASTNode))
    args.each do |arg|
      walk arg
      append ", " unless arg == args.last
    end
  end

  # Ends a block
  private def end_block
    @level -= 1
    append("\t" * @level)
  end

  # Starts a block and creates a newline
  private def start_block
    @level += 1
    newline
  end

  # Chop the last `idx` characters off out the output
  private def chop(idx : UInt32)
    @out = @out[0..(-(idx.to_i + 1))]
  end

  # Add a newline character plus the current tab level
  private def newline
    @out += "\n#{"\t" * @level}"
  end

  # Append `content` onto the output
  private def append(content : String)
    @out += content
    content
  end
end
