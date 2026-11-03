require 'yaml'
require 'optparse'

IMAGE_EXTENSIONS = %w[
    .avif .bmp .gif .heic .heif .ico .jpe .jpeg .jpg .jxl
    .png .svg .tif .tiff .webp
].freeze

def page_data(file)
    if IMAGE_EXTENSIONS.include?(File.extname(file).downcase)
        return { href: file, src: file, title: nil }
    end

    html_text = File.read(file, encoding: "UTF-8", invalid: :replace, undef: :replace)
    title_match = html_text.match(/<title>(.*?)<\/title>/mi)
    img_matches = html_text.scan(/<img[^>]+src="([^"]+)"/i)
    img_src = img_matches.last&.first

    {
        href: file,
        src: img_src ? File.join(File.dirname(file), img_src.sub(/\A\.\//, '')) : nil,
        title: title_match&.[](1)&.strip
    }
end

def section_title(directory)
    File.basename(directory).sub(/\Ac\d+_?/, '').tr('_-', ' ').strip
end

options = {}
OptionParser.new do |parser|
    parser.banner = "Usage: ruby #{File.basename($PROGRAM_NAME)} [-L LEVEL]"
    parser.on('-L LEVEL', Integer, '探索する最大階層（tree -L と同じ数え方）') do |level|
        raise OptionParser::InvalidArgument, 'LEVEL は1以上で指定してください' if level < 1

        options[:max_level] = level
    end
end.parse!

begin
    config = YAML.load_file(".hc_config.yaml")
rescue Errno::ENOENT
    abort "Error: .hc_config.yaml を開けませんでした。"
end

data = [
    { up: [{ href: config[:source_html], title: config[:lecture] }] }
]
pp data

if options[:max_level]
    max_level = options[:max_level]
    glob_patterns = ['**/*.html']
    files = Dir.glob(glob_patterns).select do |file|
        File.file?(file) && file.sub(/\A\.\//, '').split(File::SEPARATOR).length <= max_level
    end.sort
    p ['max_level', max_level]
else
    glob_extensions = config[:glob_extensions] || "c*/*.html"
    p ['glob_ext', glob_extensions]
    glob_patterns = Array(glob_extensions)
    files = Dir.glob(glob_patterns).select { |file| File.file?(file) }.sort
end

# c*/**/*.html のように独立した ** が指定された場合だけ、
# 第一階層のディレクトリごとにセクションを作る。
hierarchical = options[:max_level] || glob_patterns.any? do |pattern|
    pattern.split(File::SEPARATOR).include?('**')
end

file_groups = if hierarchical
    files.group_by do |file|
        file.sub(/\A\.\//, '').split(File::SEPARATOR).first
    end.to_a
else
    # 従来の一階層構成との互換性を保つ。
    files.each_slice(3).map { |group| [nil, group] }
end

file_groups.each_with_index do |(directory, group), index|
    group.each { |file| p file }

    data << {
        id: "section-#{index}",
        title: directory ? section_title(directory) : "セクション #{index}",
        items: group.map { |file| page_data(file) }
    }
end

File.write("light_table.yaml", YAML.dump(data))
