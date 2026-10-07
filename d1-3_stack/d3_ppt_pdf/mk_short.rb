#!/usr/bin/env ruby
# frozen_string_literal: true

# Convert links such as
# [[https://example.com/...][file:./hidden_files/document.pdf]]
# into the short, non-link form
# document.pdf

script_dir = __dir__
input_path = File.expand_path(ARGV[0] || 'readme.org', script_dir)
output_path = File.expand_path(ARGV[1] || 'readme_short.org', script_dir)

source = File.read(input_path)
replacement_count = 0

shortened = source.gsub(%r{\[\[[^\]\n]+\]\[file:(?:\./)?hidden_files/([^\]/\n]+)\]\]}) do
  replacement_count += 1
  Regexp.last_match(1)
end

File.write(output_path, shortened)
puts "#{output_path}: shortened #{replacement_count} link(s)"
