require 'colorize'

puts "c1 String/print, puts".green
p name = '池田' # String
=begin
printf "Hello #{name}.\n"
puts "Hello #{name}."
=end
puts "Hello "+name+"."

puts "c2 Array".green
p name_year = [name, "悠真", 65]
name_year.each do |item| # method(arg)
  puts item
end
puts "c2 Hash".green
p name_year_hash = {family: name, first: "悠真", year: 65}
# def COMMENT 'hoge hoge'
name_year_hash = {:family => name, # symbol 
                  :first => "悠真",
                  :year => 65}
name_year_hash.each do |key, val|
  p [key, val]
end

p name_year_hash[:first]

puts "c2 Regular Expression".green
string = 'Yet Another Ruby Hacker,'
prob = "/Ruby/ =~ #{string}"
ans = /Ruby/ =~ 'Yet Another Ruby Hacker,'
puts "#{prob} : #{ans}"
# open http://rubular.com
p string.match(/(R.+)\s/)

puts "cx scanf".green
require 'scanf'
p string = "val = 4.0321"
p val = string.scanf("val = %f")[0]

puts "cx pretty print".green
puts "val : %15.10f" % val




