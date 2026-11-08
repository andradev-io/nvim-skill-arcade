return {
  {
    id = "line-end", title = "Last character", level = 1,
    brief = "Put the cursor on the very last character of the last line.",
    text = [[
first line
second line
the final line]],
    solution = "G$",
    expect = { at = { 3, "e", "last" } },
    why = "`G` goes to the last line, `$` to its end. Both work with counts: `3G`, `2$`.",
  },
  {
    id = "goto-line", title = "Go to line 17", level = 1,
    brief = "Put the cursor on line 17 (the line that says 'target').",
    text = (function()
      local t = {}
      for i = 1, 30 do
        t[#t + 1] = i == 17 and "line 17 target" or ("line " .. i)
      end
      return table.concat(t, "\n")
    end)(),
    solution = "17G",
    expect = { cursor = { 17 } },
    par_seconds = 8,
    why = "`{n}G` or `:{n}<CR>` jump straight to a line. `{n}j` works too when the line is near.",
  },
  {
    id = "word-jump", title = "Jump to a word", level = 1,
    brief = "Put the cursor on the 'l' of 'lazy'.",
    text = [[
the quick brown fox
jumps over the lazy dog
and runs far away]],
    solution = "/lazy<CR>",
    expect = { at = { 2, "lazy" } },
    helps = { jump = "label jump straight onto 'lazy' with two or three keys instead of searching" },
    plugin_par = 4,
    why = "`/lazy<CR>` or `fl` chains work, `*` on a word searches it. A jump plugin needs 3-4 keys.",
  },
  {
    id = "till-char", title = "Find a character", level = 2,
    brief = "Put the cursor on the '4' of 42.",
    text = [[config = {name = "alpha", id = 42, tag = "beta"}]],
    solution = "f4",
    expect = { at = { 1, "42" } },
    why = "`f{char}` jumps onto the next {char} on the line, `t{char}` stops before it, `;` repeats.",
  },
  {
    id = "match-bracket", title = "Matching bracket", level = 2,
    brief = "The cursor is on '(' after 'compute'. Move it to the matching ')' at the end.",
    text = [[local result = compute(alpha, beta(gamma), delta)]],
    cursor = { 1, 22 },
    solution = "%",
    expect = { at = { 1, ")", "last" } },
    why = "`%` jumps between matching pairs ((), [], {}) and treats nesting for you.",
  },
  {
    id = "paragraph", title = "Paragraph hop", level = 2,
    brief = "Put the cursor on 'epsilon', the first line of the last paragraph.",
    text = [[
alpha
beta

gamma
delta

epsilon
zeta]],
    solution = "}}j",
    expect = { cursor = { 7, 0 } },
    why = "`}` and `{` hop between blank-line separated blocks. `7G` or `/eps<CR>` also work.",
  },
}
