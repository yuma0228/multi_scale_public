#!/usr/bin/env ruby
# mv hello.rb hello
# chmod a+x hello
name = ARGV[0] || "world"
# > ruby hello.rb Rudy
text = "Hello, " + name + "."
puts text


