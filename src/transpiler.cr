require "./code_generator"
require "file_utils"
require "json"

class RobloxCrystalConfig
  property rootDir : String
  property outDir : String

  def initialize(
    @rootDir = "src",
    @outDir = "dist"
  ) end
end

module Transpiler
  @@rbxcr_path : String = ENV.has_key?("RBXCR") ? ENV["RBXCR"] : "./"

  private def self.do_file(
    path : String,
    parent_dir : String,
    generation_mode : GenerationMode,
    config : RobloxCrystalConfig,
    testing : Bool = false
  )
    base_name = path.split(".cr").first
    source = File.read("#{base_name}.cr")
    codegen = CodeGenerator.new(source, generation_mode, testing)

    extracted_path = base_name.split("#{config.rootDir}/").last
    out_path = "#{parent_dir}/#{config.outDir}/#{extracted_path}.lua"
    begin
      File.write(out_path, codegen.generate)
    rescue ex : Exception
      abort "Code generation failed: #{ex.message}", Exit::CodeGenFailed.value
    end
  end

  private def self.copy_include(dir_path : String)
    begin
      project_include = "#{dir_path}/include/"
      FileUtils.rm_r(project_include) if File.directory?(project_include)
      FileUtils.cp_r "#{ENV["RBXCR"]}/include/", project_include
    rescue ex : Exception
      abort "Failed to copy Lua libraries: #{ex.message}", Exit::FailedToCopyInclude.value
    end
  end

  private def self.get_config(dir_path : String) : RobloxCrystalConfig
    begin
      config_json = File.read("#{dir_path}/config.crystal.json")
      begin
        (JSON.parse(config_json).as?(RobloxCrystalConfig) unless config_json.nil?) || RobloxCrystalConfig.new("src", "dist")
      rescue ex : Exception
        abort "Error parsing config: #{ex.message}", Exit::InvalidConfig.value
      end
    rescue ex : Exception
      puts "Missing config: #{ex.message}"
      abort "Make sure you provide the directory you want to compile if it isn't your current directory.", Exit::NoConfig.value
    end
  end

  def self.do_directory(dir_path : String, testing : Bool = false)
    ENV["RBXCR"] = File.dirname File.dirname(__FILE__) if @@rbxcr_path == "./"
    config = get_config dir_path
    begin
      Dir.glob("#{dir_path}/#{config.rootDir}/*") do |path|
        generation_mode = GenerationMode::Module
        if path.includes?(".client.")
          generation_mode = GenerationMode::Client
        elsif path.includes?(".server.")
          generation_mode = GenerationMode::Server
        end

        do_file(
          path,
          dir_path,
          generation_mode,
          config,
          testing
        )
      end
    rescue ex : Exception
      abort "Error transpiling: Root directory '#{dir_path}/#{config.rootDir}' does not exist.", Exit::NoRootDir.value
    end
    copy_include dir_path
  end
end
