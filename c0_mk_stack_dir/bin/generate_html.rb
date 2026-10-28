require 'yaml'
require 'erb'

def render_items(items)
  items.map do |item|
    display_title = item[:title] || File.basename(item[:href], '.*')
    img_src = item[:src] || 'c0_mk_stack_dir/templates/dummy_icon.png'
    
    img_tag = if File.exist?(img_src)
      <<-IMG
          <img src="#{img_src}" 
            alt="#{File.basename(img_src)}" 
            loading="lazy" 
            style="width: 100%; height: auto; display: block; margin-bottom: 8px;">
      IMG
    else
      ""
    end

    <<-HTML
      <td style="padding: 5px; vertical-align: top; width: 33.33%;">
        <a href="#{item[:href]}" target="_blank" style="text-decoration: none; color: inherit;">
#{img_tag}          <span style="display: block; text-align: center; font-size: 0.9em; word-break: break-all;">#{display_title}</span>
        </a>
      </td>
    HTML
  end.join
end

def render_sections(sections)
  sections.map do |sec|
    <<-HTML
    <h2 id="#{sec[:id]}">#{sec[:title]}</h2>
    <div class="outline-text-2">
      <table class="light-table" style="width: 100%; border-collapse: collapse;">
        <tr>
#{render_items(sec[:items])}
        </tr>
      </table>
    </div>
    HTML
  end.join
end

def render_toc(sections)
  sections.map do |sec|
    <<-HTML
      <li><a href="##{sec[:id]}">#{sec[:title]}</a></li>
    HTML
  end.join
end

yaml_data = YAML.load_file('light_table.yaml', symbolize_names: true)

# 'up'要素からタイトルを取得、存在しない場合はデフォルトの'Light Table'を設定
# YAMLの構造に合わせて、up配列の最初の要素のtitleを取得します
up_section = yaml_data.find { |sec| sec.key?(:up) }
page_title = up_section&.dig(:up, 0, :title) || 'Light Table'

# 'up' の要素を取り除き、'items' を持つ要素のみをセクションとして抽出
sections = yaml_data.select { |sec| sec.key?(:items) }

template = <<-ERB
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title><%= page_title %></title>
  <link rel="stylesheet" href=".style.css">
</head>
<body>
  <div id="table-of-contents">
    <h2>Table of Contents</h2>
    <ul>
<%= render_toc(sections) %>
    </ul>
  </div>
  <div id="content">
    <h1 class="title"><%= page_title %></h1>
    <p>画像をクリックしてもリンクに飛びます.</p>
 
<%= render_sections(sections) %>
  </div>
</body>
</html>
ERB

html = ERB.new(template, trim_mode: '-').result(binding)

# 出力ファイル名を 'up' の :href から取得、無ければ 'up_link.html' をデフォルトとする
file = up_section&.dig(:up, 0, :href) || 'up_link.html'
File.write(file, html)

puts "generate #{file}."
