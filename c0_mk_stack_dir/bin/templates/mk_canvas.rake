# frozen_string_literal: true
require 'colorize'

desc 'light_table.yamlからcanvas.htmlを生成して表示する'
task :mk_canvas do
  [['ruby', './c0_mk_stack_dir/bin/mk_light_table.rb', '-L', '3'],
   ['ruby', './c0_mk_stack_dir/bin/mk_dir_node.rb'],
   ['hc', 'view', '-n', '.semi_lattice/dir_node_edge.yaml'],
   ['ruby', './c0_mk_stack_dir/bin/mk_canvas.rb'],
   ['hc', 'view']].each do |comm|
    puts comm.join(' ').green
    sh *comm
  end
end

task :default do
  sh 'rake', '-T', '-f', 'mk_canvas.rake'
end
