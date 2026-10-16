require 'colorize'
# ssh, Github
# hidden_files/c1 ... c2 c2

puts "Array".green
names = ["Shigeto", "Nishitani", 65]
names.each do |val|
  p val
end

names.each_with_index do |val, i|
  p [i, val]
end

puts "Hash".green
p names = {first: "Shigeto", family: "Nishitani", age: 65}
# :key = symbol
names.each do |key, val|
  puts "%8s : %s" % [key, val]
end
