return {
  {
    id = "yank-survives", title = "Yank, delete, paste", level = 2,
    brief = "Copy the number 42, delete the junk line, then fill in 'copy = 42' on the last line.",
    lines = { "value = 42", "# junk comment", "copy = " },
    solution = '$yiwjdd$"0p',
    expect = { text = "value = 42\ncopy = 42" },
    why = '`"0` always holds the last yank, even after a delete overwrote `""`. Or: `"_dd` deletes without touching registers.',
  },
  {
    id = "named-append", title = "Collect into a register", level = 3,
    brief = "Collect 'one' (line 1) and 'four' (line 4) with one register and paste both under the marker line.",
    text = "one\ntwo\nthree\nfour\n-- paste below --",
    solution = '"ayy4G"AyyG"ap',
    expect = { text = "one\ntwo\nthree\nfour\n-- paste below --\none\nfour" },
    why = '`"ayy` stores, `"Ayy` (capital) APPENDS to register a, `"ap` pastes the collection.',
  },
  {
    id = "black-hole", title = "Delete without a trace", level = 3,
    brief = "Delete the 'trash' line without losing the yanked 'keep me', then paste 'keep me' at the very end.",
    text = "keep me\ntrash\nend",
    solution = 'yyj"_ddGp',
    expect = { text = "keep me\nend\nkeep me" },
    why = '`"_` is the black-hole register: `"_dd` deletes without overwriting what you yanked.',
  },
}
