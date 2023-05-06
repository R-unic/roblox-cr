# in order of abstraction:
# ----
# top is for entry points,
# like the crystal parser.
# bottom is low level things
# like codegen, things that are at
# the bottom of the dependency chain.
enum Exit
  InputInvalid = 0x002
  NoConfig = 0x004
  InvalidConfig = 0x008
  NoRootDir = 0x016
  CodeGenFailed = 0x032
end

enum GenerationMode
  Client
  Server
  Module
end
