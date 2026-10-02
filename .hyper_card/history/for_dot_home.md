daddygongon: '.' , '..', '~'に対応するように変更．

GitHub Copilot: ````ruby
#!/usr/bin/env ruby
require 'open3'

targets = ARGV.empty? ? ['.'] : ARGV
targets.each do |target|
  # Expand special directories
  case target
  when '.'
    path = Dir.pwd
  when '..'
    path = File.expand_path('..', Dir.pwd)
  when '~'
    path = Dir.home
  else
    path = target
  end

  case
  when path == Dir.pwd
    system "explorer.exe #{path}"
  when path.match(/^http/)
    system "explorer.exe #{path}"
  when path.match(/(html|pdf|jpg|jpeg|png|pptx|xls|docx)$/)
    out, err, status = Open3.capture3("wslpath -m #{path}")
    target_path = "file:#{out.strip}"
    p target_path
    system "explorer.exe #{target_path}"
  else
    puts "no command for #{target}"
  end
end
````

daddygongon: もっとまとめて．

GitHub Copilot: ````ruby
#!/usr/bin/env ruby
require 'open3'

targets = ARGV.empty? ? ['.'] : ARGV

targets.each do |target|
  # Expand special directories
  path =
    case target
    when '.', '..'
      File.expand_path(target)
    when '~'
      Dir.home
    else
      target
    end

  if path =~ /^http/
    system "explorer.exe #{path}"
  elsif path =~ /\.(html|pdf|jpg|jpeg|png|pptx|xls|docx)$/i
    out, _, _ = Open3.capture3("wslpath -m #{path}")
    system "explorer.exe file:#{out.strip}"
  else
    system "explorer.exe #{path}"
  end
end
````

daddygongon: open ~でubuntu on wslでDir.homeがひらくように修正

GitHub Copilot: ````ruby
#!/usr/bin/env ruby
require 'open3'

targets = ARGV.empty? ? ['.'] : ARGV

targets.each do |target|
  # Expand special directories
  path =
    case target
    when '.', '..'
      File.expand_path(target)
    when '~'
      ENV['HOME'] # WSL上のホームディレクトリ
    else
      target
    end

  if path =~ /^http/
    system "explorer.exe #{path}"
  elsif path =~ /\.(html|pdf|jpg|jpeg|png|pptx|xls|docx)$/i
    out, _, _ = Open3.capture3("wslpath -m #{path}")
    system "explorer.exe file:#{out.strip}"
  else
    system "explorer.exe #{path}"
  end
end
````

daddygongon: pathがhttpで始まる以外はelsif以下を実行するように変更．

GitHub Copilot: ````ruby
if path =~ /^http/
  system "explorer.exe #{path}"
else
  if path =~ /\.(html|pdf|jpg|jpeg|png|pptx|xls|docx)$/i
    out, _, _ = Open3.capture3("wslpath -m #{path}")
    system "explorer.exe file:#{out.strip}"
  else
    system "explorer.exe #{path}"
  end
end
````
