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

hrefs.each_with_index do |f, i|
  p org_file = f.sub(/\.html\z/, '.org')
  
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
  system "emacs #{org_file} --batch -l ~/.emacs.d/init.el -f org-html-export-to-html --kill"
end
