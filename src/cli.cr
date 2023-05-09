require "./shared"
require "./transpiler"
require "benchmark"
require "option_parser"
require "readline"

def bold(content : String)
  "\e[1m#{content}\e[0m"
end

def default_config(project_name : String)
  {
    "name": project_name,
    "rootDir": "src",
    "outDir": "dist"
  }.to_json
end

def default_project(config : RobloxCrystalConfig)
  {
    "name": config.name,
    "tree": {
      "$className": "DataModel",
      "ReplicatedStorage": {
        "rbxcr_include": {
          "$path": "include",
          ".shards": {
            "$path": ".shards"
          }
        },
        "Crystal": {
          "$path": "#{config.outDir}/shared"
        }
      },
      "ServerScriptService": {
        "$className": "ServerScriptService",
        "Crystal": {
          "$path": "#{config.outDir}/server"
        }
      },
      "StarterPlayer": {
        "$className": "StarterPlayer",
        "StarterPlayerScripts": {
          "$className": "StarterPlayerScripts",
          "Crystal": {
            "$path": "#{config.outDir}/client"
          }
        }
      },
      "Workspace": {
        "$className": "Workspace",
        "$properties": {
          "FilteringEnabled": true
        }
      },
      "HttpService": {
        "$className": "HttpService",
        "$properties": {
          "HttpEnabled": true
        }
      },
      "SoundService": {
        "$className": "SoundService",
        "$properties": {
          "RespectFilteringEnabled": true
        }
      }
    }
  }.to_json
end

module CLI
  @@watch = false
  @@test = false
  @@init = false
  @@path = "."

  def self.run
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: rbxcr [DIRECTORY] [OPTIONS]\n\nThank you for using roblox-cr!"
      opts.on("-w", "--watch", "Watch project directory for changes") do
        @@watch = true
      end
      opts.on("-t", "--test", "Enable testing mode (for testing code without syncing to Roblox)") do
        @@test = true
      end
      opts.on("--init", "Enable testing mode (for testing code without syncing to Roblox)") do
        @@init = true
        init_project
      end
      opts.on("-DDIR", "--dir=DIR", "Set the directory to compile") do |dir|
        @@path = dir
      end
      opts.on("-h", "--help", "Show this message") do
        puts opts
        exit
      end
    end

    parser.parse(ARGV)
    result = Benchmark.measure { transpile }
    puts "Finished. Took (#{(result.real * 1000).ceil.to_i}ms)"
  end

  def self.transpile
    return if @@init
    Transpiler.do_directory dir_path: @@path, testing: @@test
  end

  def self.init_project
    project_name = Readline.readline bold("What is the name of your project? "), add_history: true
    init_git = (Readline.readline(bold("Do you want to initialize a git repository? (y/n) "), add_history: true) || "n").downcase == "y"
    add_snippets = (Readline.readline(bold("Do you want to add default code snippets? (y/n) "), add_history: true) || "n").downcase == "y"

    # Create the directory structure
    return if project_name.nil?
    config_json = default_config project_name

    begin
      config = (JSON.parse(config_json).as?(RobloxCrystalConfig) unless config_json.nil?) || RobloxCrystalConfig.new("robloxcr-project", "src", "dist")
      FileUtils.mkdir(project_name)
      begin
        File.write "#{project_name}/default.project.json", default_project config
      rescue ex : Exception
        abort "Failed to write default Rojo project: #{ex.message}", Exit::FailedToWriteDefaultProject.value
      end
      begin
        File.write "#{project_name}/config.crystal.json", config_json
      rescue ex : Exception
        abort "Failed to write default Crystal config: #{ex.message}", Exit::FailedToWriteDefaultConfig.value
      end
      begin
        FileUtils.mkdir_p "#{project_name}/#{config.rootDir}/client"
        File.write "#{project_name}/#{config.rootDir}/client/main.client.cr", ""
        FileUtils.mkdir_p "#{project_name}/#{config.rootDir}/server"
        File.write "#{project_name}/#{config.rootDir}/server/main.server.cr", ""
        FileUtils.mkdir_p "#{project_name}/#{config.rootDir}/shared"
        File.write "#{project_name}/#{config.rootDir}/shared/module.cr", ""
      rescue ex : Exception
        abort "Failed to create project structure: #{ex.message}", Exit::FailedToCreateStructure.value
      end
    rescue ex : Exception
      abort "Error parsing config: #{ex.message}", Exit::InvalidConfig.value
    end

    `git init #{project_name}/` if init_git
    puts "Successfully initialized project."
  end
end
