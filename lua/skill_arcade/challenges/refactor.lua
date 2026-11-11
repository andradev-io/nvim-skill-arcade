-- Refactor sprints: small code changes (10-40 s), judged by the END STATE only: the buffer must equal the refactored
-- code. Where the language is Lua the result is also run, so the behaviour must survive the refactor.
-- Languages: lua, typescript, go, cs (C#), python, javascript. `:ArcadeSetup` -> `refactor_languages` limits them.
local function lua_returns(want)
  return function(c)
    local f = load(table.concat(c.lines, "\n"))
    if not f then
      return false
    end
    local ok, v = pcall(f)
    return ok and v == want
  end
end

return {
  -- level 1 ---------------------------------------------------------------
  {
    id = "join-table", title = "Join the table onto one line", level = 1, ft = "lua",
    brief = "Refactor: write the table constructor on a single line. The last line stays as it is.",
    lines = { "local t = {", "  1,", "  2,", "  3,", "}", "return #t" },
    solution = "5J",
    expect = { text = "local t = { 1, 2, 3, }\nreturn #t" },
    check = lua_returns(3),
    why = "`{n}J` joins n lines into one (blank-trimmed). `gJ` joins without adding spaces; `gq` / `:normal` do the opposite.",
  },
  {
    id = "rename-local", title = "Rename a variable everywhere", level = 1, ft = "lua",
    brief = "Rename the local `count` to `total` in every place it is used.",
    lines = { "local count = 0", "count = count + 1", "count = count + 1", "return count" },
    solution = [[:%s/\<count\>/total/g<CR>]],
    expect = { text = "local total = 0\ntotal = total + 1\ntotal = total + 1\nreturn total" },
    check = lua_returns(2),
    why = [[`:%s/\<old\>/new/g`: the `\<` `\>` word anchors keep it from touching `counter`. An LSP rename does the same by meaning, not by text.]],
  },
  {
    id = "add-parameter", title = "Add a parameter", level = 1, ft = "cs",
    brief = "Add a third parameter `int c` to the method signature.",
    text = "public int Add(int a, int b)",
    solution = "f)i, int c<Esc>",
    expect = { text = "public int Add(int a, int b, int c)" },
    why = "`f)` lands on the closing parenthesis and `i` inserts before it. `$i` works when the `)` is the last character.",
  },
  {
    id = "reorder-fields", title = "Move a field up", level = 1, ft = "go",
    brief = "Move the `Email` field to the top of the struct.",
    lines = { "type User struct {", "\tName  string", "\tAge   int", "\tEmail string", "}" },
    solution = ":4m1<CR>",
    loose = true,
    expect = { text = "type User struct {\n\tEmail string\n\tName  string\n\tAge   int\n}" },
    why = "`:{n}m{target}` moves a line below `target` (`:4m1` = line 4 goes under line 1). `ddkP` / `ddggp` do it with the cursor.",
  },
  -- level 2 ---------------------------------------------------------------
  {
    id = "rename-interface", title = "Rename a type, not its cousins", level = 2, ft = "typescript",
    brief = "Rename the type `User` to `Account` everywhere. `UserName` is a different type: leave it alone.",
    lines = { "interface User { name: UserName }", "function show(u: User): User { return u }" },
    solution = [[:%s/\<User\>/Account/g<CR>]],
    expect = { text = "interface Account { name: UserName }\nfunction show(u: Account): Account { return u }" },
    why = [[A plain `:%s/User/Account/` would also hit `UserName`. The `\<` `\>` anchors match whole words only.]],
  },
  {
    id = "change-signature", title = "Group the parameter types", level = 2, ft = "go",
    brief = "Go allows `x, y int`. Group the two parameters that share a type.",
    text = "func scale(x int, y int) int {",
    solution = "f(ll4x",
    expect = { text = "func scale(x, y int) int {" },
    why = "`f(` lands on the parenthesis, `ll` on the space after `x`, and `4x` deletes ` int`. `dt,` would do it up to the comma.",
  },
  {
    id = "extract-variable", title = "Extract a constant", level = 2, ft = "typescript",
    brief = "The rate 1.2 appears twice. Name it with a `const rate = 1.2;` line above, and use `rate` in the call.",
    text = "console.log(price * 1.2 + shipping * 1.2);",
    solution = [[:s/1\.2/rate/g<CR>Oconst rate = 1.2;<Esc>]],
    expect = { text = "const rate = 1.2;\nconsole.log(price * rate + shipping * rate);" },
    why = "Replace every use first (`:s/.../g`), then open a line above with `O` and declare it. Code actions do both in one step.",
  },
  {
    id = "rename-project", title = "Rename across the file", level = 2, ft = "lua", needs = "replace",
    brief = "Rename `old_name` to `count` everywhere in the buffer.",
    lines = { "local old_name = 1", "old_name = old_name + 1", "return old_name" },
    solution = "gg:%s/old_name/count/g<CR>",
    plugin_par = 6,
    expect = { text = "local count = 1\ncount = count + 1\nreturn count" },
    check = lua_returns(2),
    helps = { replace = "a search/replace UI previews every change before you apply it" },
    why = "`:%s/old/new/g` is enough for one file. With several files, a project search/replace UI gives you the preview.",
  },
  {
    id = "wrap-bracket", title = "Wrap it in a list", level = 2, ft = "javascript", needs = "surround",
    brief = "Wrap `item` in square brackets: it should become a one-element list.",
    text = "const list = item;",
    cursor = { 1, 13 },
    solution = [[ciw[<C-r>"]<Esc>]],
    plugin_par = 5,
    expect = { text = "const list = [item];" },
    helps = { surround = "one surround command: ysiw] (nvim-surround) or saiw] (mini.surround)" },
    why = "Native: change the word to `[`, paste the deleted word from the unnamed register, close the bracket. A surround plugin is 5 keys.",
  },
  -- level 3 ---------------------------------------------------------------
  {
    id = "swap-arguments", title = "Swap the arguments", level = 3, ft = "go",
    brief = "Swap the two arguments: `ratio(width, height)` becomes `ratio(height, width)`.",
    text = "total := ratio(width, height)",
    solution = "f(lcwheight<Esc>wwcwwidth<Esc>",
    expect = { text = "total := ratio(height, width)" },
    why = "Retype both names with `cw`; `w` from the end of a word steps over the comma. With an argument text object you can swap in one go.",
  },
  {
    id = "invert-if", title = "Invert the condition", level = 3, ft = "python",
    brief = "Invert the if: `if not enabled`, with the two branches swapped.",
    lines = { "if enabled:", "    start()", "else:", "    stop()" },
    solution = "winot <Esc>:4m1|4m2<CR>",
    loose = true,
    expect = { text = "if not enabled:\n    stop()\nelse:\n    start()" },
    why = "Negate the condition, then swap the branches: `:4m1` moves the `stop()` line up, `:4m2` the `else:` after it. Linewise `ddp` also works.",
  },
  {
    id = "rename-dot-repeat", title = "Rename with cgn and the dot", level = 3, ft = "python",
    brief = "Rename `total` to `sum` everywhere without a :s command (the cursor is on the first one).",
    lines = { "total = 0", "total += 1", "print(total)" },
    solution = "ciwsum<Esc>/total<CR>cgnsum<Esc>.",
    expect = { text = "sum = 0\nsum += 1\nprint(sum)" },
    why = "`cgn` changes the next match of the last search; `.` repeats it on the one after that. Powerful when each hit needs a look.",
  },
  {
    id = "swap-params", title = "Swap the parameters", level = 3, ft = "javascript", needs = "textobjects",
    brief = "Swap the two parameters: `area(width, height)` becomes `area(height, width)`.",
    text = "function area(width, height) {}",
    solution = "f(lcwheight<Esc>wwcwwidth<Esc>",
    plugin_par = 4,
    expect = { text = "function area(height, width) {}" },
    helps = { textobjects = "treesitter-textobjects swap_next / swap_previous (e.g. a mapping on <leader>a) swaps parameters in one key" },
    why = "Native: retype both names. With treesitter-textobjects a `swap_next` mapping moves the parameter under the cursor in 3-4 keys.",
  },
  {
    id = "expression-bodied", title = "Expression-bodied method", level = 3, ft = "cs",
    brief = "Turn the method into an expression body: `public int Twice(int x) => x * 2;`",
    lines = { "public int Twice(int x)", "{", "    return x * 2;", "}" },
    solution = "A =><Esc>jddjddkJwdw",
    expect = { text = "public int Twice(int x) => x * 2;" },
    why = "`A =>` appends the arrow, `dd` drops the braces, `J` joins the body up, and `dw` removes `return`.",
  },
  -- level 4 ---------------------------------------------------------------
  {
    id = "inline-variable", title = "Inline the variable", level = 4, ft = "lua",
    brief = "Inline `sum`: remove the variable and use `(a + b)` where it was used.",
    lines = { "local a, b = 2, 3", "local sum = a + b", "return sum * 2" },
    solution = "jwwwy$dd0fsciw(<C-r>0)<Esc>",
    expect = { text = "local a, b = 2, 3\nreturn (a + b) * 2" },
    check = lua_returns(10),
    why = "Yank the expression (`y$` from its start), delete the declaration, change the use with `ciw` and paste from register 0, which a delete does not overwrite.",
  },
  {
    id = "loop-to-filter", title = "Loop to comprehension", level = 4, ft = "python",
    brief = "Replace the loop with a list comprehension: `evens = [n for n in nums if n % 2 == 0]`",
    lines = { "evens = []", "for n in nums:", "    if n % 2 == 0:", "        evens.append(n)" },
    solution = "ccevens = [n for n in nums if n % 2 == 0]<Esc>j3dd",
    expect = { text = "evens = [n for n in nums if n % 2 == 0]" },
    why = "`cc` rewrites the first line, `j3dd` removes the three loop lines. Comprehensions state *what*, the loop said *how*.",
  },
  {
    id = "loop-to-map", title = "Loop to map", level = 4, ft = "javascript",
    brief = "Replace the loop with `const out = nums.map(n => n * 2);`",
    lines = { "const out = [];", "for (const n of nums) out.push(n * 2);" },
    solution = "ccconst out = nums.map(n => n * 2);<Esc>jdd",
    expect = { text = "const out = nums.map(n => n * 2);" },
    why = "Rewrite the declaration with `cc`, then delete the loop line. `.map` is the loop that builds a new array.",
  },
  -- level 5 ---------------------------------------------------------------
  {
    id = "extract-function", title = "Extract a function", level = 5, ft = "lua",
    brief = "Both lines double a sum. Extract `dbl(s)` above them (`local function dbl(s) return s * 2 end`) and call it.",
    lines = { "local a, b, c, d = 1, 2, 3, 4", "local x = (a + b) * 2", "local y = (c + d) * 2", "return x + y" },
    solution = [[Olocal function dbl(s) return s * 2 end<Esc>:3,4s/(\(\w\) + \(\w\)) \* 2/dbl(\1 + \2)/<CR>]],
    par_seconds = 40,
    expect = {
      text = "local function dbl(s) return s * 2 end\nlocal a, b, c, d = 1, 2, 3, 4\nlocal x = dbl(a + b)\nlocal y = dbl(c + d)\nreturn x + y",
    },
    check = lua_returns(20),
    why = "Declare the function with `O`, then rewrite the repeated expression with a capture group. `\\(` / `\\)` are the groups, `\\1` the first.",
  },
  {
    id = "callback-to-async", title = "Callback to async/await", level = 5, ft = "javascript",
    brief = "Convert the callback to await: `const data = await fs.readFile(path);`, then `use(data);` unindented.",
    lines = { "fs.readFile(path, (err, data) => {", "  use(data);", "});" },
    solution = "ccconst data = await fs.readFile(path);<Esc>j<<jdd",
    par_seconds = 40,
    loose = true,
    expect = { text = "const data = await fs.readFile(path);\nuse(data);" },
    why = "Rewrite the call line (`cc`), dedent the body (`<<`) and delete the closing `});`. The body now reads top to bottom.",
  },
}
