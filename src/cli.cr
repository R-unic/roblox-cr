require "./shared"
require "./transpiler"
require "benchmark"
require "option_parser"
require "readline"
require "inotify-fixed"
require "json"
require "yaml"

def bold(content : String)
  "\e[1m#{content}\e[0m"
end

def default_config(project_name : String) : YAML::Any
  {
    "name": project_name,
    "root_dir": "src",
    "out_dir": "dist"
  }.to_yaml
end

def default_project(config : RobloxCrystalConfig) : JSON::Any
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
  @@last_changed_time : Float64? = nil
  @@debounce_interval = 0.25 # seconds

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
    if @@watch
      start_watch_mode
    else
      transpile
    end
  end

  def self.start_watch_mode
    puts "Started #{bold "roblox-cr"} in watch mode."
    puts bold "Watching #{@@path} for changes..."
    transpile
    Inotify.watch @@path, recursive: true do |ev|
      if @@last_changed_time.nil? || Time.utc.to_unix_f - @@last_changed_time.not_nil! >= @@debounce_interval
        unless [".cr", ".yml"].includes?(ev.name)
          puts bold "File change detected, compiling..."
          transpile
          @@last_changed_time = Time.utc.to_unix_f
        end
      end
    end
    sleep
  end

  def self.transpile
    return if @@init
    result = Benchmark.measure do
      Transpiler.do_directory dir_path: @@path, testing: @@test
    end
    puts "Finished. Took (#{(result.real * 1000).ceil.to_i}ms)"
  end

  def self.init_project
    project_name = Readline.readline bold("What is the name of your project? "), add_history: true
    init_git = (Readline.readline(bold("Do you want to initialize a git repository? (y/n) "), add_history: true) || "n").downcase == "y"
    add_snippets = (Readline.readline(bold("Do you want to add default code snippets? (y/n) "), add_history: true) || "n").downcase == "y"

    # Create the directory structure
    return if project_name.nil?
    config_yml = default_config project_name

    begin
      config = (JSON.parse(config_yml).as?(RobloxCrystalConfig) unless config_yml.nil?) || RobloxCrystalConfig.new("robloxcr-project", "src", "dist")
      FileUtils.mkdir(project_name)
      begin
        File.write "#{project_name}/default.project.json", default_project config
      rescue ex : Exception
        abort "Failed to write default Rojo project: #{ex.message}", Exit::FailedToWriteDefaultProject.value
      end
      begin
        File.write "#{project_name}/config.crystal.yml", config_yml
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
