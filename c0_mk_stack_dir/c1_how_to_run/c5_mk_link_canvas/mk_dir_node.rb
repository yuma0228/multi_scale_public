require 'yaml'
require 'pathname'

# 1. 入力ファイルと出力ファイルを定義
input_yaml = 'light_table.yaml'
output_dir = '.semi_lattice'
output_yaml = File.join(output_dir, 'dir_node_edge.yaml')

# YAMLのキーをシンボルに変換するヘルパーメソッド
def symbolize_keys(obj)
  case obj
  when Hash
    obj.each_with_object({}) do |(k, v), result|
      result[k.to_sym] = symbolize_keys(v)
    end
  when Array
    obj.map { |v| symbolize_keys(v) }
  else
    obj
  end
end

# 2. light_table.yamlを読み込む
data = YAML.load_file(input_yaml)
data = symbolize_keys(data)

# 3. ノードとエッジのデータを構築
nodes = []
edges = []

# ルートノード (hyper_card/) を追加
root_node_id = 1
nodes << {
  id: root_node_id,
  name: 'hyper_card/',
  type: 'dir',
  file_path: '.'
}

# light_table.yamlの各アイテムをノードに変換
node_id_counter = 2
data.each do |section|
  next unless section[:items]
  section[:items].each do |item|
    name = if item[:title]
             item[:title]
           else
             Pathname.new(item[:href]).parent.basename.to_s
           end

    nodes << {
      id: node_id_counter,
      name: name,               # :title or parent dir name -> :name
      type: 'icon',           # タイプを 'icon' に変更
      file_path: item[:href],  # :href -> :file_path
      icon_path: item[:src]    # :src -> :icon_path
    }
    edges << {
      from: root_node_id,
      to: node_id_counter
    }
    node_id_counter += 1
  end
end

# 4. YAMLとして出力するデータ構造を作成
output_data = {
  nodes: nodes,
  edges: edges
}

# 5. ディレクトリを作成し、YAMLファイルに書き出す
Dir.mkdir(output_dir) unless Dir.exist?(output_dir)
File.write(output_yaml, output_data.to_yaml)

puts "#{output_yaml} has been generated successfully."