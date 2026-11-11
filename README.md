# nvim-skill-arcade

A mini game that tests and improves your Neovim skills **with your own keybinds and plugins**.
Short rounds, score, streaks, lives, a clock, difficulty that ramps up, personal bests - and after every
round a short lesson: a better way to do it, and which of *your* installed plugins could have helped.

Pure Lua, no dependencies. Sibling of [nvim-learn-refactor](../nvim-learn-refactor) (refactoring exercises);
this one is gameplay-driven.

## How it plays

1. `:ArcadeMenu` (default `<leader>Gm`) -> **Start a run**.
2. A dedicated tab opens with a challenge, e.g. *"Replace the text inside the quotes with: new"*.
   A HUD (top right) shows the task, clock, key count vs. par, lives, streak, score and the **real keys**
   for pause / skip / hint / quit / menu.
3. You get a few seconds to read, then the clock starts. Solve it **any way you like** - the game only looks at
   the resulting buffer / cursor / marks / windows / quickfix state, never at which keys you used. It detects the
   win by itself (no "submit").
4. A result window shows rank (S-C), points, the breakdown, a better way, your tools, and your bad habits.
   `<CR>` for the next challenge. Run = 6 challenges, 3 lives (a timeout costs a life; skip is free but scores 0).
5. Clear >= 80% without game over and your level goes up; start the next run harder.

Modes: **run** (ramped difficulty), **daily** (same 5 challenges for everyone each day, own best per day),
**practice** (pick an area, no lives, `r` retries).

### Scoring

| part | rule |
|---|---|
| base | 100 + 40 per level |
| keys | up to +50% when keys <= par, fading to 0 at 2x par (counted with `vim.on_key`, control keys excluded) |
| time | up to +25% for beating par time |
| toolbelt | +25% when you beat the native par on a challenge your installed plugin group helps with |
| habits | -2 per hjkl spam key (5+ in a row), -5 per arrow, -5 per mouse click (max 40%) |
| hints | -25% each |
| streak | x(1 + 0.1 per consecutive clear, max x2) |

Rank: **S** keys <= par and time <= par; **A** <= 1.5x keys / 2x time; **B** <= 2x keys; else **C**.

## Skill areas (100+ built-in challenges)

`motions`, `textobjects`, `editing`, `search` (:s, :g), `macros`, `registers`, `marks` (marks + jumplist),
`windows` (splits, tabs, buffers), `quickfix`, `diagnostics` (jump / float / to quickfix - planted by the game, so it
works with or without an LSP), `track` (reach a goal on a text-grid map, see below), `refactor` (refactor sprints, see
below), `plugins` (featured challenges for plugins you have).
Restrict them: `areas = { "motions", "textobjects" }`.

### Refactor sprints (`refactor`)

Small, fast code refactors (10-40 s): rename a symbol, extract a variable or function, swap arguments, invert an `if`,
inline a variable, loop to map/filter, callback to `async`/`await`, join/split lines, change a signature, reorder
fields. Only the END STATE counts: the buffer must equal the refactored code (whitespace trimmed like every challenge),
and for Lua the result is also run, so the behaviour must survive. The snippets are Lua, TypeScript, JavaScript, Go,
C# and Python; `refactor_languages = { "lua", "go" }` limits them (filetypes `lua`, `typescript`, `javascript`, `go`,
`cs`, `python`). Some sprints feature a plugin group you have (search/replace UI, extra text objects, surround) and all of
them are solvable with native keys. They join runs, daily and practice like every area.

### Tracks (`track`)

A **track** is a text-grid map. You start on one cell and must reach the goal cell with motions, in as few keys as
you can, optionally touching numbered checkpoints in order on the way. Maps mark the start `S`, the goal `X` and the
checkpoints `1`..`6`. Only the end state is judged (cursor on the goal, every checkpoint visited in order, map
untouched), so your own keybinds and plugins work. The HUD shows checkpoint progress and the rules of the map.

Some tracks switch key families off so the motions you have not practised are the only way through: `hjkl`,
`arrows`, `mouse` (buffer-local, only on that map). Sixteen built-in tracks run from `$` and `f{char}` (level 1) to
`%`, `}`, marks, `{n}G`, `-`/`+` and search with checkpoints and rules (level 5).

In a challenge file a track is data:

```json
{ "area": "track", "text": "S...X\n.....", "cursor": [1, 0],
  "track": { "goal": [1, 4], "checkpoints": [[2, 2]], "forbid": ["hjkl", "arrows"] },
  "solution": "j2lgg$", "...": "id title level brief why" }
```

`expect` is derived (cursor on `goal`, text unchanged) and may be left out. At most 6 checkpoints; each is a cell
(row 1-based, column 0-based) inside the map, different from the goal and from each other. The reference
`solution` is replayed headless and must reach the goal through every checkpoint in order.

## Your setup, not a sandbox

* Your mappings and plugins stay active. Use flash/leap, surround, mini.ai, telescope, whatever you normally use.
* `:ArcadeSetup` shows what the game detected (lazy.nvim spec + loaded modules + runtime files): jump plugins,
  surround, extra text objects, comment, pickers, which-key, oil, harpoon, trouble, multicursor, ...
* **Plugin-featured challenges** appear only if you have that plugin group, and are always solvable natively
  (the plugin just makes them cheaper -> toolbelt bonus).
* After each round: *"You have flash.nvim: label jump ... (s{char}{char}{label})"* or, when you have none,
  *"No jump plugin found ... (try flash.nvim or leap.nvim)"*.
* Challenge files are real temp files under `stdpath("data")/skill-arcade/arena`, so your LSP / treesitter / quickfix
  commands (`:vimgrep %`) behave as usual. Your registers, quickfix list and search pattern are restored when a
  run ends.

## Install (lazy.nvim / LazyVim)

Copy [`examples/lazy.lua`](examples/lazy.lua) to `lua/plugins/skill-arcade.lua`:

```lua
{
  "dev-vinicius-andrade/nvim-skill-arcade",
  cmd = { "Arcade", "ArcadeMenu", "ArcadeRun", "ArcadeDaily", "ArcadePractice", "ArcadeToggle", "ArcadeSkip",
          "ArcadeHint", "ArcadeNext", "ArcadeQuit", "ArcadeStats", "ArcadeSetup", "ArcadeGenerate", "ArcadeSync",
          "ArcadeTry", "ArcadeJoin" },
  keys = {
    { "<leader>Gm", "<cmd>ArcadeMenu<cr>", desc = "Arcade: menu" },
    { "<leader>Gg", "<cmd>ArcadeRun<cr>", desc = "Arcade: start a run" },
    -- ... see examples/lazy.lua
  },
  opts = { keymaps = false },
}
```

`<leader>G` is used because `<leader>r` / `<leader>g` are usually taken. Change the prefix freely; the menu and HUD
read whatever you map (by command or by `desc = "SkillArcade <action>"`) and show it. Without lazy `keys`, `setup()`
maps the defaults.

## Keys and commands

| action | command | default key |
|---|---|---|
| menu (only offers what is valid now) | `:ArcadeMenu` / `:Arcade` | `<leader>Gm` |
| start a run | `:ArcadeRun [level]` | `<leader>Gg` |
| daily set | `:ArcadeDaily` | `<leader>Gd` |
| practice an area | `:ArcadePractice [area]` | `<leader>Gr` |
| pause / resume | `:ArcadeToggle` (`:ArcadePause`, `:ArcadePlay`) | `<leader>Gp` |
| skip | `:ArcadeSkip` | `<leader>Gs` |
| hint (-25%) | `:ArcadeHint` | `<leader>Gh` |
| next after a result | `:ArcadeNext` | `<leader>Gn` |
| quit run (shows summary) | `:ArcadeQuit` | `<leader>Gq` |
| stats and bests | `:ArcadeStats` | `<leader>Gt` |
| what the game found in my setup | `:ArcadeSetup` | `<leader>Ge` |
| generate challenges (model) | `:ArcadeGenerate [area] [level]` | - |
| download community challenges | `:ArcadeSync` | - |
| play a draft once (room code, clipboard `+`, or file) | `:ArcadeJoin <code>` / `:ArcadeTry <code|+|file>` | - |

Menu: press the letter, or `j`/`k` + `<CR>`; `q`/`<Esc>` closes. Its "mapped to" column shows your real binding.

## Options

```lua
opts = {
  areas = nil,            -- nil = all, or a list of area names
  run_length = 6, daily_length = 5, lives = 3, countdown = 3,
  level = nil,            -- force the starting difficulty 1-5 (default: your saved level)
  plugin_challenges = true,
  refactor_languages = nil, -- e.g. { "lua", "go" }: limit the refactor sprints to these languages
  hud = true,
  keymaps = { ... } | false,
  data_dir = vim.fn.stdpath("data") .. "/skill-arcade",
  provider = "none",      -- "anthropic" | "openai" for generated challenges
}
```

## Progress

JSON under `data_dir`: `profile.json` (points, level, per-area stats, habits), `bests.json` (per challenge, best run,
daily bests), `history.json` (last 200 runs), `generated/` (model challenges). The menu tip adapts to your most frequent
bad habit.

## Optional: model-generated challenges

```lua
-- Anthropic
opts = { provider = "anthropic" }            -- needs ANTHROPIC_API_KEY
-- any OpenAI-compatible server, e.g. local Ollama
opts = { provider = "openai", openai = { base_url = "http://localhost:11434/v1", model = "qwen2.5-coder:14b" } }
```

`:ArcadeGenerate [area] [level]` asks the model for a few challenges that suit your detected plugins. The model
returns **data only** (start text, cursor, expected text/cursor, reference keys). Nothing it writes is executed; the
reference keys are only displayed (marked *model-made*). Invalid or already-solved challenges are discarded.
(The Ollama container setup from nvim-learn-refactor works unchanged.)

## Community challenges

Anyone can design a challenge on the website of
[nvim-skill-arcade-challenges](https://github.com/dev-vinicius-andrade/nvim-skill-arcade-challenges)
(form -> pull request -> CI replays the reference keys -> review -> published).

`:ArcadeSync` (menu: *Sync community challenges*) downloads the published bundle. They then join runs and practice,
marked *community*. Sync is manual and https-only; set `community = { enabled = false }` to ignore them.

**Join a draft like a game room:** the website gives every draft a *room code* (`ARC1.…`) and a ready command,
`:ArcadeJoin ARC1.…`. Paste it in Neovim and you play the draft with your own keybinds and plugins, as one practice
round with checks and par. The code carries the whole draft (no upload, no server). Other sources work too:
`:ArcadeTry +` reads a code or JSON from the clipboard, `:ArcadeTry path/to/draft.json` reads a file.
Everything goes through the same safety schema as community challenges, and nothing is saved: no points, bests,
stats or history.

Safety: a community challenge is **data only**. `skill_arcade.schema` whitelists every field (unknown fields are
dropped), checks and set-ups come from fixed presets in the plugin, reference keys are restricted (no `:!`, `:lua`,
`|`, `\=`, `<C-r>=`; short ex-command list), and the data is re-validated on download **and on every load**.

## Writing challenges

Each pack is `lua/skill_arcade/challenges/<area>.lua` returning a list:

```lua
{
  id = "change-quotes", title = "Change inside quotes", level = 1,
  brief = 'Replace the text inside the quotes with: new',
  text = [[name = "old value here"]], cursor = { 1, 12 },
  solution = 'ci"new<Esc>',                      -- reference keys: shown as "better way", par = its key count
  expect = { text = [[name = "new"]] },          -- also: cursor = {row, col} | at = {row, "needle"} | marks = {a = 3}
  -- check = function(ctx) ... end               -- custom state check (ctx.lines, cursor, mark(), wins, qf, floats ...)
  -- setup = function(x) ... end                 -- extra buffers (x.new_buf), diagnostics (x.diag_ns), splits ...
  helps = { textobjects = "tip shown with your matching plugin" }, plugin_par = 3,
  why = "...",
}
```

`tests/smoke.lua` replays every `solution` and requires: not solved at start, solved after the keys.

## Tests

```sh
nvim --headless -u NONE -l tests/smoke.lua    # from the repo root, Neovim 0.10+ (tested on 0.12)
```

## Not yet

LSP-dependent challenges (rename, go to definition, code actions) need an attached server in the arena file; the
`needs`/`setup` hooks are there but only diagnostics (planted by the game) are built in so far.
