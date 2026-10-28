#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'find'
require 'json'
require 'optparse'
require 'pathname'
require 'set'
require 'time'

# Finds local paths referenced by light_table.yaml and canvas.html, then suggests
# replacements for paths that moved.  It only rewrites path-valued fields; the
# surrounding YAML/HTML formatting is kept intact.
class LinkRepair
  Reference = Struct.new(:source, :field, :value, :line, keyword_init: true)
  Suggestion = Struct.new(:old_path, :new_path, :reason, :automatic, keyword_init: true)

  YAML_REFERENCE = /^(\s*(?:-\s*)?:(href|src):\s*)(.*?)(\s*(?:#.*)?)$/
  CANVAS_REFERENCE = /^(\s*"(file_path|icon_path)"\s*:\s*)"((?:\\.|[^"])*)"/
  SKIP_DIRECTORIES = %w[.git .svn node_modules vendor].freeze

  def initialize(root:, yaml_path:, canvas_path:, explicit_maps: {})
    @root = Pathname.new(root).expand_path
    @yaml_path = absolute_path(yaml_path)
    @canvas_path = absolute_path(canvas_path)
    @explicit_maps = explicit_maps
    @references = []
  end

  def run(apply:, backup:)
    read_references
    missing = @references.reject { |ref| target_exists?(ref.value) }
    grouped = missing.group_by(&:value)
    suggestions = grouped.keys.sort.map { |path| suggest(path) }

    print_report(grouped, suggestions)
    replacements = suggestions.select { |item| item.new_path && item.automatic }
                              .to_h { |item| [item.old_path, item.new_path] }

    if apply && !replacements.empty?
      rewrite(@yaml_path, replacements, :yaml, backup)
      rewrite(@canvas_path, replacements, :canvas, backup)
      puts "\n#{replacements.length} path(s) repaired."
    elsif apply
      puts "\nNo automatically repairable paths found."
    else
      puts "\nDry run: no files changed. Add --apply to repair automatic matches."
    end

    unresolved = suggestions.count { |item| !item.automatic }
    puts "Unresolved: #{unresolved} path(s)." if unresolved.positive?
    unresolved.zero? ? 0 : 1
  end

  private

  def absolute_path(path)
    candidate = Pathname.new(path)
    candidate.absolute? ? candidate : @root.join(candidate)
  end

  def read_references
    [@yaml_path, @canvas_path].each do |path|
      raise "File not found: #{path}" unless path.file?
    end

    File.foreach(@yaml_path).with_index(1) do |line, line_number|
      match = YAML_REFERENCE.match(line.chomp)
      next unless match

      value = unquote_yaml(match[3].strip)
      add_reference(@yaml_path, match[2], value, line_number)
    end

    File.foreach(@canvas_path).with_index(1) do |line, line_number|
      match = CANVAS_REFERENCE.match(line)
      next unless match

      value = JSON.parse(%("#{match[3]}"))
      add_reference(@canvas_path, match[2], value, line_number)
    end
  end

  def add_reference(source, field, value, line)
    return if value.empty? || external_reference?(value)

    @references << Reference.new(source: source, field: field, value: value, line: line)
  end

  def unquote_yaml(value)
    if value.length >= 2 && value.start_with?('"') && value.end_with?('"')
      JSON.parse(value)
    elsif value.length >= 2 && value.start_with?("'") && value.end_with?("'")
      value[1..-2].gsub("''", "'")
    else
      value
    end
  rescue JSON::ParserError
    value
  end

  def external_reference?(value)
    value.start_with?('#', '//') || value.match?(/\A(?:https?|mailto|data|javascript):/i)
  end

  def path_part(value)
    value.split(/[?#]/, 2).first
  end

  def target_exists?(value)
    @root.join(path_part(value)).exist?
  end

  def files
    @files ||= begin
      result = []
      Find.find(@root.to_s) do |path|
        relative = Pathname.new(path).relative_path_from(@root).to_s
        if File.directory?(path) && SKIP_DIRECTORIES.include?(File.basename(path))
          Find.prune
        elsif File.file?(path) || File.symlink?(path)
          result << relative
        end
      end
      result
    end
  end

  def suggest(old_path)
    explicit = @explicit_maps[old_path]
    if explicit
      raise "Mapped target does not exist: #{explicit}" unless target_exists?(explicit)
      return Suggestion.new(old_path: old_path, new_path: explicit,
                            reason: 'explicit --map', automatic: true)
    end

    old = path_part(old_path)
    suffix = old_path.delete_prefix(old)
    basename = File.basename(old)
    top = old.split('/').first
    candidates = files.select { |path| File.extname(path) == File.extname(old) }

    exact = candidates.select { |path| File.basename(path) == basename }
    exact_same_top = exact.select do |path|
      path.split('/').first == top && !stack_path?(path)
    end
    choice = unique_choice(exact_same_top, old)
    if choice
      return Suggestion.new(old_path: old_path, new_path: choice + suffix,
                            reason: 'same filename', automatic: true)
    end

    ordinal = basename[/\.\d+\.[^.]+\z/]
    if ordinal
      ordinal_matches = candidates.select do |path|
        path.split('/').first == top && !stack_path?(path) &&
          File.basename(path).end_with?(ordinal)
      end
      if ordinal_matches.one?
        return Suggestion.new(old_path: old_path, new_path: ordinal_matches.first + suffix,
                              reason: "same section and image number #{ordinal}", automatic: true)
      end
    end

    ranked = candidates.map { |path| [candidate_score(old, path), path] }
                       .sort_by { |score, path| [-score, path] }
    safe_ranked = ranked.reject { |_score, path| stack_path?(path) }
    best = safe_ranked[0]
    second = safe_ranked[1]
    generic_readme = basename.match?(/\A(?:readme|index)\.html?\z/i)
    if !generic_readme && best && best[0] >= 150 &&
       (!second || best[0] - second[0] >= 40)
      Suggestion.new(old_path: old_path, new_path: best[1] + suffix,
                     reason: "similar path (score #{best[0]})", automatic: true)
    else
      previews = ranked.first(3).select { |score, _path| score.positive? }
                       .map { |score, path| "#{path} [#{score}]" }
      Suggestion.new(old_path: old_path,
                     new_path: previews.empty? ? nil : previews.join(' | '),
                     reason: 'ambiguous; use --map OLD=NEW', automatic: false)
    end
  end

  def unique_choice(preferred, old)
    if preferred.one?
      candidate = preferred.first
      generic_readme = File.basename(old).match?(/\A(?:readme|index)\.html?\z/i)
      same_depth = old.count('/') == candidate.count('/')
      return candidate unless generic_readme && !same_depth
    end

    # A path that merely moved as one intact trailing subtree is also safe.
    trailing = old.split('/').last(2).join('/')
    matches = preferred.select { |path| path.end_with?(trailing) }
    matches.one? ? matches.first : nil
  end

  def stack_path?(path)
    path.split('/').any? { |part| part.start_with?('_stack') }
  end

  def candidate_score(old, candidate)
    old_parts = old.split('/')
    new_parts = candidate.split('/')
    score = 0
    score += 70 if old_parts.first == new_parts.first
    score += 120 if File.basename(old) == File.basename(candidate)
    score += 20 if File.extname(old) == File.extname(candidate)
    score += common_prefix_length(old_parts, new_parts) * 15
    score += common_suffix_length(old_parts, new_parts) * 25
    score -= 45 if new_parts.any? { |part| part.start_with?('_stack') }
    score
  end

  def common_prefix_length(a, b)
    a.zip(b).take_while { |left, right| left == right }.length
  end

  def common_suffix_length(a, b)
    common_prefix_length(a.reverse, b.reverse)
  end

  def print_report(grouped, suggestions)
    total = @references.length
    missing_count = grouped.values.sum(&:length)
    puts "Checked: #{total} reference(s) in #{@yaml_path.basename} and #{@canvas_path.basename}"
    puts "OK: #{total - missing_count}; broken occurrences: #{missing_count}; unique broken paths: #{grouped.length}"
    return if grouped.empty?

    puts
    suggestions.each do |item|
      locations = grouped.fetch(item.old_path).map do |ref|
        "#{ref.source.basename}:#{ref.line} (#{ref.field})"
      end.join(', ')
      marker = item.automatic ? 'AUTO' : 'REVIEW'
      puts "[#{marker}] #{item.old_path}"
      puts "         -> #{item.new_path || '(no candidate)'}"
      puts "         #{item.reason}; #{locations}"
    end
  end

  def rewrite(path, replacements, format, backup)
    original = File.binread(path)
    changed = if format == :yaml
                rewrite_yaml(original, replacements)
              else
                rewrite_canvas(original, replacements)
              end
    return if changed == original

    if backup
      timestamp = Time.now.strftime('%Y%m%d-%H%M%S')
      FileUtils.cp(path, "#{path}.bak-#{timestamp}")
    end
    temporary = Pathname.new("#{path}.tmp-#{Process.pid}")
    File.binwrite(temporary, changed)
    FileUtils.mv(temporary, path)
    puts "Updated: #{path}"
  ensure
    FileUtils.rm_f(temporary) if defined?(temporary) && temporary
  end

  def rewrite_yaml(content, replacements)
    content.each_line.map do |line|
      match = YAML_REFERENCE.match(line.chomp)
      unless match
        next line
      end
      raw = match[3].strip
      old = unquote_yaml(raw)
      replacement = replacements[old]
      unless replacement
        next line
      end
      quote = raw.start_with?('"') ? '"' : (raw.start_with?("'") ? "'" : '')
      value = if quote == '"'
                replacement.to_json
              elsif quote == "'"
                "'#{replacement.gsub("'", "''")}'"
              else
                replacement
              end
      newline = line.end_with?("\n") ? "\n" : ''
      "#{match[1]}#{value}#{match[4]}#{newline}"
    end.join
  end

  def rewrite_canvas(content, replacements)
    content.each_line.map do |line|
      match = CANVAS_REFERENCE.match(line)
      unless match
        next line
      end
      old = JSON.parse(%("#{match[3]}"))
      replacement = replacements[old]
      replacement ? line.sub(match[0], "#{match[1]}#{replacement.to_json}") : line
    end.join
  end
end

options = {
  root: Dir.pwd,
  yaml: 'light_table.yaml',
  canvas: 'canvas.html',
  apply: false,
  backup: true,
  maps: {}
}

parser = OptionParser.new do |opts|
  opts.banner = 'Usage: ruby repair_light_table_links.rb [options]'
  opts.separator ''
  opts.separator 'Broken links are reported by default; files change only with --apply.'
  opts.on('--apply', 'Apply unambiguous repairs') { options[:apply] = true }
  opts.on('--map OLD=NEW', 'Add an explicit repair (repeatable)') do |mapping|
    old_path, new_path = mapping.split('=', 2)
    raise OptionParser::InvalidArgument, 'expected OLD=NEW' unless old_path && new_path
    options[:maps][old_path] = new_path
  end
  opts.on('--root DIR', 'Root directory containing referenced paths') { |value| options[:root] = value }
  opts.on('--yaml FILE', 'YAML file (default: light_table.yaml)') { |value| options[:yaml] = value }
  opts.on('--canvas FILE', 'Canvas HTML file (default: canvas.html)') { |value| options[:canvas] = value }
  opts.on('--[no-]backup', 'Create timestamped backups when applying (default: yes)') { |value| options[:backup] = value }
  opts.on('-h', '--help', 'Show this help') do
    puts opts
    exit 0
  end
end

begin
  parser.parse!
  exit LinkRepair.new(root: options[:root], yaml_path: options[:yaml],
                      canvas_path: options[:canvas], explicit_maps: options[:maps])
                 .run(apply: options[:apply], backup: options[:backup])
rescue OptionParser::ParseError, RuntimeError => e
  warn "Error: #{e.message}"
  warn parser
  exit 2
end
