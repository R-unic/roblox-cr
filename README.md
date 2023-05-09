![build](https://github.com/Paragon-Studios/roblox-cr/actions/workflows/crystal.yml/badge.svg)
# roblox-cr

roblox-cr is a Crystal-to-Luau compiler for Roblox. It takes a string of Crystal code and converts it into Lua.

## Example (from [examples/fibonacci](https://github.com/Paragon-Studios/roblox-cr/blob/master/examples/fibonacci/src/client/main.client.cr))
Source
```cr
def fib(n : Int) : Int
  n <= 1 ? n : (fib(n - 1) + fib(n - 2))
end

puts fib 10 #=> 55
```
Output
```lua
function Fib(N)
	return (N <= 1 and N or Fib(N - 1) + Fib(N - 2))
end

print(Fib(10))
```

## Installation

1. Clone the repository
2. Run `make install`
3. Check if everything is working by running `rbxcr -h`

## Usage

1. Make a Roblox Crystal project using `rbxcr --init`
2. Write some code
3. Compile using `rbxcr` if you're inside of your project folder, otherwise `rbxcr -D <project_dir>`
4. Sync to Roblox using [Rojo](https://rojo.space/) or another syncing plugin.

## Might be added

- Macros

## Will not be added

- `loop` blocks
- `out` keyword

## Contributing

1. [Fork it](https://github.com/Paragon-Studios/roblox-cr/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [R-unic](https://github.com/R-unic) - creator and maintainer
