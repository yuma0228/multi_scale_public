# -*- coding: utf-8 -*-
require "command_line/global"
require "colorize"
require "pathname"

$file = "readme"
$fig_dir = "./figs"

def init
  ["revtex4-2-head.tex", "#{$file}.org"].each do |file|
    file = File.join("~/bin/Rakefiles", file)
    system "cp #{file} ."
  end
end

def put_gather(hash)
  file = $file + ".org"
  main_text = []
  hash.each do |section, file_list|
    main_text << "* #{section}\n"
    next if file_list == nil or file_list.empty?
    file_list.each do |file|
      lines = File.readlines(file)
      conts = add_dir_head(lines, file)
      main_text += conts
    end
    main_text << "\n"
  end
  File.write(file, main_text.join)
end

def rewrite_file_links(line, source_file)
  source_dir = File.dirname(File.expand_path(source_file))
  output_dir = Pathname.new(Dir.pwd)

  line.gsub(/\[\[(file:)?([^\]]+)\]/) do
    original = Regexp.last_match(0)
    explicit_file_link = !Regexp.last_match(1).nil?
    target = Regexp.last_match(2)
    next original unless explicit_file_link || target.start_with?('./', '../')

    path, separator, search = target.partition('::')
    next original if Pathname.new(path).absolute?

    resolved = Pathname.new(File.expand_path(path, source_dir))
    relative = resolved.relative_path_from(output_dir).to_s
    relative = "./#{relative}" unless relative.start_with?('.')
    "[[file:#{relative}#{separator}#{search}]"
  end
end

def add_dir_head(lines, file)
  add_dir=file.split('/')[0..-2].join('/')

  lines.map do |line|
    line = rewrite_file_links(line, file)
#    p line
    # ヘッダー行なら*を1つ追加してlevel 2に
    if line =~ /^\*+ /
      line.sub(/^(\*+)/) { |stars| stars + "*" }
    # batch exportで確認できないremote SETUPFILEは除外
    elsif line =~ /^\s*#\+SETUPFILE:\s+https?:\/\//i
      nil
    elsif line =~ /^#\+include: "(.+)"/
      p include_file = "#{add_dir}/#{$1}"
      lines = File.readlines(include_file)
      add_dir_head(lines, file)
    else
      line
    end
  end.compact
end

def resize_table_images(tex_file)
  contents = File.read(tex_file)
  resized = contents.gsub(/\\begin\{tabular\}\{([^}]*)\}.*?\\end\{tabular\}/m) do |table|
    column_spec = Regexp.last_match(1)
    column_count = column_spec.scan(/[lcr]/).length
    next table if column_count < 1 || !table.include?('\\includegraphics')
    next table unless column_spec.match?(/\A[lcr]+\z/)

    column_width = format('%.3g', 0.88 / column_count)
    paragraph_columns = Array.new(column_count, "p{#{column_width}\\linewidth}").join
    table = table.sub("\\begin{tabular}{#{column_spec}}", "\\begin{tabular}{#{paragraph_columns}}")
    table.gsub(/(\\includegraphics\[[^\]]*?\bwidth=)[^,\]]+/) do
      "#{Regexp.last_match(1)}\\linewidth"
    end
  end
  File.write(tex_file, resized) if resized != contents
end

def org_2_latex
  file = $file
  comm = "emacs #{file}.org --batch --eval '(setq org-latex-images-centered nil)' -f org-latex-export-to-latex --kill"
  puts comm
  system comm
  resize_table_images("#{file}.tex")
end

def revtex(opts={})
  p opts
  file = $file
  if opts[:revtex]
    puts "install as following [[https://qiita.com/ryokbys/items/206e5a9bdfa5f174edb9]]"
    change_head_tail(file)
    file = file + "2"
  else
    title = opts[:title]
    author = opts[:author]
    change_readme_head(file, title, author)
  end
  commands = ["platex #{file}.tex",
              # "pbibtex #{file}",
              "platex #{file}.tex",
              "dvipdfmx #{file}",
             # "open #{file}.pdf"
             ]
  commands.each do |com|
    puts com
    system com
  end
end

def change_head_tail(file)
  file = $file
  contents = $contents_main
  lines_head = File.read("revtex4-2-head.tex")
  lines = File.readlines("#{file}.tex")
  main = lines[30..-1].join
  main.sub!('\documentclass[11pt]{article}', '\documentclass[dvipdfmx, a4paper, 12pt]{jsarticle}')
  main.sub!('\usepackage{graphicx}', '\usepackage[dvipdfmx]{graphicx}')
  main.sub!('\usepackage{hyperref}', '\usepackage[dvipdfmx]{hyperref}')
  File.open("#{file}2.tex", "w") do |f|
    f.print lines_head
    f.print main
  end
end

def change_readme_head(file, title=nil, author=nil)
  main = File.read("#{file}.tex")

  main.sub!(/\\title{.+}/,"\\title{#{title}}")
  main.sub!(/pdftitle={.+}/,"pdftitle={#{title}}")
  main.sub!(/\\author{.+}/,"\\author{#{author}}")
  main.sub!(/pdfauthor={.+}/,"pdfauthor={#{author}}")
  main.sub!('\documentclass[11pt]{article}', '\documentclass[dvipdfmx, a4paper, 12pt]{jsarticle}')
  main.sub!('\usepackage{graphicx}', '\usepackage[dvipdfmx]{graphicx}')
  main.sub!('\usepackage{hyperref}', '\usepackage[dvipdfmx]{hyperref}')
  File.open("#{file}.tex", "w") do |f|
    f.print main
  end
end

require 'yaml'
puts "\nrunning auto_merge.rb\n".green
file = ARGV[1] || 'dir_tree.yaml'
header_and_toc = YAML.load(File.read(file))
pp header_and_toc

put_gather(header_and_toc[:toc])
org_2_latex()

if ARGV[0]=='-s'
  revtex({revtex: false}.merge(header_and_toc[:header]))
else
  revtex(revtex: true)
end
