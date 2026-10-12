# -*- coding: utf-8 -*-
# frozen_string_literal: true

require "optparse"
require "pathname"
require "yaml"

require_relative "lib/latex_builder"
require_relative "lib/org_assembler"
require_relative "lib/publication_config"

PAPER_DIR = Pathname.new(__dir__).expand_path.freeze
PROJECT_ROOT = PAPER_DIR.parent.freeze

options = {
  structure: "dir_tree_full.yaml",
  output: "readme",
  format: "standard",
  assemble_only: false
}

# Backward compatibility with the former invocation:
# ruby auto_merge.rb -s dir_tree_full.yaml
if ARGV.delete("-s")
  options[:structure] = ARGV.shift || options[:structure]
else
  OptionParser.new do |parser|
    parser.banner = "Usage: ruby auto_merge.rb [options]"
    parser.on("--structure FILE", "YAML file describing the report structure") do |file|
      options[:structure] = file
    end
    parser.on("--output NAME", "Output basename (default: readme)") do |name|
      options[:output] = name
    end
    parser.on("--format NAME", %w[standard revtex], "LaTeX format") do |format|
      options[:format] = format
    end
    parser.on("--assemble-only", "Generate the assembled Org file only") do
      options[:assemble_only] = true
    end
  end.parse!
end

structure_path = Pathname.new(options[:structure]).expand_path(PAPER_DIR)
output_base = Pathname.new(options[:output]).basename.to_s
output_org = PAPER_DIR.join("#{output_base}.org")

structure = YAML.load_file(structure_path)
publication = PublicationConfig.load(PROJECT_ROOT.join(".hc_config.yaml"))

assembler = OrgAssembler.new(
  project_root: PROJECT_ROOT,
  output_dir: PAPER_DIR,
  public_base_url: publication.public_base_url
)
assembler.assemble(
  structure: structure,
  structure_dir: structure_path.dirname,
  output_path: output_org
)

puts "assembled #{output_org}"
exit if options[:assemble_only]

builder = LatexBuilder.new(work_dir: PAPER_DIR)
pdf_path = builder.build(
  basename: output_base,
  header: structure.fetch(:header, {}),
  format: options[:format]
)
puts "built #{pdf_path}"
