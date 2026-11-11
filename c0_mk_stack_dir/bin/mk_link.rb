require 'yaml'

semi_lattice_file = '.semi_lattice/semi_lattice.yaml'
data = YAML.load_file(semi_lattice_file)

# up には canvas.html を使う．
canvas_file = 'canvas.html'
if File.exist?(canvas_file)
  up = canvas_file
else
  up = $source_html
end
p up

# nodes の掲載順に，HTML と対応する Org ファイルを抽出する．
hrefs = data.fetch(:nodes).filter_map.with_index do |node, node_i|
  href = node[:file_path]
  unless href.is_a?(String)
    warn "file_path異常: node=#{node_i}, name=#{node[:name].inspect}"
    next
  end

  next unless href.end_with?('.html')
  next unless File.exist?(href.sub(/\.html\z/, '.org'))

  href
end

div = hrefs.size
org_files = []

hrefs.each_with_index do |f, i|
  p org_file = f.sub(/\.html\z/, '.org')
  org_files << org_file
  
  layers = f.split('/').size-1
  up_move= '../'*layers
  lines = File.readlines(org_file)
  lines.each_with_index do |line, j|
    lines[j] = "[[#{up_move}#{hrefs[(i-1)%div]}][prev_button]]\n" if line.include?('[prev_button]]')
    lines[j] = "[[#{up_move}#{up}][up_button]]\n" if line.include?('[up_button]]')
    lines[j] = "[[#{up_move}#{hrefs[(i+1)%div]}][next_button]]\n" if line.include?('[next_button]]')
  end
  puts "[[#{up_move}#{hrefs[(i-1)%div]}][prev_button]]
[[#{up_move}#{up}][up_button]]
[[#{up_move}#{hrefs[(i+1)%div]}][next_button]]
"
  File.write(org_file, lines.join(""))
end

emacs_args = [
  '--batch', '-l', File.expand_path('~/.emacs.d/init.el'),
  '--eval', '(setq inhibit-message t message-log-max nil)'
]
org_files.each { |org_file| emacs_args.concat [org_file, '-f', 'org-html-export-to-html'] }
emacs_args << '--kill'
abort 'OrgからHTMLへの変換に失敗しました．' unless system('emacs', *emacs_args)
