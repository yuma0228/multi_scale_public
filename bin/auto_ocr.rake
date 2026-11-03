# -*- coding: utf-8 -*-
require "colorize"
require 'command_line/global'

task :default do
  system "rake -T"
end

desc "task description" #desc -> description
task :auto_ocr do # any name on task_name
  # your code goes
  Dir.glob('*.pdf').each do |file|
    source = file.split('.')
    target = source[0]+"_ocr.pdf"
    system "ocrmypdf -l jpn #{file} #{target}"
    system "mv #{target} #{file}"
  end
end

