#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"

def symbolize_keys(object)
  case object
  when Hash
    object.each_with_object({}) do |(key, value), result|
      symbolized_key = key.is_a?(String) ? key.to_sym : key
      result[symbolized_key] = symbolize_keys(value)
    end
  when Array
    object.map { |item| symbolize_keys(item) }
  else
    object
  end
end

input_path = ARGV.fetch(0, "light_table.yaml")
output_path = "tmp.yaml"

data = YAML.load_file(input_path)
symbolized_data = symbolize_keys(data)

File.write(output_path, YAML.dump(symbolized_data))
puts "#{input_path} -> #{output_path}"
