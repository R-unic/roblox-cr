require "benchmark"
require "./transpiler"
require "./shared"

result = Benchmark.measure do
  dir = ARGV.empty? ? "." : ARGV.first
  Transpiler.do_directory dir_path: dir, testing: true
end

puts "Compiled successfully. (#{(result.real * 1000).ceil.to_i}ms)"
