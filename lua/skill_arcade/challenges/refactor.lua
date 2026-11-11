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

  -- TypeScript and C# batch ----------------------------------------------------
  -- level 1
  {
    id = "ts-let-to-const", title = "let to const", level = 1, ft = "typescript",
    brief = "`limit` and `label` never change: make them `const`. `sum` is reassigned, so it stays `let`.",
    text = [==[
let limit = 10;
let label = "total";
let sum = 0;
sum += limit;]==],
    solution = [==[:1,2s/^let/const/<CR>]==],
    expect = { text = 'const limit = 10;\nconst label = "total";\nlet sum = 0;\nsum += limit;' },
    why = "A line range before `s` limits the substitution. `^` anchors it, so a `let` inside a word or later in the line is left alone.",
  },
  {
    id = "ts-as-const", title = "Freeze the literal", level = 1, ft = "typescript",
    brief = "Add `as const` to the array, before the semicolon, so its items become literal types.",
    text = [==[const dirs = ["up", "down", "left"];]==],
    solution = [==[$i as const<Esc>]==],
    expect = { text = 'const dirs = ["up", "down", "left"] as const;' },
    why = "`$` lands on the last character (the `;`) and `i` inserts before it. `A` would insert after it.",
  },
  {
    id = "ts-optional-param", title = "Optional parameter", level = 1, ft = "typescript",
    brief = "`name: string | undefined` becomes the optional parameter `name?: string`.",
    text = [==[function greet(name: string | undefined) {}]==],
    solution = [==[:s/: string | undefined/?: string/<CR>]==],
    expect = { text = "function greet(name?: string) {}" },
    why = "The `|` in the pattern is literal in a Vim `:s` (alternation is `\\|`), so the text can be copied as it is.",
  },
  {
    id = "cs-target-typed-new", title = "Target-typed new", level = 1, ft = "cs",
    brief = "The type is already on the left: shorten the right side to `new()`.",
    text = [==[List<string> names = new List<string>();]==],
    solution = [==[:s/new List<string>/new/<CR>]==],
    expect = { text = "List<string> names = new();" },
    why = "C# 9 infers the type of `new()` from the declaration. The same `:s` works for fields, parameters and return values.",
  },
  {
    id = "cs-count-any", title = "Count() > 0 is Any()", level = 1, ft = "cs",
    brief = "Replace `Count() > 0` by `Any()`: it stops at the first item.",
    text = [==[if (items.Count() > 0) { Run(); }]==],
    solution = [==[:s/Count() > 0/Any()/<CR>]==],
    expect = { text = "if (items.Any()) { Run(); }" },
    why = "`Any()` does not enumerate the whole sequence. Here the `(` `)` of `Count()` are literal in the pattern.",
  },
  -- level 2
  {
    id = "ts-nullish-default", title = "Ternary to ??", level = 2, ft = "typescript",
    brief = "Replace the ternary by the nullish coalescing operator: `user.name ?? \"anon\"`.",
    text = [==[const name = user.name !== undefined ? user.name : "anon";]==],
    solution = [==[:s/ !== undefined ? user.name :/ ??/<CR>]==],
    expect = { text = 'const name = user.name ?? "anon";' },
    why = "Match only the middle part of the expression and the rest stays in place. `?` is a plain character in Vim's default regex mode.",
  },
  {
    id = "ts-template-literal", title = "Concatenation to template literal", level = 2, ft = "typescript",
    brief = "Rewrite the concatenation as a template literal with `${name}`.",
    text = [==[const msg = "Hello, " + name + "!";]==],
    solution = [==[:s/"Hello, " + name + "!"/`Hello, ${name}!`/<CR>]==],
    expect = { text = "const msg = `Hello, ${name}!`;" },
    why = "A `:s` can rewrite a whole expression in one go. `ci\"` then typing the backticks is the manual route.",
  },
  {
    id = "ts-readonly-fields", title = "Make the fields readonly", level = 2, ft = "typescript",
    brief = "Mark both fields `readonly`.",
    text = [==[
class Point {
  x: number;
  y: number;
}]==],
    solution = [==[:2,3s/^\s*/&readonly /<CR>]==],
    expect = { text = "class Point {\n  readonly x: number;\n  readonly y: number;\n}" },
    why = "`&` in the replacement is the whole match (the indentation), so `readonly ` lands right after it. A visual block with `I` does the same.",
  },
  {
    id = "ts-extract-type-alias", title = "Extract a type alias", level = 2, ft = "typescript",
    brief = "Name the inline object type: declare `type Size = { w: number; h: number };` above and use `Size` for the parameter.",
    text = [==[function area(s: { w: number; h: number }) {}]==],
    solution = [==[:s/{ w: number; h: number }/Size/<CR>Otype Size = { w: number; h: number };<Esc>]==],
    expect = { text = "type Size = { w: number; h: number };\nfunction area(s: Size) {}" },
    why = "Replace the use first, then `O` opens a line above for the declaration. A TypeScript code action does both.",
  },
  {
    id = "ts-type-guard", title = "Turn it into a type guard", level = 2, ft = "typescript",
    brief = "Give `isString` the return type `x is string`, so callers get narrowing.",
    text = [==[
function isString(x: unknown) {
  return typeof x === "string";
}]==],
    solution = [==[f)a: x is string<Esc>]==],
    expect = { text = 'function isString(x: unknown): x is string {\n  return typeof x === "string";\n}' },
    why = "`f)` jumps to the closing parenthesis and `a` appends after it.",
  },
  {
    id = "ts-includes", title = "indexOf to includes", level = 2, ft = "typescript",
    brief = "`indexOf(...) !== -1` reads better as `includes(...)`.",
    text = [==[if (list.indexOf(item) !== -1) {}]==],
    solution = [==[:s/\.indexOf(\(.*\)) !== -1/.includes(\1)/<CR>]==],
    expect = { text = "if (list.includes(item)) {}" },
    why = [==[`\(...\)` captures the argument and `\1` puts it back inside the new call.]==],
  },
  {
    id = "cs-auto-property", title = "Backing field to auto-property", level = 2, ft = "cs",
    brief = "Delete the backing field and turn the property into `{ get; set; }`.",
    lines = { "private int _age;", "public int Age { get { return _age; } set { _age = value; } }" },
    solution = [==[dd:s/{ get.*/{ get; set; }/<CR>]==],
    expect = { text = "public int Age { get; set; }" },
    why = "`dd` drops the field, then `:s/{ get.*/` replaces everything from the first accessor to the end of the line.",
  },
  {
    id = "cs-null-assign", title = "Null check to ??=", level = 2, ft = "cs",
    brief = "Rewrite the null check and assignment as the `??=` operator.",
    text = [==[if (cache == null) cache = new();]==],
    solution = [==[:s/if (\(\w\+\) == null) \1 = /\1 ??= /<CR>]==],
    expect = { text = "cache ??= new();" },
    why = [==[`\(\w\+\)` captures the variable and `\1` requires the same name again, so only a real "assign if null" is rewritten.]==],
  },
  {
    id = "cs-expression-property", title = "Property to expression body", level = 2, ft = "cs",
    brief = "Turn the getter-only property into `=> _name;`.",
    text = [==[public string Name { get { return _name; } }]==],
    solution = [==[:s/{ get { return \(.*\); } }/=> \1;/<CR>]==],
    expect = { text = "public string Name => _name;" },
    why = "Capture the returned expression and put it after `=>`.",
  },
  {
    id = "cs-is-pattern", title = "Declare the cast with is", level = 2, ft = "cs",
    brief = "Use a declaration pattern: `obj is string s`, and drop the manual cast line.",
    text = [==[
if (obj is string)
{
    var s = (string)obj;
    Use(s);
}]==],
    solution = [==[f)i s<Esc>3Gdd]==],
    expect = { text = "if (obj is string s)\n{\n    Use(s);\n}" },
    why = "`f)` then `i` adds ` s` before the parenthesis, and `3Gdd` removes the cast line.",
  },
  {
    id = "cs-init-required", title = "required + init", level = 2, ft = "cs",
    brief = "Make the property `required` and set-once: `public required string Name { get; init; }`.",
    text = [==[public string Name { get; set; }]==],
    solution = [==[:s/public/public required/|s/set;/init;/<CR>]==],
    expect = { text = "public required string Name { get; init; }" },
    why = "`|` chains two `:s` on the same line. The second one runs on the line the first left the cursor on.",
  },
  {
    id = "cs-string-interpolation", title = "Concatenation to interpolation", level = 2, ft = "cs",
    brief = "Use an interpolated string: `$\"Hi {name}!\"`.",
    text = [==[var s = "Hi " + name + "!";]==],
    solution = [==[:s/"Hi " + name + "!"/$"Hi {name}!"/<CR>]==],
    expect = { text = 'var s = $"Hi {name}!";' },
    why = "`$` and `{` are plain text in the replacement, so the new string can be typed as it is.",
  },
  -- level 3
  {
    id = "ts-optional-chaining", title = "Guard chain to ?.", level = 3, ft = "typescript",
    brief = "Replace the `&&` chain by optional chaining.",
    text = [==[const city = user && user.address && user.address.city;]==],
    solution = [==[:s/\(\w\+\) && \1\.\(\w\+\) && \1\.\2\./\1?.\2?./<CR>]==],
    expect = { text = "const city = user?.address?.city;" },
    why = [==[Back-references (`\1`, `\2`) make the pattern say "the same name again", which is exactly what an `&&` guard chain repeats.]==],
  },
  {
    id = "ts-arrow-function", title = "Function to arrow", level = 3, ft = "typescript",
    brief = "Turn the function declaration into a `const` arrow function with an expression body.",
    text = [==[function double(n: number): number { return n * 2; }]==],
    solution = [==[:s/function \(\w\+\)\(([^)]*)\): \(\w\+\) { return \(.*\); }/const \1 = \2: \3 => \4;/<CR>]==],
    expect = { text = "const double = (n: number): number => n * 2;" },
    why = "Capture the name, the parameter list, the return type and the returned expression, then rebuild the line in the new order.",
  },
  {
    id = "ts-generics", title = "Make it generic", level = 3, ft = "typescript",
    brief = "`first` works for any element type: replace `number` by a type parameter `T` and declare it as `first<T>`.",
    text = [==[function first(xs: number[]): number { return xs[0]; }]==],
    solution = [==[:s/number/T/g<CR>f(i<T><Esc>]==],
    expect = { text = "function first<T>(xs: T[]): T { return xs[0]; }" },
    why = "Substitute all `number` first, then `f(` and `i<T>` declare the parameter. A rename plus a code action does it in your editor.",
  },
  {
    id = "ts-promise-all", title = "Await in parallel", level = 3, ft = "typescript",
    brief = "The two calls do not depend on each other: run them together with `Promise.all`.",
    lines = { "const a = await getA();", "const b = await getB();" },
    solution = [==[ccconst [a, b] = await Promise.all([getA(), getB()]);<Esc>jdd]==],
    expect = { text = "const [a, b] = await Promise.all([getA(), getB()]);" },
    why = "Rewrite the first line with `cc`, then drop the second one with `jdd`.",
  },
  {
    id = "cs-null-conditional", title = "Ternary to ?. and ??", level = 3, ft = "cs",
    brief = "Use `?.` and `??` instead of the null check.",
    text = [==[var len = s != null ? s.Length : 0;]==],
    solution = [==[:s/\(\w\+\) != null ? \1\.\(\w\+\) : 0/\1?.\2 ?? 0/<CR>]==],
    expect = { text = "var len = s?.Length ?? 0;" },
    why = [==[`\1` ties the null check to the member access that follows, so a different variable is never rewritten.]==],
  },
  {
    id = "cs-using-declaration", title = "using declaration", level = 3, ft = "cs",
    brief = "Use the C# 8 `using var` declaration and remove the braces. The body ends up unindented.",
    text = [==[
using (var f = File.OpenRead(p))
{
    Read(f);
}]==],
    solution = [==[:s/using (\(.*\))/using \1;/<CR>jdd<<jdd]==],
    loose = true,
    expect = { text = "using var f = File.OpenRead(p);\nRead(f);" },
    why = "Rewrite the head, delete the opening brace, dedent the body (`<<`) and delete the closing brace.",
  },
  {
    id = "cs-record", title = "Class to record", level = 3, ft = "cs",
    brief = "Replace the immutable class by a positional record: `public record Point(int X, int Y);`.",
    text = [==[
public class Point
{
    public int X { get; }
    public int Y { get; }
    public Point(int x, int y) { X = x; Y = y; }
}]==],
    solution = [==[ccpublic record Point(int X, int Y);<Esc>jdG]==],
    expect = { text = "public record Point(int X, int Y);" },
    why = "`cc` rewrites the first line, `jdG` deletes from the next line to the end of the file.",
  },
  {
    id = "cs-primary-constructor", title = "Primary constructor", level = 3, ft = "cs",
    brief = "Move the parameter to the class header (`public class Svc(ILogger log)`) and delete the field and constructor.",
    text = [==[
public class Svc
{
    private readonly ILogger _log;
    public Svc(ILogger log) { _log = log; }
}]==],
    solution = [==[A(ILogger log)<Esc>3Gdd.]==],
    expect = { text = "public class Svc(ILogger log)\n{\n}" },
    why = "`3Gdd` removes the field, `.` repeats it on the constructor that moved up into line 3.",
  },
  {
    id = "cs-async-method", title = "Block on .Result to async", level = 3, ft = "cs",
    brief = "Make the method `async Task<int> LoadAsync()` and `await` the call instead of reading `.Result`.",
    text = [==[public int Load() { return client.Get(url).Result; }]==],
    solution = [==[:s/public int Load()/public async Task<int> LoadAsync()/|s/return \(.*\)\.Result;/return await \1;/<CR>]==],
    expect = { text = "public async Task<int> LoadAsync() { return await client.Get(url); }" },
    why = "Two `:s` on one line: the signature first, then `.Result` becomes a leading `await` through a capture.",
  },
  -- level 4
  {
    id = "ts-then-to-async", title = ".then to async/await", level = 4, ft = "typescript",
    brief = "Make `load` async: `const r = await fetch(url);` then `return r.json();`.",
    text = [==[
function load() {
  return fetch(url).then((r) => r.json());
}]==],
    solution = [==[Iasync <Esc>jccconst r = await fetch(url);<Esc>oreturn r.json();<Esc>]==],
    par_seconds = 30,
    expect = { text = "async function load() {\n  const r = await fetch(url);\n  return r.json();\n}" },
    why = "`I` prefixes the declaration, `cc` rewrites the body line (keeping its indent) and `o` adds the second statement.",
  },
  {
    id = "ts-union-to-enum", title = "String union to enum", level = 4, ft = "typescript",
    brief = "Turn the union into `enum Dir { Up = \"up\", ... }`, one member per line with a trailing comma.",
    text = [==[
type Dir =
  | "up"
  | "down"
  | "left";]==],
    solution = [==[:2,4s/| "\(\w\)\(\w*\)";\?/\u\1\2 = "\1\2",/<CR>ggccenum Dir {<Esc>Go}<Esc>]==],
    par_seconds = 40,
    loose = true,
    expect = { text = 'enum Dir {\n  Up = "up",\n  Down = "down",\n  Left = "left",\n}' },
    why = [==[`\u` upper-cases the next character in the replacement; the two captures rebuild `Up = "up"`. Then fix the first and last line.]==],
  },
  {
    id = "cs-linq-where-select", title = "Loop to LINQ", level = 4, ft = "cs",
    brief = "Replace the loop by `users.Where(u => u.Active).Select(u => u.Name).ToList()`.",
    text = [==[
var names = new List<string>();
foreach (var u in users)
{
    if (u.Active) names.Add(u.Name);
}]==],
    solution = [==[ccvar names = users.Where(u => u.Active).Select(u => u.Name).ToList();<Esc>j4dd]==],
    par_seconds = 30,
    expect = { text = "var names = users.Where(u => u.Active).Select(u => u.Name).ToList();" },
    why = "`cc` writes the query, `j4dd` removes the four loop lines.",
  },
  {
    id = "cs-switch-expression", title = "Switch statement to expression", level = 4, ft = "cs",
    brief = "Turn the statement into `return n switch { 1 => \"one\", ... _ => \"many\" };` (one arm per line, trailing commas).",
    text = [==[
switch (n)
{
    case 1: return "one";
    case 2: return "two";
    default: return "many";
}]==],
    solution = [==[:3,4s/case \(\d\+\): return \("\w*"\);/\1 => \2,/<CR>:5s/default: return \("\w*"\);/_ => \1,/<CR>ggccreturn n switch<Esc>Gs};<Esc>]==],
    par_seconds = 45,
    expect = { text = 'return n switch\n{\n    1 => "one",\n    2 => "two",\n    _ => "many",\n};' },
    why = "Rewrite the arms with captures (the `default` becomes `_`), then replace the head and add the `;` after the last brace with `s`.",
  },
  {
    id = "cs-extract-interface", title = "Extract an interface", level = 4, ft = "cs",
    brief = "Add `: IMailer` to the class and declare `public interface IMailer` above it with the method signature.",
    text = [==[
public class Mailer
{
    public void Send(string to) { }
}]==],
    solution = [==[A : IMailer<Esc>:1,4t0<CR>:1s/class Mailer : IMailer/interface IMailer/|3s/public //|3s/ { }/;/<CR>]==],
    par_seconds = 45,
    expect = {
      text = "public interface IMailer\n{\n    void Send(string to);\n}\npublic class Mailer : IMailer\n{\n    public void Send(string to) { }\n}",
    },
    why = "`:1,4t0` copies the class to the top; the copy is then trimmed into an interface with a few `:s`.",
  },
  -- level 5
  {
    id = "ts-param-properties", title = "Parameter properties", level = 5, ft = "typescript",
    brief = "Replace the fields and the assignments by parameter properties: `constructor(public name: string, public age: number) {}`.",
    text = [==[
class User {
  name: string;
  age: number;
  constructor(name: string, age: number) {
    this.name = name;
    this.age = age;
  }
}]==],
    solution = [==[:2,3d<CR>:3,4d<CR>:2s/(\(\w\+\)/(public \1/|s/, /, public /|s/{$/{}/<CR>:3d<CR>]==],
    par_seconds = 50,
    expect = { text = "class User {\n  constructor(public name: string, public age: number) {}\n}" },
    why = "Delete the two field lines, then the assignments, then add `public` to both parameters and close the empty body.",
  },
  {
    id = "ts-switch-to-record", title = "Switch to a lookup table", level = 5, ft = "typescript",
    brief = "Replace the function by `const labels: Record<Status, string> = { ... };` with one `key: value,` per line.",
    text = [==[
function label(s: Status) {
  switch (s) {
    case "ok": return "Okay";
    case "bad": return "Broken";
  }
}]==],
    solution = [==[:3,4s/case "\(\w\+\)": return \("[^"]*"\);/\1: \2,/<CR>ggccconst labels: Record<Status, string> = {<Esc>jdd:4d<CR>GA;<Esc>]==],
    par_seconds = 50,
    loose = true,
    expect = { text = 'const labels: Record<Status, string> = {\n  ok: "Okay",\n  bad: "Broken",\n};' },
    why = "Turn each `case` into a `key: value,` pair, replace the function head, delete the `switch` lines and finish with `};`.",
  },
  {
    id = "cs-extract-method", title = "Extract a method", level = 5, ft = "cs",
    brief = "Move the summing lines into `int Sum(int[] xs)` (blank line, signature, braces, `return total;`) and call `Sum(xs)` from the `Console.WriteLine`.",
    text = [==[
var total = 0;
foreach (var x in xs) total += x;
Console.WriteLine(total);]==],
    solution = [==[:3s/(total)/(Sum(xs))/<CR>:1,2m$<CR>Goreturn total;<CR>}<Esc>2GO<CR>int Sum(int[] xs)<CR>{<Esc>]==],
    par_seconds = 60,
    loose = true,
    expect = {
      text = "Console.WriteLine(Sum(xs));\n\nint Sum(int[] xs)\n{\n    var total = 0;\n    foreach (var x in xs) total += x;\n    return total;\n}",
    },
    why = "Replace the use, move the body to the end with `:m$`, close it, then open the signature above the body with `O`.",
  },
  -- Go and Python, so the language counts stay balanced ----------------------
  {
    id = "go-short-var", title = "Short variable declaration", level = 1, ft = "go",
    brief = "Use the short form: `count := 0`.",
    text = [==[var count int = 0]==],
    solution = [==[:s/var \(\w\+\) int = \(.*\)/\1 := \2/<CR>]==],
    expect = { text = "count := 0" },
    why = "Two captures: the name and the value. The type is inferred from the value.",
  },
  {
    id = "py-fstring", title = "Concatenation to f-string", level = 1, ft = "python",
    brief = "Rewrite the concatenation as an f-string: `f\"Hello, {name}!\"`.",
    text = [==[msg = "Hello, " + name + "!"]==],
    solution = [==[:s/"Hello, " + name + "!"/f"Hello, {name}!"/<CR>]==],
    expect = { text = 'msg = f"Hello, {name}!"' },
    why = "One `:s` rewrites the whole expression. Inside an f-string the name goes between braces.",
  },
  {
    id = "go-range-loop", title = "Index loop to range", level = 2, ft = "go",
    brief = "Replace the three-part `for` header by `for i := range xs {`.",
    text = [==[for i := 0; i < len(xs); i++ {]==],
    solution = [==[:s/i := 0; i < len(\(\w\+\)); i++/i := range \1/<CR>]==],
    expect = { text = "for i := range xs {" },
    why = [==[`\(\w\+\)` captures the slice name and `\1` puts it after `range`.]==],
  },
  {
    id = "go-wrap-error", title = "Wrap the error", level = 2, ft = "go",
    brief = "Return the error wrapped with context: `fmt.Errorf(\"load: %w\", err)`.",
    text = [==[return err]==],
    solution = [==[:s/return err/return fmt.Errorf("load: %w", err)/<CR>]==],
    expect = { text = 'return fmt.Errorf("load: %w", err)' },
    why = "`%w` keeps the original error reachable by `errors.Is` and `errors.As`.",
  },
  {
    id = "py-enumerate", title = "range(len()) to enumerate", level = 2, ft = "python",
    brief = "Use `enumerate` and the item itself instead of indexing: `for i, x in enumerate(xs)` and `print(i, x)`.",
    text = [==[
for i in range(len(xs)):
    print(i, xs[i])]==],
    solution = [==[:%s/i in range(len(xs))/i, x in enumerate(xs)/|%s/xs\[i\]/x/<CR>]==],
    expect = { text = "for i, x in enumerate(xs):\n    print(i, x)" },
    why = "Two `:%s` in a row, chained with `|`.",
  },
  {
    id = "py-with-open", title = "Use a context manager", level = 3, ft = "python",
    brief = "Read the file inside `with open(path) as f:` and drop the explicit `close()`.",
    text = [==[
f = open(path)
data = f.read()
f.close()]==],
    solution = [==[:1s/f = open(path)/with open(path) as f:/<CR>jI    <Esc>jdd]==],
    expect = { text = "with open(path) as f:\n    data = f.read()" },
    why = "Rewrite the head, indent the body with `I` and four spaces, delete the `close()` line.",
  },
}
