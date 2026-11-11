-- Offered only when the matching plugin group is installed in YOUR setup (see env.lua).
-- Every challenge stays solvable natively; the plugin just makes it cheaper (plugin_par).
return {
  {
    id = "surround-word", title = "Wrap in quotes", level = 2, needs = "surround",
    brief = 'Wrap hello in double quotes:  print(hello)  ->  print("hello")',
    text = "print(hello)",
    cursor = { 1, 8 },
    solution = 'ciw"<C-r>-"<Esc>',
    plugin_par = 4,
    expect = { text = 'print("hello")' },
    helps = { surround = "one surround command does it, e.g. ysiw\" (nvim-surround) or saiw\" (mini.surround)" },
    why = "Native: change the word to a quote, paste the deleted text from register `-`, close the quote. A surround plugin: 4 keys.",
  },
  {
    id = "jump-far", title = "Long-distance jump", level = 2, needs = "jump",
    brief = "Put the cursor on the word 'target' (far down the buffer).",
    lines = (function()
      local t = {}
      for i = 1, 40 do
        t[i] = i == 33 and "the quiet target hides here" or ("filler line number " .. i)
      end
      return t
    end)(),
    solution = "/target<CR>",
    expect = { at = { 33, "target" } },
    plugin_par = 4,
    helps = { jump = "type the first two letters of the word, then the label it shows" },
    why = "`/target<CR>` works; a jump plugin turns it into `s` + 2 letters + a label (4 keys, no search history noise).",
  },
  {
    id = "second-argument", title = "Drop the 2nd argument", level = 3, needs = "textobjects",
    brief = "Remove the second argument:  call(a, b, c)  ->  call(a, c)",
    text = "call(a, b, c)",
    cursor = { 1, 8 },
    solution = "df,x",
    plugin_par = 3,
    expect = { text = "call(a, c)" },
    helps = { textobjects = "an argument text object (`daa` / `dia`) deletes it with its separator" },
    why = "Native: `df,` then fix the leftover space. With an argument text object: `daa`.",
  },
  {
    id = "comment-line", title = "Comment out a line", level = 1, needs = "comment",
    brief = "Comment out line 2 (Lua comment, '-- ' in front). The other lines stay as they are.",
    text = "local a = 1\nlocal b = 2\nlocal c = 3",
    ft = "lua",
    cursor = { 2, 0 },
    solution = "I-- <Esc>",
    plugin_par = 3,
    expect = { text = "local a = 1\n-- local b = 2\nlocal c = 3" },
    helps = { comment = "`gcc` (built in since 0.10, or your comment plugin) toggles the line in 3 keys" },
    why = "Native: `I-- <Esc>`. With `gcc` it is 3 keys and works for any filetype: it knows the comment string.",
  },
  {
    id = "jump-word-end", title = "Hop to the last word", level = 2, needs = "jump",
    brief = "Put the cursor on the 'o' of 'omega', the last word of the line.",
    text = "alpha beta gamma delta omega",
    solution = "$b",
    plugin_par = 4,
    expect = { cursor = { 1, 23 } },
    helps = { jump = "type two letters of 'omega', then the label that appears on it" },
    why = "`$b` (end of line, back one word) or `fo` chains work. A jump plugin: `s` + `om` + label.",
  },
  {
    id = "surround-swap", title = "Swap the quote style", level = 2, needs = "surround",
    brief = [[Change the double quotes into single quotes:  msg = "hello"  ->  msg = 'hello']],
    text = [[msg = "hello"]],
    solution = [[f"r'$r']],
    plugin_par = 3,
    expect = { text = "msg = 'hello'" },
    helps = { surround = [[`cs"'` (nvim-surround / vim-surround) or `sr"'` (mini.surround) swaps both quotes at once]] },
    why = [[Native: `f"r'$r'` replaces each quote by hand. A surround plugin changes the pair in 3 keys.]],
  },
  {
    id = "change-arg", title = "Change one argument", level = 3, needs = "textobjects",
    brief = "Replace the second argument 'beta' with: x",
    text = "fn(alpha, beta, gamma)",
    solution = "fbcwx<Esc>",
    plugin_par = 6,
    expect = { text = "fn(alpha, x, gamma)" },
    helps = { textobjects = "an argument object: put the cursor on the argument, `cia` + the new text" },
    why = "Native: find the argument and `cw`. With an argument text object `cia` works from anywhere inside it and with any length.",
  },
}
