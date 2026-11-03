require 'yaml'
require 'erb'
require 'json'

# --- 前提 ---
# このスクリプトは'docs'ディレクトリから実行されることを想定
# .semi_lattice ディレクトリも'docs'内にある
# 例: cd /Users/bob/al_110_ortho/docs
#     ruby c0_mk_stack_dir/bin/mk_canvas.rb

# 1. YAMLファイルを読み込む (カレントディレクトリ'docs'からの相対パス)
yaml_file = '.semi_lattice/semi_lattice.yaml'
data = YAML.load_file(yaml_file)

# 2. ノードとエッジのデータを準備
default_icon_paths = {
  'dir' => '.semi_lattice/icons/folder.png',
  'stack' => '.semi_lattice/icons/stack.png'
}.freeze

nodes = data[:nodes].map do |node|
  # typeに対応する既定アイコンを，icon_pathが未指定の場合だけ補う
  if node[:icon_path].nil?
    node[:icon_path] = default_icon_paths[node[:type]]
  end

  # --- デバッグコード ---
  puts "Node ID: #{node[:id]}, Name: #{node[:name]}"
  if node[:icon_path]
    # File.exist?でチェックするパスは、'docs'からの相対パス
    check_path = node[:icon_path]
    exists = File.exist?(check_path)
    puts "  icon_path: '#{node[:icon_path]}', CheckPath: '#{check_path}', Exists: #{exists}"
    if !exists
      puts "  Warning: Icon file not found."
    end
  else
    puts "  icon_path: nil"
  end
  # --- デバッグコードここまで ---

  node
end.reverse! # 表示順を逆にするために配列をリバース

edges = data[:edges]

# 3. ERBテンプレートを準備
template = <<~'HTML'
<!DOCTYPE html>
<html>
<head>
  <title>Canvas Links</title>
  <meta charset="UTF-8">
  <link rel="stylesheet" href=".theme.css">
</head>
<body style="background-color: var(--background);">

<canvas id="myCanvas" width="1200" height="800" style="border:1px solid var(--border); cursor:pointer;"></canvas>

<script>
const canvas = document.getElementById('myCanvas');
const ctx = canvas.getContext('2d');

function themeColor(propertyName, fallback) {
  return getComputedStyle(document.documentElement)
    .getPropertyValue(propertyName).trim() || fallback;
}

// --- 高DPI対応 ---
const dpr = window.devicePixelRatio || 1;
const rect = canvas.getBoundingClientRect();
canvas.width = rect.width * dpr;
canvas.height = rect.height * dpr;
ctx.scale(dpr, dpr);
canvas.style.width = rect.width + 'px';
canvas.style.height = rect.height + 'px';
// --- ここまで ---

ctx.imageSmoothingQuality = 'high'; // 画像の描画品質を最高に設定

// 1. データ定義（Rubyで生成）
const nodes = <%= JSON.pretty_generate(nodes) %>;
const edges = <%= JSON.pretty_generate(edges) %>;

// ノードIDをキーにしたノード情報のマップを作成
const nodeMap = new Map(nodes.map(node => [node.id, node]));

const nodesWithIcons = nodes.filter(node => node.icon_path);
const defaultIconWidth = 120;
const defaultIconHeight = 90;

// 画像を読み込めない場合にもラベルとクリック領域を残す
nodes.forEach(node => {
  node.width = defaultIconWidth;
  node.height = defaultIconHeight;
  node.img = null;
  node.imageLoadError = false;
});

// 描画関数
function drawAll() {
  // Canvasをクリア
  ctx.clearRect(0, 0, canvas.width, canvas.height);

  // 背景色を設定
  ctx.fillStyle = themeColor('--background', '#ffffff');
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  // 2. エッジ（線）を描画
  ctx.strokeStyle = themeColor('--foreground', '#263f35');
  ctx.lineWidth = 1;
  edges.forEach(edge => {
    const fromNode = nodeMap.get(edge.from);
    const toNode = nodeMap.get(edge.to);
    if (fromNode && toNode) {
      ctx.beginPath();
      ctx.moveTo(fromNode.x, fromNode.y);
      ctx.lineTo(toNode.x, toNode.y);
      ctx.stroke();
    }
  });

  // 3. ノード（アイコンとテキスト）を描画
  nodes.forEach(node => {
    // 描画位置を画像の中心に補正
    const drawX = node.x - node.width / 2;
    const drawY = node.y - node.height / 2;

    if (node.img && node.img.naturalWidth > 0) {
      ctx.drawImage(node.img, drawX, drawY, node.width, node.height);
    } else {
      // 画像がない場合や読み込みに失敗した場合はプレースホルダーを表示
      ctx.fillStyle = themeColor('--muted', '#f4f7f3');
      ctx.strokeStyle = themeColor('--muted-foreground', '#52665d');
      ctx.fillRect(drawX, drawY, node.width, node.height);
      ctx.strokeRect(drawX, drawY, node.width, node.height);

      ctx.fillStyle = themeColor('--muted-foreground', '#52665d');
      ctx.font = '12px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText('image not found', node.x, node.y);
    }
    
    // 画像の読み込み結果にかかわらずタイトルを表示
    ctx.fillStyle = themeColor('--muted-foreground', '#52665d');
    ctx.font = `12px ${themeColor('--font-family-base', 'Arial, sans-serif')}`;
    ctx.textAlign = 'center';
    ctx.fillText(node.name, node.x, drawY + node.height + 15);
  });
}

// 画像の読み込み処理
function loadNodeImage(node) {
  return new Promise(resolve => {
    const img = new Image();

    img.onload = () => {
      // 元画像の縦横比を維持して高さを計算
      const aspectRatio = img.naturalHeight / img.naturalWidth;
      node.width = defaultIconWidth;
      node.height = defaultIconWidth * aspectRatio;
      node.img = img;
      resolve();
    };

    img.onerror = () => {
      node.img = null;
      node.imageLoadError = true;
      console.warn(`Icon image could not be loaded: ${node.icon_path}`, node);
      resolve();
    };

    // ハンドラを登録してから読み込みを開始する
    img.src = node.icon_path;
  });
}

// 一部の画像が読み込めなくても，全ノードの描画を継続する
Promise.all(nodesWithIcons.map(loadNodeImage)).then(drawAll);

// OSの自動appearance切替にも追従してCanvasを再描画する．
const darkModeQuery = window.matchMedia('(prefers-color-scheme: dark)');
darkModeQuery.addEventListener('change', drawAll);

// 4. クリックイベントの設定
canvas.addEventListener('click', (event) => {
  const rect = canvas.getBoundingClientRect();
  const clickX = event.clientX - rect.left;
  const clickY = event.clientY - rect.top;

  // クリックされたノードを逆順で探す（上に描画されたものが優先される）
  const clickedNode = nodes.slice().reverse().find(node => {
    if (!node.height || !node.file_path) return false;
    const drawX = node.x - node.width / 2;
    const drawY = node.y - node.height / 2;
    return (
      clickX >= drawX &&
      clickX <= drawX + node.width &&
      clickY >= drawY &&
      clickY <= drawY + node.height
    );
  });

  if (clickedNode) {
    window.open(clickedNode.file_path, '_blank');
  }
});
</script>

</body>
</html>
HTML

# 4. ERBでHTMLを生成
renderer = ERB.new(template)
output = renderer.result(binding)

# 5. canvas.htmlファイルに出力 (カレントディレクトリ'docs'に書き出す)
output_path = 'canvas.html'
File.write(output_path, output)

puts "#{output_path} has been generated successfully from #{yaml_file}."
