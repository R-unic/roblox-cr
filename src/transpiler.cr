require "./code_generator"
require "file_utils"
require "json"

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
        (JSON.parse(config_json).as?(RobloxCrystalConfig) unless config_json.nil?) || RobloxCrystalConfig.new("robloxcr-project", "src", "dist")
      rescue ex : Exception
        abort "Error parsing config: #{ex.message}", Exit::InvalidConfig.value
      end
    rescue ex : Exception
      puts "Missing config: #{ex.message}"
      abort "Make sure you provide the directory you want to compile if it isn't your current directory.", Exit::NoConfig.value
    end
  end

  private def self.check_project_structure(dir_path : String, config : RobloxCrystalConfig)
    return if !File.directory? dir_path
    FileUtils.mkdir_p File.join(dir_path, config.outDir)
    FileUtils.mkdir_p File.join(dir_path, config.rootDir)
    FileUtils.mkdir_p File.join(dir_path, config.rootDir, "client")
    FileUtils.mkdir_p File.join(dir_path, config.rootDir, "server")
    FileUtils.mkdir_p File.join(dir_path, config.rootDir, "shared")
  end

  def self.create_directory_structure(dir_path : String, config : RobloxCrystalConfig)
    # create directories in dist/ based on structure of src/
    Dir.glob "#{dir_path}/**" do |path|
      next unless File.directory? path
      dist_path = path.gsub("#{dir_path}", File.join(dir_path, "../dist"))
      FileUtils.mkdir(dist_path) unless File.directory? dist_path # it exists and is a folder
    end
  end

  def self.do_directory(dir_path : String, testing : Bool = false)
    ENV["RBXCR"] = File.dirname File.dirname(__FILE__) if @@rbxcr_path == "./"
    config = get_config dir_path
    check_project_structure dir_path, config

    begin
      create_directory_structure File.join(dir_path, config.rootDir), config # create directories in dist/
      Dir.glob File.join(dir_path, config.rootDir, "**/*.cr") do |path|
        generation_mode = GenerationMode::Module
        if path.includes?(".client.")
          generation_mode = GenerationMode::Client
        elsif path.includes?(".server.")
          generation_mode = GenerationMode::Server
        end

        # copy non-crystal files
        FileUtils.cp_r(path, dir_path) unless path.ends_with? ".cr"

        # transpile .cr file and write to .lua file in dist/
        lua_path = path.gsub(File.join(dir_path, config.rootDir), File.join(dir_path, config.outDir)).gsub(".cr", ".lua")
        lua_dir = File.dirname lua_path
        do_file(path, dir_path, generation_mode, config, testing)
      end
    rescue ex : Exception
      abort "Error transpiling: Root directory '#{dir_path}/#{config.rootDir}' does not exist.", Exit::NoRootDir.value
    end
    copy_include dir_path
  end
end
