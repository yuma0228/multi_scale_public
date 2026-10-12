# frozen_string_literal: true

require "pathname"

class LatexBuilder
  def initialize(work_dir:)
    @work_dir = Pathname.new(work_dir).expand_path
  end

  def build(basename:, header:, format: "standard")
    export_latex(basename)
    resize_table_images(@work_dir.join("#{basename}.tex"))

    latex_basename = case format
                     when "standard"
                       configure_standard_document(basename, header)
                       basename
                     when "revtex"
                       configure_revtex_document(basename)
                       "#{basename}2"
                     else
                       raise ArgumentError, "unknown LaTeX format: #{format}"
                     end

    run("platex", "#{latex_basename}.tex")
    run("platex", "#{latex_basename}.tex")
    run("dvipdfmx", latex_basename)

    @work_dir.join("#{latex_basename}.pdf")
  end

  private

  def export_latex(basename)
    run(
      "emacs",
      "#{basename}.org",
      "--batch",
      "--eval",
      "(setq org-latex-images-centered nil)",
      "-f",
      "org-latex-export-to-latex",
      "--kill"
    )
  end

  def configure_standard_document(basename, header)
    path = @work_dir.join("#{basename}.tex")
    contents = path.read
    title = header[:title]
    author = header[:author]

    contents.sub!(/\\title\{.+\}/, "\\title{#{title}}") if title
    contents.sub!(/pdftitle=\{.+\}/, "pdftitle={#{title}}") if title
    contents.sub!(/\\author\{.+\}/, "\\author{#{author}}") if author
    contents.sub!(/pdfauthor=\{.+\}/, "pdfauthor={#{author}}") if author
    contents.sub!("\\documentclass[11pt]{article}", "\\documentclass[dvipdfmx, a4paper, 12pt]{jsarticle}")
    contents.sub!("\\usepackage{graphicx}", "\\usepackage[dvipdfmx]{graphicx}")
    contents.sub!("\\usepackage{hyperref}", "\\usepackage[dvipdfmx]{hyperref}")

    path.write(contents)
  end

  def configure_revtex_document(basename)
    header_path = @work_dir.join("revtex4-2-head.tex")
    raise "missing #{header_path}" unless header_path.file?

    source_path = @work_dir.join("#{basename}.tex")
    destination_path = @work_dir.join("#{basename}2.tex")
    lines = source_path.readlines
    main = lines[30..].join
    main.sub!("\\documentclass[11pt]{article}", "\\documentclass[dvipdfmx, a4paper, 12pt]{jsarticle}")
    main.sub!("\\usepackage{graphicx}", "\\usepackage[dvipdfmx]{graphicx}")
    main.sub!("\\usepackage{hyperref}", "\\usepackage[dvipdfmx]{hyperref}")
    destination_path.write(header_path.read + main)
  end

  def resize_table_images(tex_file)
    contents = tex_file.read
    resized = contents.gsub(/\\begin\{tabular\}\{([^}]*)\}.*?\\end\{tabular\}/m) do |table|
      column_spec = Regexp.last_match(1)
      column_count = column_spec.scan(/[lcr]/).length
      next table if column_count < 1 || !table.include?("\\includegraphics")
      next table unless column_spec.match?(/\A[lcr]+\z/)

      column_width = format("%.3g", 0.88 / column_count)
      paragraph_columns = Array.new(column_count, "p{#{column_width}\\linewidth}").join
      table = table.sub(
        "\\begin{tabular}{#{column_spec}}",
        "\\begin{tabular}{#{paragraph_columns}}"
      )
      table.gsub(/(\\includegraphics\[[^\]]*?\bwidth=)[^,\]]+/) do
        "#{Regexp.last_match(1)}\\linewidth"
      end
    end
    tex_file.write(resized) if resized != contents
  end

  def run(*command)
    puts command.join(" ")
    success = Dir.chdir(@work_dir) { system(*command) }
    raise "command failed: #{command.join(' ')}" unless success
  end
end
