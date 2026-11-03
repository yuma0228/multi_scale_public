# frozen_string_literal: true

# sync_styles.rake
#
# c0_mk_stack_dir/bin/templatesを正本として，共通のstyle/themeファイルを
# sync_styles.yamlに登録された複数のプロジェクトへ一括同期するRakefileである．
# 実際の同期処理はbin/sync_styles.rbが行う．
#
# ■ 同期対象
#
#   hiddenレイアウト：
#     .style.css
#     .style_w_link_button.css
#     .theme.css
#
#   docsレイアウト：
#     style.css
#     style_w_link_button.css
#     theme.css
#
# .style_for_image_content.cssは特殊用途のため，一斉同期の対象外である．
# この処理は同期対象ファイルを作成または上書きするが，不要ファイルの削除は行わない．
#
# ■ 最初にdry-runする
#
# c0_mk_stack_dirへ移動して，次を実行する．
#
#   DRY_RUN=1 rake -f sync_styles.rake sync_styles
#
# 別のディレクトリから実行する場合は，Rakefileを絶対パスまたは~付きパスで指定する．
#
#   DRY_RUN=1 rake \
#     -f ~/Desktop/lecture_26f/multi_scale/c0_mk_stack_dir/sync_styles.rake \
#     sync_styles
#
# dry-runではファイルを書き換えず，次のいずれかを表示する．
#
#   same         正本と同期先が同一である．
#   would update 本実行時に作成または上書きされる．
#
# 対象ディレクトリとwould updateの範囲が意図どおりであることを確認してから，
# 本実行へ進むこと．
#
# ■ 本実行
#
#   rake -f sync_styles.rake sync_styles
#
# 本実行では，変更対象をupdate，変更不要な対象をsameとして表示する．
#
# ■ sync_styles.yamlの設定
#
# 通常のHyperCardプロジェクトでは，ドット付きファイルを配置するhiddenを使う．
#
#   - path: ~/Desktop/lecture_26f/multi_scale
#     layout: hidden
#
# pathの末尾を/**にすると，指定ルートと配下を再帰探索し，直下に
# *readme*.orgまたは*canvas*.htmlを含むディレクトリだけへ適用する．
#
#   - path: ~/current_research/phase_diagram_26f/**
#     layout: hidden
#
# 再帰適用では，ドットで始まるディレクトリとシンボリックリンクを探索しない．
# 計算用ディレクトリなど，直下に*readme*.orgと*canvas*.htmlの
# どちらもないディレクトリは同期対象外となる．
# 本実行前にdry-runの対象一覧を必ず確認すること．
#
# al_110_ortho/docsのように非ドット名を使う構成ではdocsを指定する．
# wrapper_dirsに列挙した各節には，共通の../style.cssをimportする
# style_w_link_button.cssが生成される．
#
#   - path: ~/al_110_ortho/docs
#     layout: docs
#     wrapper_dirs:
#       - s0_abstract
#       - s1_intro
#
# ■ 正本を変更した場合
#
# 1．c0_mk_stack_dir/bin/templates内の正本を編集する．
# 2．dry-runで変更対象を確認する．
# 3．本実行で全プロジェクトへ反映する．
# 4．各リポジトリのgit diffとブラウザ表示を確認する．
#
# 同期対象の追加・削除，layoutの変更，除外規則など，今後の運用方針は
# sync_styles.yamlとbin/sync_styles.rbを併せて見直すこと．

require "rbconfig"
require "rake"

ROOT_DIR = File.expand_path(__dir__)
SYNC_SCRIPT = File.join(ROOT_DIR, "bin", "sync_styles.rb")
SYNC_CONFIG = File.join(ROOT_DIR, "sync_styles.yaml")

desc "sync style files listed in sync_styles.yaml (DRY_RUN=1 for preview)"
task :sync_styles do
  command = [RbConfig.ruby, SYNC_SCRIPT, "--config", SYNC_CONFIG]
  command << "--dry-run" if ENV["DRY_RUN"] == "1"
  sh(*command)
end

task default: :sync_styles
