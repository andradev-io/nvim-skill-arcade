return {
  {
    id = "change-quotes", title = "Change inside quotes", level = 1,
    brief = 'Replace the text inside the quotes with: new',
    text = [[name = "old value here"]],
    cursor = { 1, 12 },
    solution = 'ci"new<Esc>',
    expect = { text = [[name = "new"]] },
    helps = { textobjects = "`q` (any quote) and `a` (argument) text objects save you from picking the delimiter" },
    why = '`ci"` = change inside quotes from anywhere on the line. `ca"` also takes the quotes.',
  },
  {
    id = "delete-parens", title = "Empty the call", level = 1,
    brief = "Remove everything between the parentheses, keep the parentheses.",
    text = [[call(first, second, third)]],
    cursor = { 1, 8 },
    solution = "di(",
    expect = { text = [[call()]] },
    why = "`di(` (or `dib`) deletes inside the nearest parentheses. `da(` removes the parens too.",
  },
  {
    id = "around-word", title = "Delete a word and its space", level = 2,
    brief = "Delete the word 'very' (the result must keep a single space).",
    text = [[The very quick brown fox]],
    cursor = { 1, 6 },
    solution = "daw",
    expect = { text = [[The quick brown fox]] },
    why = "`daw` deletes a word plus one surrounding space; `diw` leaves the space behind.",
  },
  {
    id = "delete-paragraph", title = "Drop a paragraph", level = 2,
    brief = "Delete the middle paragraph (the 'remove me' lines) including its blank line.",
    text = [[
keep this one
and this

remove me
remove me too

keep the last]],
    cursor = { 4, 0 },
    solution = "dap",
    expect = { text = "keep this one\nand this\n\nkeep the last" },
    why = "`dap` deletes a paragraph and its trailing blank line; `dip` keeps the blank line.",
  },
  {
    id = "change-tag", title = "Change tag content", level = 3,
    brief = "Replace the text inside <span> with: new",
    text = [[<div class="box"><span>old text</span></div>]],
    cursor = { 1, 25 },
    solution = "citnew<Esc>",
    expect = { text = [[<div class="box"><span>new</span></div>]] },
    helps = { treesitter = "treesitter incremental selection / textobjects grow the selection by syntax node" },
    why = "`cit` changes the content of the innermost tag, `cat` the tag itself.",
  },
  {
    id = "inner-block", title = "Replace a block body", level = 3,
    brief = "Replace the whole body of the braces with a single line: done()",
    text = [[
if ready {
  step_one()
  step_two()
}]],
    cursor = { 2, 4 },
    loose = true,
    solution = "ci{done()<Esc>",
    expect = { text = "if ready {\ndone()\n}" },
    why = "`ci{` (or `ciB`) works across lines. Indentation after it depends on your 'autoindent' settings.",
  },
}
