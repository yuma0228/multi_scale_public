# frozen_string_literal: true

require 'cgi'
require 'fileutils'
require 'pathname'
require 'rbconfig'
require 'yaml'

PROJECT_DIR = Pathname.new(__dir__).expand_path.freeze
TOOLS_DIR = PROJECT_DIR.join('../c0_mk_stack_dir/bin').cleanpath.freeze
INPUT_YAML = Pathname.new('.semi_lattice/dir_node_edge.yaml').freeze
LAYOUT_YAML = Pathname.new('.semi_lattice/semi_lattice.yaml').freeze
MAX_LEVEL = Integer(ENV.fetch('LEVEL', '2'), 10)

def html_files
  Dir.glob('**/*.html').select do |file|
    depth = Pathname.new(file).each_filename.count
    File.file?(file) && depth <= MAX_LEVEL && file != 'canvas.html'
  end.sort
end

def html_title(html)
  title = html[/<title\b[^>]*>(.*?)<\/title>/mi, 1]
  return unless title

  CGI.unescapeHTML(title.gsub(/<[^>]+>/, '').gsub(/\s+/, ' ').strip)
end

def icon_path(file, html)
  sources = html.scan(/<img\b[^>]*\bsrc\s*=\s*["']([^"']+)["']/i).flatten
  source = sources.last
  return unless source
  return if source.match?(%r{\A(?:[a-z][a-z0-9+.-]*:|//|/)}i)

  Pathname.new(file).dirname.join(source.sub(%r{\A\./}, '')).cleanpath.to_s
end

def node_name(file, html)
  html_title(html) || Pathname.new(file).basename('.html').to_s.tr('_-', ' ')
end

def build_graph(files)
  root_id = 1
  nodes = [{
    id: root_id,
    name: 'Bundler and TDD',
    type: 'stack',
    file_path: '.'
  }]
  edges = []
  directory_ids = { '.' => root_id }
  next_id = root_id + 1

  directories = files.map { |file| Pathname.new(file).dirname.to_s }
                     .reject { |directory| directory == '.' }
                     .uniq
                     .sort_by { |directory| [Pathname.new(directory).each_filename.count, directory] }

  directories.each do |directory|
    directory_ids[directory] = next_id
    parent = Pathname.new(directory).dirname.to_s
    nodes << {
      id: next_id,
      name: Pathname.new(directory).basename.to_s.tr('_-', ' '),
      type: 'dir',
      file_path: directory
    }
    edges << { from: directory_ids.fetch(parent), to: next_id }
    next_id += 1
  end

  files.each do |file|
    html = File.read(file, encoding: 'UTF-8', invalid: :replace, undef: :replace)
    node_id = next_id
    parent = Pathname.new(file).dirname.to_s
    nodes << {
      id: node_id,
      name: node_name(file, html),
      type: 'icon',
      file_path: file,
      icon_path: icon_path(file, html)
    }
    edges << { from: directory_ids.fetch(parent), to: node_id }
    next_id += 1
  end

  { nodes: nodes, edges: edges }
end

desc '深さ2までのHTMLからCanvas配置用YAMLを作る（LEVELで深さを変更可能）'
task :prepare do
  Dir.chdir(PROJECT_DIR) do
    abort 'LEVELは1以上で指定してください．' if MAX_LEVEL < 1

    files = html_files
    abort '対象となるHTMLが見つかりませんでした．' if files.empty?

    FileUtils.mkdir_p(INPUT_YAML.dirname)
    File.write(INPUT_YAML, YAML.dump(build_graph(files)))

    puts "#{INPUT_YAML} を生成しました（HTML #{files.length}件）．"
    files.each { |file| puts "  - #{file}" }
  end
end

desc 'hc viewでノードを配置し，semi_lattice.yamlを作る'
task layout: :prepare do
  Dir.chdir(PROJECT_DIR) do
    sh 'hc', 'view', '-n', INPUT_YAML.to_s
    abort "#{LAYOUT_YAML} が生成されませんでした．" unless LAYOUT_YAML.file?
  end
end

desc 'semi_lattice.yamlからcanvas.htmlを生成する'
task render: :layout do
  Dir.chdir(PROJECT_DIR) do
    generator = TOOLS_DIR.join('mk_canvas.rb')
    abort "生成スクリプトが見つかりません: #{generator}" unless generator.file?

    sh RbConfig.ruby, generator.to_s
  end
end

desc 'HTMLツリーからcanvas.htmlを生成し，表示する（OPEN=0で表示を省略）'
task mk_canvas: :render do
  Dir.chdir(PROJECT_DIR) do
    sh 'hc', 'view' unless ENV['OPEN'] == '0'
  end
end

task default: :mk_canvas
