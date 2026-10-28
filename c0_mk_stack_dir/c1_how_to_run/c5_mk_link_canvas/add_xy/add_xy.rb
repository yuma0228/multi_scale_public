require 'psych'
require 'yaml'

USAGE = <<~EOS
Usage: ruby #{__FILE__} [<file>] [<dd_x>] [<dd_y>]
  - If <file> is not a valid file, it's treated as <dd_x>.
  - Default file: 'semi_lattice_orig.yaml'
  - Default dd_x/dd_y: 100
EOS

puts USAGE

# 引数の解釈
args = ARGV.dup
file = (File.exist?(args.first.to_s) ? args.shift : 'semi_lattice_orig.yaml')

output_file = 'tmp.yaml'
dd_x = (args[0] || 100).to_i
dd_y = (args[1] || args[0] || 100).to_i

puts "Updating #{file}..."
puts "Adding #{dd_x} to x coordinates, #{dd_y} to y coordinates."
puts "------------------------------------"

output_lines = File.readlines(file).map do |line|
  # ":x: 123" や "  y: 456" のような行にマッチする
  if match = line.match(/^(\s*:?(x|y)):\s*(-?\d+)(.*)$/)
    key_part = match[1]
    key_char = match[2] # 'x' or 'y'
    current_value = match[3].to_i
    rest_of_line = match[4]

    dd = (key_char == 'x' ? dd_x : dd_y)
    new_value = current_value + dd

    new_line = "#{key_part}: #{new_value}#{rest_of_line}\n"
    puts "Changed: #{line.strip} -> #{new_line.strip}"
    new_line
  else
    line
  end
end

File.write(output_file, output_lines.join)

puts "------------------------------------"
puts "Updated content has been written to #{output_file}"
