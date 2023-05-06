require "./shared"
require "./transpiler"
require "benchmark"
require "option_parser"

module CLI
  @@watch = false
  @@test = false
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
      opts.on("-DDIR", "--dir=DIR", "Set the directory to compile") do |dir|
        @@path = dir
      end
      opts.on("-h", "--help", "Show this message") do
        puts opts
        exit
      end
    end

    result = Benchmark.measure do
      parser.parse(ARGV)
      Transpiler.do_directory dir_path: @@path, testing: @@test
    end

    puts "Finished. Took (#{(result.real * 1000).ceil.to_i}ms)"
  end
end



