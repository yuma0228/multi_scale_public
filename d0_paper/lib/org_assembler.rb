# frozen_string_literal: true

require "pathname"

class OrgAssembler
  def initialize(project_root:, output_dir:, public_base_url:)
    @project_root = Pathname.new(project_root).expand_path
    @output_dir = Pathname.new(output_dir).expand_path
    @public_base_url = public_base_url.sub(%r{/+\z}, "")
  end

  def assemble(structure:, structure_dir:, output_path:)
    contents = []

    structure.fetch(:toc).each do |section, source_files|
      contents << "* #{section}\n"
      Array(source_files).each do |source_file|
        path = Pathname.new(source_file).expand_path(structure_dir)
        contents.concat(transform_file(path))
      end
      contents << "\n"
    end

    File.write(output_path, contents.join)
  end

  private

  def transform_file(source_file)
    source_file.readlines.flat_map do |line|
      if line.match?(/^\*+ /)
        line.sub(/^(\*+)/) { |stars| stars + "*" }
      elsif line.match?(/^\s*#\+SETUPFILE:\s+https?:\/\//i)
        []
      elsif (match = line.match(/^#\+include:\s+"([^"]+)"/i))
        include_file = Pathname.new(match[1]).expand_path(source_file.dirname)
        transform_file(include_file)
      else
        rewrite_file_links(line, source_file)
      end
    end
  end

  def rewrite_file_links(line, source_file)
    line.gsub(/\[\[(file:)?([^\]\n]+)\](?:\[([^\]\n]*)\])?\]/) do
      original = Regexp.last_match(0)
      explicit_file_link = !Regexp.last_match(1).nil?
      target = Regexp.last_match(2)
      description = Regexp.last_match(3)
      next original unless explicit_file_link || target.start_with?("./", "../")

      path, separator, search = target.partition("::")
      next original if Pathname.new(path).absolute?

      resolved = Pathname.new(path).expand_path(source_file.dirname)

      if resolved.extname == ".org" && inside_project?(resolved) && search.empty?
        public_path = resolved.relative_path_from(@project_root).sub_ext(".html")
        label = description || public_path.basename.to_s
        "[[#{@public_base_url}/#{public_path}][#{label}]]"
      else
        relative = resolved.relative_path_from(@output_dir).to_s
        relative = "./#{relative}" unless relative.start_with?(".")
        rewritten = "[[file:#{relative}#{separator}#{search}]"
        description ? "#{rewritten}[#{description}]]" : "#{rewritten}]"
      end
    end
  end

  def inside_project?(path)
    path_string = path.expand_path.to_s
    path_string == @project_root.to_s ||
      path_string.start_with?("#{@project_root}#{File::SEPARATOR}")
  end
end
