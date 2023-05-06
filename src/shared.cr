# in order of abstraction:
# ----
# top is for entry points,
# like the crystal parser.
# bottom is low level things
# like codegen, things that are at
# the bottom of the dependency chain.
enum Exit
  FailedToWriteDefaultConfig = 0x000002 # cli stuff
  FailedToWriteDefaultProject = 0x000004
  FailedToCreateStructure = 0x000008

  InputInvalid = 0x000016
  FailedToCopyInclude = 0x000032
  NoConfig = 0x000064
  InvalidConfig = 0x000128
  NoRootDir = 0x000256
  CodeGenFailed = 0x000512
end

enum GenerationMode
  Client
  Server
  Module
end

class RobloxCrystalConfig
  property name : String
  property rootDir : String
  property outDir : String

  def initialize(
    @name = "rbxcr-project",
    @rootDir = "src",
    @outDir = "dist"
  ) end
end
