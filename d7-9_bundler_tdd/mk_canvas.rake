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
IMAGE_EXTENSIONS = %w[avif bmp gif heic heif ico jpe jpeg jpg jxl png svg tif tiff webp].freeze
STACK_ICON = '.semi_lattice/icons/stack.png'
FOLDER_ICON = '.semi_lattice/icons/folder.png'

def files_at_level(extension)
  Dir.glob("**/*.#{extension}").select do |file|
    File.file?(file) && Pathname.new(file).each_filename.count <= MAX_LEVEL
  end.sort
end

def org_files
  files_at_level('org')
end

def org_text(file)
  File.read(file, encoding: 'UTF-8', invalid: :replace, undef: :replace)
end

def org_export_path(file, text = org_text(file))
  export_name = text[/^#\+EXPORT_FILE_NAME:\s*(.+?)\s*$/i, 1]
  name = export_name ? export_name.strip : Pathname.new(file).basename('.org').to_s
  name += '.html' if File.extname(name).empty?

  path = Pathname.new(file).dirname.join(name).cleanpath
  abort "プロジェクト外へのHTML出力は指定できません: #{path}" if path.absolute? || path.each_filename.first == '..'

  path.to_s
end

def org_title(text)
  title = text[/^#\+TITLE:\s*(.+?)\s*$/i, 1]
  title&.strip
end

def org_icon_path(file, text = org_text(file))
  image_pattern = IMAGE_EXTENSIONS.join('|')
  image_regexp = /\[\[file:([^\]\n]+\.(?:#{image_pattern}))(?:\]\[[^\]]*\])?\]\]/i
  in_block = false

  text.each_line do |line|
    in_block = true if line.match?(/^\s*#\+begin_/i)
    next if in_block || line.match?(/^\s*#(?!\+)/)

    source = line[image_regexp, 1]
    next unless source
    next if source.match?(%r{\A(?:[a-z][a-z0-9+.-]*:|//|/)}i)

    return Pathname.new(file).dirname.join(source.sub(%r{\A\./}, '')).cleanpath.to_s
  ensure
    in_block = false if line.match?(/^\s*#\+end_/i)
  end

  nil
end

def html_title(html)
  title = html[/<title\b[^>]*>(.*?)<\/title>/mi, 1]
  return unless title

  CGI.unescapeHTML(title.gsub(/<[^>]+>/, '').gsub(/\s+/, ' ').strip)
end

def node_name(html_file, org_file = nil)
  if File.file?(html_file)
    title = html_title(File.read(html_file, encoding: 'UTF-8', invalid: :replace, undef: :replace))
    return title if title && !title.empty?
  end

  title = org_title(org_text(org_file)) if org_file
  title || Pathname.new(html_file).basename('.html').to_s.tr('_-', ' ')
end

def html_node(id, html_file, org_file = nil, fallback_icon: FOLDER_ICON)
  {
    id: id,
    name: node_name(html_file, org_file),
    type: 'icon',
    file_path: html_file,
    icon_path: (org_file && org_icon_path(org_file)) || fallback_icon
  }
end

def directories_for(files)
  directories = ['.']

  files.each do |file|
    directory = Pathname.new(file).dirname
    until directory.to_s == '.'
      directories << directory.to_s
      directory = directory.dirname
    end
  end

  directories.uniq.sort_by do |directory|
    [directory == '.' ? 0 : Pathname.new(directory).each_filename.count, directory]
  end
end

def relative_link(from_org, target_html)
  relative = Pathname.new(target_html).relative_path_from(Pathname.new(from_org).dirname).to_s
  relative.include?(File::SEPARATOR) ? relative : "./#{relative}"
end

def rewrite_buttons(orgs, html_by_org)
  pages = orgs.map { |org| html_by_org.fetch(org) }

  orgs.each_with_index do |org, index|
    targets = {
      'prev_button' => pages[(index - 1) % pages.length],
      'up_button' => 'canvas.html',
      'next_button' => pages[(index + 1) % pages.length]
    }
    original = File.read(org, encoding: 'UTF-8')
    lines = original.lines
    replaced = {}

    lines.each_with_index do |line, line_index|
      break if line.match?(/^\*+\s/)

      targets.each do |button, target|
        next if replaced[button] || !line.include?("[#{button}]]")

        lines[line_index] = "[[file:#{relative_link(org, target)}][#{button}]]\n"
        replaced[button] = true
        break
      end
    end

    missing = targets.keys - replaced.keys
    warn "buttonsが見つかりません: #{org} (#{missing.join(', ')})" unless missing.empty?
    updated = lines.join
    File.write(org, updated) if updated != original
  end
end

def build_graph(files, org_by_html)
  nodes = []
  edges = []
  directory_ids = {}
  representative_files = []
  next_id = 1

  directories_for(files).each do |directory|
    readme_org = directory == '.' ? 'readme.org' : File.join(directory, 'readme.org')
    representative_html = org_by_html.key(readme_org)
    directory_ids[directory] = next_id

    if representative_html
      fallback_icon = directory == '.' ? STACK_ICON : FOLDER_ICON
      nodes << html_node(next_id, representative_html, readme_org, fallback_icon: fallback_icon)
      representative_files << representative_html
    else
      nodes << {
        id: next_id,
        name: directory == '.' ? 'Bundler and TDD' : Pathname.new(directory).basename.to_s.tr('_-', ' '),
        type: directory == '.' ? 'stack' : 'dir',
        file_path: directory
      }
    end

    unless directory == '.'
      parent = Pathname.new(directory).dirname.to_s
      edges << { from: directory_ids.fetch(parent), to: next_id }
    end
    next_id += 1
  end

  (files - representative_files).each do |file|
    parent = Pathname.new(file).dirname.to_s
    nodes << html_node(next_id, file, org_by_html[file])
    edges << { from: directory_ids.fetch(parent), to: next_id }
    next_id += 1
  end

  { nodes: nodes, edges: edges }
end

desc 'Org内のbuttonsを更新し，EmacsでHTMLを生成する'
task :refresh_html do
  Dir.chdir(PROJECT_DIR) do
    abort 'LEVELは1以上で指定してください．' if MAX_LEVEL < 1

    orgs = org_files
    abort '対象となるOrgファイルが見つかりませんでした．' if orgs.empty?

    html_by_org = orgs.to_h { |org| [org, org_export_path(org)] }
    rewrite_buttons(orgs, html_by_org)

    init_file = File.expand_path('~/.emacs.d/init.el')
    emacs_args = [
      '--batch', '-l', init_file,
      '--eval', '(setq inhibit-message t message-log-max nil)'
    ]
    orgs.each do |org|
      emacs_args.concat [org, '-f', 'org-html-export-to-html']
    end
    emacs_args << '--kill'
    sh ENV.fetch('EMACS', 'emacs'), *emacs_args

    orgs.each do |org|
      output = html_by_org.fetch(org)
      abort "HTMLが生成されませんでした: #{output}" unless File.file?(output)
      puts "#{org} -> #{output}"
    end
  end
end

desc 'Org由来のHTMLからCanvas配置用YAMLを作る（LEVELで深さを変更可能）'
task prepare: :refresh_html do
  Dir.chdir(PROJECT_DIR) do
    orgs = org_files
    html_by_org = orgs.to_h { |org| [org, org_export_path(org)] }
    org_by_html = html_by_org.invert
    files = html_by_org.values.sort

    FileUtils.mkdir_p(INPUT_YAML.dirname)
    File.write(INPUT_YAML, YAML.dump(build_graph(files, org_by_html)))

    puts "#{INPUT_YAML} を生成しました（Org／HTML #{files.length}件）．"
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

desc 'Org更新からcanvas.html生成まで実行する（OPEN=1で完成後に表示）'
task mk_canvas: :render do
  Dir.chdir(PROJECT_DIR) do
    sh 'hc', 'view' if ENV['OPEN'] == '1'
  end
end

task default: :mk_canvas
