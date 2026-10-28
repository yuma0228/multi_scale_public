
desc "automatic mk dir for canvas.html" #desc -> description
task :auto_mk_dir, [:dir_name] do |_task, args| # any name on task_name
  t_name = 'tmp'
  Rake::Task[:mkdir].invoke(t_name)
  # your code goes
  dir_name = args[:dir_name] || 'hoge'
  system "mv #{dir_name} #{t_name}"
  system "mv #{t_name} #{dir_name}"
end
