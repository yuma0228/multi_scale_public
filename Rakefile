# -*- coding: utf-8 -*-
require 'yaml'
require "colorize"
require 'command_line/global'
require 'fileutils'

RSYNC_OPTIONS = %w[
  -av
  --no-links
].freeze

RSYNC_EXCLUDES = %w[
  .venv/
  venv/
  env/
  .env/
  __**pycache__**/
  .git/
].freeze

def sync_directory(source_dir, destination_root)
  destination = File.join(destination_root, source_dir)
  FileUtils.mkdir_p(destination)

  args = ['rsync', *RSYNC_OPTIONS]

  Dir.chdir(source_dir) do
    args << '--filter=merge .rsync_filter' if File.file?('.rsync_filter')
    args.concat(RSYNC_EXCLUDES.map { |pattern| "--exclude=#{pattern}" })
    args << './'
    args << "#{destination}/"

    sh(*args)
  end
end

begin
  config = YAML.load(File.read(".hc_config.yaml"))
  p ['config', config]
rescue Errno::ENOENT
  config = {year: 2026,
 lecture: "intro_info",
 source_html: "intro_info_26s.html",
 glob_extensions: "c*/*.html",
 server_info:
  {local_sites: "~/Sites/new_ist/Lectures",
   ruby_code_dir: "c0_mk_stack_dir",
   server_ssh_path: "nishitani@ist.ksc.kwansei.ac.jp:~/public_html",
   server_url: "https://ist.ksc.kwansei.ac.jp/~nishitani/Lectures"}}

  File.write(".hc_config.yaml",YAML.dump(config))
  puts "edit .hc_config.yaml"
  exit
end

$year = config[:year].to_s
$lecture = config[:lecture] ||'intro_info'
$source_html = config[:source_html]

server_info = config[:server_info] || {}
$local_sites = server_info[:local_sites] || "~/Sites/new_ist/Lectures"
$lecture_or_research = File.basename($local_sites)
$ruby_code_dir = server_info[:ruby_code_dir] || "c0_mk_stack_dir"
#$ruby_code_dir = File.join($ruby_code_dir, 'bin')
$server_ssh_path = server_info[:server_ssh_path] || "nishitani@ist.ksc.kwansei.ac.jp:~/public_html"
$server_url = server_info[:server_url] || "https://ist.ksc.kwansei.ac.jp/~nishitani/Lectures"

$local_dir = File.join($local_sites, $year)
$lec_dir = File.expand_path(File.join($local_dir,$lecture))
$glob_extensions = config[:glob_extensions] || "c*/*.html"

task :default do
  puts "\nRakefile for c0_mk_stack_dir.".cyan
  p ['$lec_dir', $lec_dir]
  system "rake -T"
end

desc 'dry-run marker'
task :dry_run

desc 'rsync to ../multi_scale_public( w w/o dry-run)'
task :rsync_public do
  options = %w[-F -avz --delete --itemize-changes]
  options << '--dry-run' if ARGV.include?('dry_run')

  sh(
    'rsync',
    *options,
    '--filter', 'merge .rsync_filter',
    '--no-links',
    '.',
    '../multi_scale_public/'
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
  puts "#{$lec_dir}".blue
  puts "#{$ist_dir}".blue
  puts ""
end

desc "commit local dir"
task commit: :show_dirs do
  FileUtils.mkdir_p($lec_dir)

  source_directories =
    (Dir.glob($glob_extensions.split('/').first) + ['.semi_lattice']).uniq

  source_directories
    .select { |path| File.directory?(path) }
    .each { |path| sync_directory(path, $lec_dir) }

  [
    $source_html,
    'style.css',
    'theme.css',
    'canvas.html',
    'folder.png'
  ].each do |source|
    if File.file?(source)
      FileUtils.cp(source, $lec_dir)
    else
      warn "Skip missing file: #{source}"
    end
  end

  sh 'chmod', '-R', 'a+r', $lec_dir
end

desc "push light tables to web server"
task :push => :show_dirs do
  https_dir = File.join($server_url,
                         $year, $lecture, $source_html)
  local_base_dir = File.join($local_sites, $year)
  ["rsync -F -auvz --no-links -e ssh #{local_base_dir} #{File.join($server_ssh_path, $lecture_or_research)}",
   "open #{https_dir}"].each do |comm|
    puts comm.blue
    system comm
  end
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
