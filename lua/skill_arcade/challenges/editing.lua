return {
  {
    id = "swap-lines", title = "Swap two lines", level = 1,
    brief = "Swap the first two lines.",
    text = "banana\napple\ncherry",
    solution = "ddp",
    expect = { text = "apple\nbanana\ncherry" },
    why = "`ddp` swaps a line with the one below; `:m+1` / `:m-2` move lines; mini.move does it with <M-j>/<M-k>.",
    helps = { move = "move lines with a single chord instead of ddp" },
  },
  {
    id = "join-lines", title = "Join lines", level = 1,
    brief = "Join the three lines into one line: const total = price + tax;",
    text = "const total =\n  price +\n  tax;",
    solution = "3J",
    expect = { text = "const total = price + tax;" },
    why = "`J` joins with one space; `3J` joins three lines; `gJ` joins without touching spaces.",
  },
  {
    id = "upper-word", title = "Shout one word", level = 2,
    brief = "Make only the word 'this' uppercase.",
    text = "make this loud",
    solution = "wgUiw",
    expect = { text = "make THIS loud" },
    why = "`gUiw` upper-cases a word, `guiw` lower-cases, `g~iw` toggles. `~` flips a single character.",
  },
  {
    id = "increment", title = "Bump a number", level = 2,
    brief = "Change retries = 3 into retries = 8.",
    text = "retries = 3",
    solution = "5<C-a>",
    expect = { text = "retries = 8" },
    why = "`<C-a>` / `<C-x>` add/subtract (with a count) to the next number on the line. `g<C-a>` in visual mode numbers a column.",
  },
  {
    id = "block-append", title = "Semicolons everywhere", level = 3,
    brief = "Add a ';' at the end of all five lines.",
    text = "let a = 1\nlet b = 2\nlet c = 3\nlet d = 4\nlet e = 5",
    solution = "<C-v>G$A;<Esc>",
    expect = { text = "let a = 1;\nlet b = 2;\nlet c = 3;\nlet d = 4;\nlet e = 5;" },
    helps = { multicursor = "a multicursor plugin can add a cursor per line and type once" },
    why = "`<C-v>G$A;<Esc>` appends at every line end. `A;<Esc>j.` repeated also works; `:%norm A;` too.",
  },
  {
    id = "block-comment", title = "Comment three lines", level = 3,
    brief = "Prefix lines 2 to 4 with '-- ' (Lua comment). Line 1 stays untouched.",
    text = "local a = 1\nlocal b = 2\nlocal c = 3\nlocal d = 4",
    ft = "lua",
    cursor = { 2, 0 },
    solution = "<C-v>jjI-- <Esc>",
    expect = { text = "local a = 1\n-- local b = 2\n-- local c = 3\n-- local d = 4" },
    helps = { comment = "`3gcc` (gc operator) or your comment plugin toggles comments in 4 keys" },
    plugin_par = 4,
    why = "Neovim 0.10+ has `gc{motion}` and `gcc` built in; `3gcc` comments three lines. A visual block works anywhere.",
  },
  {
    id = "indent", title = "Indent a block", level = 2,
    brief = "Indent lines 2 to 4 one level. Lines 1 and 5 stay at the left edge.",
    text = "function f()\nx = 1\ny = 2\nz = 3\nend",
    cursor = { 2, 0 },
    solution = "3>>",
    check = function(c)
      local l = c.lines
      local function indented(s) return s:match("^%s+%S") ~= nil end
      return l[1] == "function f()" and l[5] == "end"
        and indented(l[2]) and indented(l[3]) and indented(l[4])
        and vim.trim(l[2]) == "x = 1" and vim.trim(l[4]) == "z = 3"
    end,
    why = "`3>>` indents three lines by 'shiftwidth'; `>ip` a paragraph; `=` re-indents by the filetype's rules.",
  },
  {
    id = "move-last", title = "Last line goes first", level = 2,
    brief = "Move the last line to the top of the buffer.",
    text = "b\nc\nd\na",
    solution = ":$m0<CR>",
    expect = { text = "a\nb\nc\nd" },
    why = "`:m` moves lines: `:$m0` last to top, `:m+1` one down, `:5,7m0` a range. `ddggP` also works.",
  },
}
