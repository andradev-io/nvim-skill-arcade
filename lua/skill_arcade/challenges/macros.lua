return {
  {
    id = "quote-list", title = "Quote the list", level = 3,
    brief = 'Turn every word into a quoted, comma-ended line:  alpha  ->  "alpha",',
    text = "alpha\nbeta\ngamma\ndelta",
    solution = [[qqI"<Esc>A",<Esc>jq3@q]],
    expect = { text = '"alpha",\n"beta",\n"gamma",\n"delta",' },
    why = "Record on line 1 and finish with `j` so the macro lands on the next line; then `3@q`. `:%s/.*/\"&\",/` or `:%norm` are alternatives.",
  },
  {
    id = "number-list", title = "Count up", level = 4,
    brief = "Make five lines id_1 ... id_5 starting from the single line you have.",
    text = "id_1",
    solution = "qqyyp<C-a>q3@q",
    expect = { text = "id_1\nid_2\nid_3\nid_4\nid_5" },
    why = "`yyp<C-a>` duplicates and increments; recorded once, `3@q` does the rest. Visual `g<C-a>` can also number a column.",
  },
}
