require "compiler/crystal/syntax"; include Crystal

OP_MAP = {
  "**" => "^",
  "!=" => "~="
}

TYPE_MAP = {
  "Bool" => "boolean",
  "String" => "string",
  "Proc" => "function",
  "Nil" => "nil",
  "Array" => "table",
  "Hash" => "table",
  "Tuple" => "table",
  "NamedTuple" => "table",
  "Int8" => "number",
  "Int16" => "number",
  "Int32" => "number",
  "Int64" => "number",
  "Float8" => "number",
  "Float16" => "number",
  "Float32" => "number",
  "Float64" => "number"
}

class CodeGenerator
  getter ast : ASTNode?
  @out = ""
  @level = 0
  @current_class_members = [] of Array(ASTNode)
  @current_class_instance_vars = [] of InstanceVar
  @current_class_instance_var_values = [] of ASTNode
  @current_class_includes = [] of String
  @class_names = [] of String
  @runtime_macros = [
    "times", "each", "each_with_index", # looping methods
    "push", "size", # array methods
    "to_s", "to_f64", "to_f32", "to_f", "to_i64", "to_i32", "to_i", "as" # casting methods
  ]

  def initialize(
    source : String,
    @generation_mode : GenerationMode,
    @testing : Bool,
    @file_path : String
  )
    begin
      parser = Parser.new(source)
      @ast = parser.parse
      ENV["RBXCR"] = File.dirname File.dirname(__FILE__) if @testing && !ENV.has_key?("RBXCR")
    rescue ex : Exception
      abort "Crystal failed to compile: #{ex.message}", Exit::CodeGenFailed.value
    end
  end

  def generate
    append_dependencies
    walk @ast.not_nil! unless @ast.nil?
    @out
  end

  private def to_pascal(name : String)
    return name if !!(name =~ /\A([A-Z][a-z_0-9]*)+\z/)
    name.split("_").map(&.capitalize).join ""
  end

  private def append_dependencies
    if @testing
      append "package.path = \"#{ENV["RBXCR"]}/include/?.lua;\" .. package.path"
      newline
    end
    append "local Crystal = require("
    if @testing
      append "\"RuntimeLib\")"
    else
      case @generation_mode
      when GenerationMode::Client
        append "game.Players.LocalPlayer.PlayerScripts"
      when GenerationMode::Server
        append "game.ServerScriptService"
      when GenerationMode::Module
        append "game.ReplicatedStorage"
      end
      append ".Crystal.include.RuntimeLib)"
    end
    newline
  end

  private def walk(node : ASTNode | Float64 | String,
    class_member : Bool = false,
    class_node : (ClassDef | ModuleDef)? = nil,
    save_value : Bool = false,
    def_member : Bool = false
  )
    case node
    when Nop
    when Expressions
      node.expressions.each do |expr|
        append "return " if def_member && expr == node.expressions.last
        walk expr, class_member, class_node, save_value
        newline unless expr == node.expressions.last
      end
    when Include
      name = walk node.name
      unless name.nil? || !name.is_a?(String)
        @current_class_includes << name.not_nil!.to_s
        chop name.size
      end
    when Require # yeah im gonna have to make a custom require function
      append "require("
      walk node.string
      append ")"
      newline
    when Return
      append "return "
      walk node.exp.not_nil! unless node.exp.nil?
    when Yield
      append "return "
      walk node.exps.first unless node.exps.empty?
    when Break
      append "break"
    when VisibilityModifier
      case node.modifier
      when Visibility::Private
        append "local " unless class_member
        walk node.exp
      else
        raise "Unhandled visibility modifier: #{node.modifier}"
      end
    when Var, Global
      append to_pascal node.name
    when UninitializedVar
      raise "Uninitialized variables are not supported."
    when ExceptionHandler
      has_rescues = node.rescues.nil? ? false : !node.rescues.not_nil!.empty?
      raise "Multiple rescue blocks are not supported." if has_rescues && node.rescues.not_nil!.size > 1
      raise "'else' in begin-rescue blocks not supported, use rescue instead." unless node.else.nil?

      append "xpcall(function()"
      start_block

      walk node.body

      end_block
      newline
      append "end, function(#{has_rescues ? node.rescues.not_nil!.first.name : ""})"
      start_block

      walk node.rescues.not_nil!.first.body if has_rescues

      end_block
      newline
      append "end)"
      walk node.ensure.not_nil! unless node.ensure.nil?
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
      multiline = node.value.to_s.split('\n').size > 1
      append multiline ? "[[" : "\""
      append node.value.to_s
      append multiline ? "]]" : "\""
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
        newline
        append "end"

        end_block
      else
        walk_node_list node.elements
      end
      append "}"
      newline
    when ArrayLiteral
      append "Crystal.array {"
      walk_node_list node.elements
      append "}"
    when HashLiteral
      append "{"
      start_block

      node.entries.each do |entry|
        append "["
        walk entry.key
        append "] = "
        walk entry.value
        unless entry == node.entries.last
          append ","
          newline
        end
      end

      end_block
      newline
      append "}"
    when Generic
      walk_named_tuple node if (walk node.name) == "NamedTuple"
    when IsA
      append "Crystal.isA"
      append "("
      walk node.obj
      append ", \""
      type_name = node.const.is_a?(Generic) ?
        node.const.as(Generic).name.as(Crystal::Path).names.join('.').split('(').first
        : node.const.as(Crystal::Path).names.join '.'

      append TYPE_MAP.has_key?(type_name) ? TYPE_MAP[type_name] : type_name
      append "\")"
    when MultiAssign
      walk_node_list node.targets
      append " = "
      walk_node_list node.values
      newline
    when Assign
      walk node.target, class_member, class_node, save_value
      append " = "
      walk node.value
      newline
    when OpAssign
      walk node.target, class_member, class_node, save_value
      unless @testing
        append " #{node.op}= "
      else
        append " = "
        walk node.target, class_member, class_node, save_value
        append " #{node.op} "
      end
      walk node.value
    when Crystal::Path
      append node.names.join "."
    when Block
      append "function("
      walk_node_list node.args
      append ")"
      start_block

      append "return " unless node.body.is_a?(Expressions)
      walk node.body, def_member: true

      end_block
      newline
      append "end"
    when NamedArgument
      walk node.value
    when Arg
      append to_pascal node.name
    when Def
      node.name = to_pascal node.name.gsub('?', "")
      if class_member ? node.name != "Initialize" : true
        append "function "
        if class_member
          @current_class_members << [node.as ASTNode, node.as ASTNode]
          if class_node.is_a?(ClassDef)
            walk class_node.not_nil!.name
          else
            walk class_node.not_nil!.name
          end

          accessor = ":"
          unless node.receiver.nil?
            accessor = "." if node.receiver.as(Var).name == "self"
          end
          append accessor
        end

        unless node.receiver.nil? || node.receiver.as(Var).name == "self"
          walk node.receiver.not_nil!, class_member, class_node
          append "."
        end
        append node.name

        append "("
        walk_node_list node.args
        append ")"
        start_block

        append "return " unless node.body.is_a?(Expressions)
        walk node.body, class_member, class_node, def_member: true

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
      node.name = to_pascal node.name.gsub('?', "")
      if bin_op?(node.name)
        walk_bin_op node
      elsif un_op?(node.name)
        append "("
        append node.name
        walk node.args.first
        append ")"
      elsif postfix?(node.name)
        walk_postfix node
      elsif node.name == "Getter" || node.name == "Setter" || node.name == "Property"
        decl = node.args.first.as(TypeDeclaration)
        var = decl.var.as(Var)
        var.name = to_pascal var.name
        decl.var = var
        @current_class_members << [decl, node].as Array(ASTNode)
      else
        walk_fn_call node, class_member, class_node
      end
    when ModuleDef
      walk_module_def node, class_member, class_node
    when ClassDef
      walk_class_def node, class_member, class_node
    when InstanceVar
      node.name = to_pascal node.name
      if save_value
        @current_class_instance_vars << node
      else
        member_data = @current_class_members.find do |member_list|
          _, call = member_list
          return false unless call.is_a?(Call)
          decl_node = call.as(Call).args.first
          matching = false
          case decl_node
          when TypeDeclaration
            name = walk decl_node.var
            if name.is_a?(String)
              name = to_pascal name
              chop name.size
              matching = name == to_pascal node.name.gsub(/@/, "")
            else
              raise "wtf"
            end
          end
          matching
        end
        unless member_data.nil?
          decl_node = member_data.first
          walk_class_member_assignment decl_node, member_data[1], class_node
        end
      end
    when ClassVar
      if class_node.is_a?(ClassDef)
        to_pascal append node.name.gsub(/@@/, "#{class_node.not_nil!.name}.")
      else
        to_pascal append node.name.gsub(/@@/, "#{class_node.not_nil!.name}.")
      end
    when TypeDeclaration
      walk node.var, class_member, class_node, save_value
      unless node.value.nil?
        if save_value && node.var.class != ClassVar
          @current_class_instance_var_values << node.value.not_nil!
        else
          append " = "
          walk node.value.not_nil!, class_member, class_node
          newline if node.var.is_a?(ClassVar)
        end
      end
    when While, Until
      append "while "
      append "not (" if node.is_a?(Until)
      walk node.cond
      append ")" if node.is_a?(Until)
      append " do"
      start_block

      walk node.body

      end_block
      newline
      append "end"
    when If, Unless
      if node.is_a?(If) && node.as(If).ternary?
        append "("
        walk node.cond
        append " and "
        walk node.then
        append " or "
        walk node.else
        append ")"
      else
        append "if "
        append "not (" if node.is_a?(Unless)
        walk node.cond
        append ")" if node.is_a?(Unless)
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
      end
    else
      raise "Unhandled node: #{node.class}"
    end
  end

  private def walk_module_def(_module : ModuleDef, class_member : Bool, class_node : (ClassDef | ModuleDef)?)
    append "--moduledef" # comment for readability and such
    newline

    if class_member
      walk class_node.not_nil!.name
      append "."
    end
    walk _module.name
    append " = {} do"
    start_block

    walk _module.name; append ".__class = \"Module\""; newline
    if class_member
      append "local "; walk _module.name; append " = "
      walk class_node.not_nil!.name; append "."; walk _module.name
      newline
    end

    walk _module.body, class_member: true, class_node: _module, save_value: true unless _module.body.is_a?(Call)
    walk_ctor _module

    if class_member
      start_block
      walk class_node.not_nil!.name; append "."; walk _module.name
      append " = "; walk _module.name
      end_block
    end

    newline
    append "end"; newline
  end

  private def walk_class_def(_class : ClassDef, class_member : Bool, class_node : (ClassDef | ModuleDef)?)
    append "--classdef" # comment for readability and such
    newline

    if class_member
      walk class_node.not_nil!.name
      append "."
    end
    walk _class.name
    append " = {} do"
    start_block

    walk _class.name; append ".__class = \"Class\""; newline
    if class_member
      append "local "; walk _class.name; append " = "
      walk class_node.not_nil!.name; append "."; walk _class.name
      newline
    end

    @class_names << _class.name.names.join "::"
    walk _class.body, class_member: true, class_node: _class, save_value: true unless _class.body.is_a?(Call)
    walk_ctor _class

    if class_member
      start_block
      walk class_node.not_nil!.name; append "."; walk _class.name
      append " = "; walk _class.name
      end_block
    end

    newline
    append "end"; newline
  end

  private def walk_class_member_assignment(decl_node : ASTNode, parent_node : ASTNode, _class : (ClassDef | ModuleDef)?)
    case decl_node
    when Def
    when TypeDeclaration
      append "self."
      macro_name = parent_node.as(Call).name
      case macro_name
      when "property"
        append "accessors."
        walk decl_node, class_member: true, class_node: _class
        newline
        append "self.writable"
      when "setter"
        append macro_name
        append "s."
        walk decl_node, class_member: true, class_node: _class
        newline
        append "self.writable"
      else
        append macro_name.downcase
        append "s"
      end
      append "."
      walk decl_node, class_member: true, class_node: _class
      newline
    else
      raise "Unhandled class member node: #{decl_node.class}"
    end
  end

  private def walk_ctor(_class : ClassDef | ModuleDef)
    append "function "
    walk _class.name
    append ".new("
    walk_ctor_args _class
    append ")"
    start_block

    append "local include = {#{@current_class_includes.join ", "}}"; newline
    append "local meta = setmetatable("; walk _class.name;
    append ", { __index = "
    unless !_class.is_a?(ClassDef) || _class.as(ClassDef).superclass.nil?
      walk _class.as(ClassDef).superclass.not_nil!
    else
      append "{}"
    end
    append " })"; newline
    unless !_class.is_a?(ClassDef) || _class.as(ClassDef).superclass.nil?
      append "meta.__super = "
      walk _class.as(ClassDef).superclass.not_nil!
      newline
    end
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
    newline

    # Find a Def node with the name "initialize"
    if _class.is_a?(ClassDef)
      walk_ctor_body _class.as(ClassDef)
    else
      walk_ctor_body _class.as(ModuleDef)
    end

    @current_class_members.each do |member|
      decl_node, parent_node = member
      next if decl_node.is_a?(TypeDeclaration) && decl_node.as(TypeDeclaration).value.nil?
      walk_class_member_assignment decl_node, parent_node, _class
    end
    @current_class_instance_vars.each_with_index do |instance_var, i|
      value = @current_class_instance_var_values[i]?
      next if value.nil?

      append "self.private."
      append to_pascal instance_var.name.gsub(/@/, "")
      append " = "
      walk value, class_member: true, class_node: _class
      newline
    end
    @current_class_instance_vars = [] of InstanceVar
    @current_class_instance_var_values = [] of ASTNode
    @current_class_members = [] of Array(ASTNode)
    @current_class_includes = [] of String

    newline
    append "return setmetatable(self, {"; start_block

    append "__index = function(t, k)"; start_block
    append "if not self.getters[k] and not self.accessors[k] and self.private[k] then"; start_block
    append "return nil"

    end_block
    newline
    append "end"; newline
    append "return self.getters[k] or self.accessors[k] or meta[k]"
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

    append_error _class.name_location do
      walk "Attempt to assign to getter"
    end
    end_block

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

  private def get_ctor(_class : T) forall T
    initializer_def = _class.as(T).body.is_a?(Expressions) ?
      _class.as(T).body.as(Expressions).expressions.find { |expr| expr.is_a?(Def) && expr.as(Def).name == "Initialize" }
      : (_class.as(T).body.is_a?(Def) && _class.as(T).body.as(Def).name == "Initialize" ? _class.as(T).body.as(Def) : nil)
  end

  private def walk_ctor_args(_class : T) forall T
    initializer_def = get_ctor _class
    return if initializer_def.nil?

    args = initializer_def.as(Def).args
    args.each do |arg|
      walk arg
      append ", " unless arg == args.last
    end
  end

  private def walk_ctor_body(_class : T) forall T
    initializer_def = get_ctor _class
    return if initializer_def.nil?

    walk _class.as(T).body unless _class.as(T).body.as(Expressions).expressions.pop.is_a?(Def)
    initializer_def.as(Def).body.as(Expressions).expressions.reverse! if initializer_def.as(Def).body.is_a?(Expressions)
    walk initializer_def.as(Def).body
  end

  private def walk_named_tuple(node : Generic)
    chop "NamedTuple".size
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

  private def walk_fn_call(node : Call, class_member : Bool, class_node : (ClassDef | ModuleDef)?)
    def_name = (to_pascal node.name)
      .gsub(/Raise/, "Crystal.error")
      .gsub(/Puts/, "print")
      .gsub(/Sleep/, "wait")
      .gsub(/New/, "new")
      .gsub(/Super/, "super")

    check_fn = node.args.size < 1 && def_name != "new" && node.block.nil?
    if !node.obj.nil? && node.obj.is_a?(Crystal::Path) && node.obj.as(Crystal::Path).names.first == "Rbx" # pascal case roblox methods
      def_name = to_pascal def_name
      node.obj.as(Crystal::Path).names.shift
    end

    if @runtime_macros.includes?(def_name) || (def_name == "super" && node.args.size > 0) || def_name == "Crystal.error"
      if def_name == "super"
        append "local superInstance = self.__super.new("
        walk_call_args node, check_fn
        append ")"
        newline
        append "for k, v in pairs(superInstance) do"
        start_block

        append "self[k] = v"

        end_block
        newline
        append "end"
        newline
      elsif def_name == "Crystal.error"
        append_error node.name_location do
          walk_call_args node, check_fn
        end
      else
        append "Crystal."
        append def_name
        append "("
        walk node.obj.not_nil! unless node.obj.nil?
        append ", " unless node.obj.nil? && check_fn
        walk_call_args node, node.block.nil? && check_fn
        append ")"
      end
    else
      call_op = def_name == "new" ? "." : ":"
      unless node.obj.nil? || def_name == "new"
        obj_name = ""
        case node.obj
        when Crystal::Path
          obj_name = node.obj.as(Crystal::Path).names.join "::"
        when Call
          obj_name = node.obj.as(Call).name
        when Var
          obj_name = node.obj.as(Var).name
        when Global
          obj_name = node.obj.as(Global).name
        else
          raise "Unhandled object node for call: #{node.obj.class}"
        end
        to_pascal obj_name
        call_op = "." if @class_names.includes?(obj_name)
      end

      if check_fn
        fake_assign = @out.chars.last == '\n' || @out.chars.last == '\t'
        append "local _ = " if fake_assign
        append "(type#{!@testing ? "of" : ""}("
        append "self" if node.name == "super"

        unless node.obj.nil?
          walk node.obj.not_nil!, class_member, class_node
          append "."
        else
          append "self." unless @current_class_members.select { |m| m[0].is_a?(Def) }.empty?
        end
        append "__" if node.name == "super"
      else
        unless node.obj.nil?
          walk node.obj.not_nil!, class_member, class_node
        else
          append "self:" unless @current_class_members.select { |m| m[0].is_a?(Def) && m[0].as(Def).name == def_name }.empty?
        end
        append call_op unless node.obj.nil?
      end

      append def_name
      if check_fn
        append ") == \"function\" and "
        append "self" if node.name == "super"
        unless node.obj.nil?
          walk node.obj.not_nil!, class_member, class_node
          append call_op
        else
          append "self#{call_op}" unless @current_class_members.select { |m| m[0].is_a?(Def) }.empty?
        end
        append "__" if node.name == "super"
        append def_name
      end

      append "("
      walk_call_args node, check_fn || !node.block.nil?
      append ")"
      if check_fn
        append " or "
        append "self" if node.name == "super"
        unless node.obj.nil?
          walk node.obj.not_nil!, class_member, class_node
          append "."
        else
          append "self." unless @current_class_members.select { |m| m[0].is_a?(Def) }.empty?
        end
        append "__" if node.name == "super"
        append def_name
        append ")"
        append ";" if fake_assign
        newline if fake_assign
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
    append OP_MAP.has_key?(op) ? OP_MAP[op] : op
    append " "
    walk node.args.first
    newline if op == "="
  end

  # Walk postfix operators such as `[]`
  private def walk_postfix(node : Call)
    left = node.name.chars.first.to_s
    right = node.name.chars.last.to_s

    walk node.obj.not_nil!
    append left
    append "("
    node.args.each { |arg| walk arg }
    append ")"
    dont_sub_classes = [StringLiteral, CharLiteral, RegexLiteral, StringInterpolation]
    append " + 1" unless !node.args.empty? && dont_sub_classes.includes?(node.args.first.class)
    append right
  end

  private def append_error(loc : Location? = nil, message : String? = nil, &block)
    loc_filename = loc.nil? ? "" : loc.filename
    filename = loc_filename == "" ? @file_path : loc_filename
    line_number = loc.nil? ? "" : loc.line_number
    column_number = loc.nil? ? "" : loc.column_number
    append "Crystal.error(\"#{filename}\", #{line_number}, #{column_number}, "
    yield
    append ")"
  end

  private def postfix?(name : String) : Bool
    name.match(/\[\]/) != nil
  end

  private def un_op?(name : String) : Bool
    name.match(/\!\~\@/) != nil
  end

  private def get_bin_op?(name : String) : Regex::MatchData | Nil
    /==/.match(name) || /!=/.match(name) ||
      /<=/.match(name) || />=/.match(name) ||
      /\*\*/.match(name) || name.match(/[\+\-\*\/\%\|\&\^\~\=\<\>\?]/)
  end

  private def bin_op?(name : String) : Bool
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
  private def chop(idx : Int32)
    @out = @out[0..(-(idx + 1))]
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
