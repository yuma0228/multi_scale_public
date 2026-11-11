# -*- coding: utf-8 -*-
require "colorize"
require 'command_line/global'

# `rake` だけで起動した場合にも，desc の内容をタスク一覧に使えるようにする．
Rake::TaskManager.record_task_metadata = true

task :default do
  Rake.application.options.show_tasks = :tasks
  Rake.application.options.show_task_pattern = //
  Rake.application.display_tasks_and_comments
end

desc "bye" #desc -> description
task :bye do # any name on task_name
  # your code goes
  puts "bye"
end

