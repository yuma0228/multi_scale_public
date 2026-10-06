# -*- coding: utf-8 -*-
require 'yaml'
require "colorize"
require 'command_line/global'
require 'fileutils'

PROJECT_ROOT = File.expand_path(__dir__).freeze

RSYNC_OPTIONS = %w[
  -F
  -av
  --delete
  --itemize-changes
  --no-links
].freeze

RSYNC_EXCLUDES = %w[
  .venv/
  venv/
  env/
  .env/
  __pycache__/
  .git/
].freeze

def dry_run?
  ARGV.include?('dry_run')
end

def directory_path(path)
  "#{path.to_s.sub(%r{/+\z}, '')}/"
end

def rsync_options(source_dir:, remote:)
  options = RSYNC_OPTIONS.dup
  options << '--dry-run' if dry_run?
  options << '--filter=merge .rsync_filter' if File.file?(File.join(source_dir, '.rsync_filter'))
  options.concat(RSYNC_EXCLUDES.map { |pattern| "--exclude=#{pattern}" })
  options.concat(%w[-z --rsh=ssh]) if remote
  options
end

def rsync_directory(source_dir:, target_dir:, remote: false)
  source = File.expand_path(source_dir, Rake.application.original_dir)
  raise "Source directory does not exist: #{source}" unless File.directory?(source)

  target = remote ? target_dir : File.expand_path(target_dir, Rake.application.original_dir)
  FileUtils.mkdir_p(target) unless remote || dry_run?

  Dir.chdir(source) do
    sh(
      'rsync',
      *rsync_options(source_dir: source, remote: remote),
      './',
      directory_path(target)
    )
  end
end

begin
  config_path = File.join(PROJECT_ROOT, '.hc_config.yaml')
  config = YAML.load(File.read(config_path))
  p ['config', config]
rescue Errno::ENOENT
  config = {year: 2026,
 lecture: "intro_info",
 source_html: "intro_info_26s.html",
 glob_extensions: "c*/*.html",
 public_repository_dir: "../intro_info_public",
 server_info:
  {ruby_code_dir: "c0_mk_stack_dir",
   server_ssh_path: "nishitani@ist.ksc.kwansei.ac.jp:~/public_html",
   server_url: "https://ist.ksc.kwansei.ac.jp/~nishitani/Lectures"}}

  File.write(config_path,YAML.dump(config))
  puts "edit #{config_path}"
  exit
end

$year = config[:year].to_s
$lecture = config[:lecture] ||'intro_info'
$source_html = config[:source_html]

server_info = config[:server_info] || {}
$ruby_code_dir = server_info[:ruby_code_dir] || "c0_mk_stack_dir"
#$ruby_code_dir = File.join($ruby_code_dir, 'bin')
$server_ssh_path = server_info[:server_ssh_path] || "nishitani@ist.ksc.kwansei.ac.jp:~/public_html"
$server_url = server_info[:server_url] || "https://ist.ksc.kwansei.ac.jp/~nishitani/Lectures"

$public_repository_dir = File.expand_path(
  config.fetch(:public_repository_dir),
  PROJECT_ROOT
)

def remote_lecture_dir
  website_root = File.basename($server_url.sub(%r{/+\z}, ''))
  File.join($server_ssh_path, website_root, $year, $lecture)
end

task :default do
  puts "\nRakefile for c0_mk_stack_dir.".cyan
  p ['$public_repository_dir', $public_repository_dir]
  system "rake -T"
end

desc 'dry-run marker'
task :dry_run

desc 'rsync to public repository (first try: rake rsync_public dry_run)'
task :rsync_public do
  rsync_directory(
    source_dir: PROJECT_ROOT,
    target_dir: $public_repository_dir
  )
end

desc "kick off hyper card"
task :kick_off do
  puts "Kick off hyper card setups"
  hp = File.join($ruby_code_dir, 'templates')
  ["cp #{File.join(hp,'.style.css')} .",
   "cp #{File.join(hp,'.rsync_filter')} .",
   "cp #{File.join(hp,'.theme.css')} .",
   "head #{File.join(hp,'readme.org')} | tail -3",
  ].each do |comm|
    puts comm
    system comm unless comm[0]=='#'
  end
  
  exit
end
desc "browser check"
task :browser do
  puts ""
  puts "ruby -run -e httpd . -p 8000"
  puts "open http://localhost:8000/canvas.html"
  puts "open -a safari canvas.html"
  puts "com+opt+j for checking console on Chrome"
end

desc "show link files"
task :ln_lat do
  Dir.chdir(Rake.application.original_dir) do
    Dir.glob("./*").each do |file|
      if File.symlink?(file)
        symlink_path = File.readlink(file)
        puts "- [[#{symlink_path}][#{file}]](symlink)"
      elsif File.directory?(file)
        next
      end
    end
  end
end

desc "show files for markup list"
task :ls do
  Dir.chdir(Rake.application.original_dir) do
    Dir.glob("./*").each do |file|
      if File.symlink?(file)
        symlink_path = File.readlink(file)
        puts "- [[#{symlink_path}][#{file}]](symlink)"
      elsif File.directory?(file)
        next
      else
        puts "- [[file:#{file}][#{file}]]"
      end
    end
  end
end

desc "mk new sub directory"
task :mkdir do
  hp = File.join($ruby_code_dir, 'templates')
  dir_name = ARGV[1] || 'new_sub_dir'
  ["mkdir #{dir_name}",
   "cp #{File.join(hp,'readme.org')} #{dir_name}",
   "cp #{File.join(hp,'dummy_icon.png')} #{dir_name}",
   "cp #{File.join(hp,'.style_w_link_button.css')} #{dir_name}",
   "cp #{File.join(hp,'.theme.css')} #{dir_name}",
   "cp #{File.join(hp,'.rsync_filter')} #{dir_name}"
  ].each do |comm|
    puts comm
    system comm
  end
  exit
end

desc "DIR : make DIR light table" #desc -> description
task :mk_light_table => :show_dirs do # any name on task_name
  ["ruby #{File.join($ruby_code_dir, 'auto_mk_light_table.rb')}",
   "cp #{File.join($ruby_code_dir, 'templates','.style.css')} .",
   "For making light table structured, modify light_table.yaml.".green,
   "ruby #{File.join($ruby_code_dir, 'generate_html.rb')}",
  ].each do |comm|
    puts comm.green
    puts 'no system call'.red
  end
  exit
end

desc "show dirs for display light table DIR public." #desc -> description
task :show_dirs do # any name on task_name
  puts "Setup following dirs:".blue
  puts "source:            #{PROJECT_ROOT}".blue
  puts "public repository: #{$public_repository_dir}".blue
  puts "IST website:       #{remote_lecture_dir}".blue
  puts ""
end

desc "push public repository to web server (first try: rake push dry_run)"
task :push => :show_dirs do
  https_path = File.join($server_url,
                         $year, $lecture, $source_html)
  puts "rsync from #{$public_repository_dir}\n to #{remote_lecture_dir}\n".blue
  rsync_directory(
    source_dir: $public_repository_dir,
    target_dir: remote_lecture_dir,
    remote: true
  )
  sh 'open', https_path unless dry_run?
end

desc "create symlink and record it. usage: rake ln_s [source_dir]"
task :ln_s do
  source_dir = ARGV[1]
  unless source_dir && File.directory?(source_dir)
    puts "Usage: rake ln_s [source_dir]".red
    puts "Error: Source directory not provided or does not exist.".red
    exit
  end

  link_name = File.basename(source_dir)
  cwd = Dir.pwd
  
  # 1. Create symbolic link
  if File.exist?(link_name) || File.symlink?(link_name)
    puts "Link '#{link_name}' already exists in #{cwd}".yellow
  else
    comm = "ln -s #{source_dir} #{link_name}"
    puts comm.blue
    system comm
  end

  # 2. Update .linked.yaml in source directory
  linked_file = File.join(source_dir, '.linked.yaml')
  linked_paths = File.exist?(linked_file) ? YAML.load_file(linked_file) : []
  
  unless linked_paths.include?(cwd)
    linked_paths << cwd
    File.write(linked_file, YAML.dump(linked_paths))
    puts "Updated #{linked_file}".green
  else
    puts "#{cwd} already recorded in #{linked_file}".yellow
  end
end

desc "mk link from ligh_table.yaml"
task :mk_link do
  comm = "ruby #{File.join($ruby_code_dir, 'mk_link.rb')}"
  puts comm.blue
  puts "\nFor making links for up, prev, next buttons from light_table.yaml.".green
  exit
  
end
