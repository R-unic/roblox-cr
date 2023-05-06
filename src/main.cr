require "./shared"
require "./transpiler"
require "benchmark"

result = Benchmark.measure do
  dir = ARGV.empty? ? "." : ARGV.first
  Transpiler.do_directory dir_path: dir, testing: true
end

puts "Finished. Took (#{(result.real * 1000).ceil.to_i}ms)"
