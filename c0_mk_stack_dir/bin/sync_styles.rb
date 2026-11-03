#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "find"
require "optparse"
require "pathname"
require "yaml"

PROJECT_ROOT = File.expand_path("..", __dir__)
DEFAULT_CONFIG = File.join(PROJECT_ROOT, "sync_styles.yaml")

options = {
  config: DEFAULT_CONFIG,
  dry_run: false
}

OptionParser.new do |parser|
  parser.banner = "Usage: sync_styles.rb [options]"
  parser.on("--config PATH", "configuration YAML (default: sync_styles.yaml)") do |path|
    options[:config] = File.expand_path(path)
  end
  parser.on("--dry-run", "show changes without writing files") do
    options[:dry_run] = true
  end
end.parse!

def read_config(path)
  YAML.safe_load(File.read(path), permitted_classes: [], aliases: false) || {}
rescue Errno::ENOENT
  abort "Configuration file not found: #{path}"
rescue Psych::SyntaxError => e
  abort "Invalid YAML in #{path}: #{e.message}"
end

def expand_path(path, base_dir:)
  raw_path = path.to_s
  return File.expand_path(raw_path) if raw_path.start_with?("~")
  return raw_path if Pathname.new(raw_path).absolute?

  File.expand_path(raw_path, base_dir)
end

def hidden_path?(path, root:)
  relative = Pathname.new(path).relative_path_from(Pathname.new(root))
  relative.each_filename.any? { |part| part.start_with?(".") }
end

def content_directory?(directory)
  patterns = %w[*readme*.org *canvas*.html]
  patterns.any? do |pattern|
    Dir.glob(File.join(directory, pattern)).any? { |path| File.file?(path) }
  end
end

def recursive_directories(root)
  abort "Target directory not found: #{root}" unless File.directory?(root)

  directories = []
  Find.find(root) do |path|
    if path != root && File.symlink?(path)
      Find.prune if File.directory?(path)
      next
    end

    if path != root && hidden_path?(path, root: root)
      Find.prune if File.directory?(path)
      next
    end

    directories << path if File.directory?(path) && content_directory?(path)
  end
  directories
end

def target_directories(path, base_dir:)
  raw_path = path.to_s

  if raw_path.end_with?("/**")
    root = expand_path(raw_path.delete_suffix("/**"), base_dir: base_dir)
    return recursive_directories(root)
  end

  expanded = expand_path(raw_path, base_dir: base_dir)
  if raw_path.match?(/[?*\[]/)
    directories = Dir.glob(expanded).select do |candidate|
      File.directory?(candidate) && !File.symlink?(candidate)
    end.sort
    abort "No target directories matched: #{raw_path}" if directories.empty?

    return directories
  end

  abort "Target directory not found: #{expanded}" unless File.directory?(expanded)

  [expanded]
end

def source_contents(source_dir)
  names = %w[
    .style.css
    .style_w_link_button.css
    .theme.css
  ]

  names.to_h do |name|
    path = File.join(source_dir, name)
    abort "Source style file not found: #{path}" unless File.file?(path)

    [name, File.binread(path)]
  end
end

def replace_once(contents, old_text, new_text, label:)
  unless contents.include?(old_text)
    abort "Expected import not found while generating #{label}: #{old_text}"
  end

  contents.sub(old_text, new_text)
end

def hidden_files(sources)
  sources
end

def docs_files(sources)
  {
    "style.css" => replace_once(
      sources.fetch(".style.css"),
      '@import url(".theme.css");',
      '@import url("./theme.css");',
      label: "style.css"
    ),
    "style_w_link_button.css" => replace_once(
      sources.fetch(".style_w_link_button.css"),
      '@import url("./.style.css");',
      '@import url("./style.css");',
      label: "style_w_link_button.css"
    ),
    "theme.css" => sources.fetch(".theme.css")
  }
end

def section_wrapper(sources)
  replace_once(
    sources.fetch(".style_w_link_button.css"),
    '@import url("./.style.css");',
    '@import url("../style.css");',
    label: "section style_w_link_button.css"
  )
end

def write_if_changed(path, contents, dry_run:)
  if File.file?(path) && File.binread(path) == contents
    puts "same    #{path}"
    return
  end

  puts "#{dry_run ? 'would update' : 'update'}  #{path}"
  return if dry_run

  FileUtils.mkdir_p(File.dirname(path))
  File.binwrite(path, contents)
end

config_path = options.fetch(:config)
config_dir = File.dirname(config_path)
config = read_config(config_path)
source_dir = expand_path(config.fetch("source_dir", "bin/templates"), base_dir: PROJECT_ROOT)
sources = source_contents(source_dir)
targets = config.fetch("targets")

abort "No targets configured in #{config_path}" unless targets.is_a?(Array) && !targets.empty?

targets.each do |target|
  layout = target.fetch("layout", "hidden")
  directories = target_directories(target.fetch("path"), base_dir: config_dir)

  directories.each do |target_dir|
    files = case layout
            when "hidden"
              hidden_files(sources)
            when "docs"
              docs_files(sources)
            else
              abort "Unknown layout #{layout.inspect} for #{target_dir}"
            end

    puts "\n[#{target_dir}]"
    files.each do |name, contents|
      write_if_changed(File.join(target_dir, name), contents, dry_run: options[:dry_run])
    end

    next unless layout == "docs"

    wrapper = section_wrapper(sources)
    Array(target["wrapper_dirs"]).each do |relative_dir|
      directory = File.expand_path(relative_dir, target_dir)
      abort "Wrapper directory not found: #{directory}" unless File.directory?(directory)

      write_if_changed(
        File.join(directory, "style_w_link_button.css"),
        wrapper,
        dry_run: options[:dry_run]
      )
    end
  end
end
