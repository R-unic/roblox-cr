require "json"
require "./code-generator"
require "./shared"

class RobloxCrystalConfig
  property rootDir : String
  property outDir : String

  def initialize(
    @rootDir = "src",
    @outDir = "dist"
  ) end
end

class Transpiler
  def self.do_file(
    path : String,
    parent_dir : String,
    generation_mode : GenerationMode,
    config : RobloxCrystalConfig,
    testing : Bool = false
  )
    base_name = path.split(".cr").first
    puts base_name
    source = File.read("#{base_name}.cr")
    codegen = CodeGenerator.new(source, generation_mode, testing)

    extracted_path = base_name.split("#{config.rootDir}/").last
    out_path = "#{parent_dir}/#{config.outDir}/#{extracted_path}.lua"
    File.write(out_path, codegen.generate)
  end

  def self.do_directory(dir_path : String, testing : Bool = false)
    begin
      config_json = File.read("#{dir_path}/config.crystal.json")

      begin
        config = (JSON.parse(config_json).as?(RobloxCrystalConfig) unless config_json.nil?) || RobloxCrystalConfig.new("src", "dist")
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
        rescue ex
          puts "Error transpiling: Root directory '#{config.rootDir}' does not exist."
        end
      rescue ex
        puts "Error parsing config: #{ex.message}"
      end
    rescue ex
      puts "Error loading config: #{ex.message}"
    end
  end
end
