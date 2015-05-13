#! env ruby

TOC_LINK_REGEX = /(?<indent>\s*?)\* \[(?<title>.+?)\]\((?<filename>.+?)\)/

HIDDEN_CODE = Regexp.new("^# ")
RUST_CODE_START = Regexp.new("^```(.*)rust(.*)")
CODE_BLOCK_END = Regexp.new("^```")

MARKDOWN_OPTIONS = "markdown+grid_tables+pipe_tables+raw_html+implicit_figures+footnotes+intraword_underscores+auto_identifiers"

def normalizeCodeSnipetts(input)
    in_code_block = false

    input
    .lines.reduce "" do |initial, line|
        if in_code_block and line.match(HIDDEN_CODE)
            # skip line
            initial
        elsif line.match(RUST_CODE_START)
            in_code_block = true
            # normalize code block start
            initial + "```rust\n"
        elsif line.match(CODE_BLOCK_END)
            in_code_block = false
            initial + "```\n"
        else
            initial + line
        end
    end
end

def normalize_title(title)
    # Some chapter titles start with Roman numerals, e.g. "I: The Basics"
    title.sub /(([IV]+):\s)/, ''
end

def pandoc(file, header_level=3)
    normalizeTables = 'sed -E \'s/^\+-([+-]+)-\+$/| \1 |/\''

    normalizeCodeSnipetts `cat #{file} | #{normalizeTables} | pandoc --from=#{MARKDOWN_OPTIONS} --to markdown_github --base-header-level=#{header_level} --indented-code-classes=rust --atx-headers`
end

RELEASE_DATE = Time.new().strftime("%Y-%m-%d")

book = <<-eos
---
title: "The Rust Programming Language"
author: "The Rust Team"
date: #{RELEASE_DATE}
description: "This book will teach you about the Rust Programming Language. Rust is a modern systems programming language focusing on safety and speed. It accomplishes these goals by being memory safe without using garbage collection."
language: en
documentclass: book
links-as-notes: true
verbatim-in-note: true
toc-depth: 2
...

eos

book << "# Introduction\n\n"
book << pandoc("src/README.md", 1)
book << "\n\n"

File.open("src/SUMMARY.md", "r").each_line do |line|
    link = TOC_LINK_REGEX.match(line)
    if link
        level = link[:indent].length == 0 ? "#" : "##"
        book << "#{level} #{normalize_title link[:title]}\n\n"
        book << pandoc("src/#{link[:filename]}")
        book << "\n\n"
    end
end

File.open("dist/trpl-#{RELEASE_DATE}.md", "w") { |file|
    file.write(book)
    puts "[x] Markdown"
}

`pandoc dist/trpl-#{RELEASE_DATE}.md --from=#{MARKDOWN_OPTIONS} --smart --normalize --standalone --self-contained --highlight-style=tango --table-of-contents --template=lib/template.html --css=lib/pandoc.css --to=html5 --output=dist/trpl-#{RELEASE_DATE}.html`
puts "[x] HTML"

`pandoc dist/trpl-#{RELEASE_DATE}.md --from=#{MARKDOWN_OPTIONS} --smart --normalize --standalone --self-contained --highlight-style=tango --table-of-contents --output=dist/trpl-#{RELEASE_DATE}.epub`
puts "[x] EPUB"

`pandoc dist/trpl-#{RELEASE_DATE}.md --from=#{MARKDOWN_OPTIONS} --smart --normalize --standalone --self-contained --highlight-style=tango --chapters --table-of-contents --variable papersize='a4paper' --template=lib/template.tex --latex-engine=xelatex --to=latex --output=dist/trpl-#{RELEASE_DATE}-a4.pdf`
puts "[x] PDF (A4)"

`pandoc dist/trpl-#{RELEASE_DATE}.md --from=#{MARKDOWN_OPTIONS} --smart --normalize --standalone --self-contained --highlight-style=tango --chapters --table-of-contents --variable papersize='letterpaper' --template=lib/template.tex --latex-engine=xelatex --to=latex --output=dist/trpl-#{RELEASE_DATE}-letter.pdf`
puts "[x] PDF (Letter)"