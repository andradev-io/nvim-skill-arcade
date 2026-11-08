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
}
