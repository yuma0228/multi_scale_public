# -*- coding: utf-8 -*-
require "colorize"
require 'command_line/global'

task :default do
  system "rake -T"
end

desc "引数を表示する"
task :hello, [:name] do |_task, args|
  puts "Hello, #{args[:name]}"
  exit
end
