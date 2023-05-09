def fib(n : Int) : Int
  n <= 1 ? n : (fib(n - 1) + fib(n - 2))
end

puts fib 10 #=> 55
