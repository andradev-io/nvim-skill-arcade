-- run: nvim --headless -u NONE -l tests/smoke.lua   (from the repo root)
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.cmd("runtime plugin/skill-arcade.lua")

local failures = 0
local function check(name, cond, extra)
  if cond then
    print("ok   " .. name)
  else
    failures = failures + 1
    print("FAIL " .. name .. (extra and (" :: " .. tostring(extra)) or ""))
  end
end

local tmp = vim.fn.tempname()
local arcade = require("skill_arcade")
arcade.setup({ data_dir = tmp, keymaps = false })
vim.g.mapleader = " "

local config = require("skill_arcade.config")
local catalog = require("skill_arcade.catalog")
local game = require("skill_arcade.game")
local keys = require("skill_arcade.keys")
local scoring = require("skill_arcade.scoring")
local store = require("skill_arcade.store")
local env = require("skill_arcade.env")

local real_notify = vim.notify
vim.notify = function() end

-- ── content ────────────────────────────────────────────────────────────────
local all = catalog.builtin()
check("at least 100 built-in challenges", #all >= 100, #all)
local areas = {}
for _, ch in ipairs(all) do
  areas[ch.area] = (areas[ch.area] or 0) + 1
end
check("covers all 13 skill areas", vim.tbl_count(areas) == 13, vim.inspect(areas))
local thin = {}
for a, n in pairs(areas) do
  if n < 5 then
    thin[#thin + 1] = a .. "=" .. n
  end
end
check("every area has at least 5 challenges", #thin == 0, table.concat(thin, ","))
local per_level = {}
for _, ch in ipairs(all) do
  per_level[ch.level] = (per_level[ch.level] or 0) + 1
end
check("every level 1-5 has at least 8 challenges", #per_level == 5 and math.min(unpack(per_level)) >= 8, vim.inspect(per_level))
-- refactor sprints: several languages, every level, and the languages setting narrows them
local langs, levels = {}, {}
for _, ch in ipairs(all) do
  if ch.area == "refactor" then
    langs[ch.ft] = true
    levels[ch.level] = true
  end
end
check("refactor sprints cover 6 languages", vim.tbl_count(langs) == 6, vim.inspect(langs))
check("refactor sprints cover levels 1-5", vim.tbl_count(levels) == 5, vim.inspect(levels))
config.setup({ data_dir = vim.fn.tempname(), refactor_languages = { "go" } })
local only_go = vim.tbl_filter(function(c) return c.area == "refactor" end, catalog.available({ areas = { "refactor" } }))
check("refactor_languages keeps only the chosen language", #only_go >= 3 and only_go[1].ft == "go" and #vim.tbl_filter(function(c) return c.ft ~= "go" end, only_go) == 0, #only_go)
for _, lang in ipairs({ "typescript", "cs" }) do
  config.setup({ data_dir = vim.fn.tempname(), refactor_languages = { lang } })
  local mine = vim.tbl_filter(function(c) return c.area == "refactor" end, catalog.available({ areas = { "refactor" } }))
  local lv = {}
  for _, c in ipairs(mine) do
    lv[c.level] = true
    assert(c.ft == lang)
  end
  check(lang .. " refactor sprints: at least 15, every level", #mine >= 15 and vim.tbl_count(lv) == 5, #mine)
  check(lang .. " files get the right extension", mine[1].ext == (lang == "cs" and "cs" or "ts"), mine[1].ext)
end
config.setup({ data_dir = vim.fn.tempname() })
local ids = {}
for _, ch in ipairs(all) do
  check("unique id " .. ch.id, not ids[ch.id])
  ids[ch.id] = true
  check("has brief+solution " .. ch.id, ch.brief and ch.brief ~= "" and ch.solution ~= nil)
end

-- ── pure helpers ───────────────────────────────────────────────────────────
check("tokens", vim.deep_equal(keys.tokens('ci"x<Esc>'), { "c", "i", '"', "x", "<Esc>" }))
check("count with <C-a>", keys.count("5<C-a>") == 2)
local ch1 = { level = 1, par_keys = 4, par_seconds = 10 }
local s = scoring.score(ch1, { keys = 4, seconds = 5, hints = 0, spam = 0, arrows = 0, mouse = 0, streak = 0 })
check("perfect score has S rank + bonuses", s.rank == "S" and s.key_bonus == 50 and s.total > 150, vim.inspect(s))
local slow = scoring.score(ch1, { keys = 20, seconds = 99, hints = 0, spam = 0, arrows = 0, mouse = 0, streak = 0 })
check("slow score = base only, rank C", slow.total == 100 and slow.rank == "C", vim.inspect(slow))
local streaky = scoring.score(ch1, { keys = 20, seconds = 99, streak = 5 })
check("streak multiplier", streaky.total == 150, streaky.total)
local pen = scoring.score(ch1, { keys = 20, seconds = 99, streak = 0, arrows = 3, hints = 1 })
check("penalties", pen.total == 100 - 15 - 25, pen.total)
check("level up on clean run", scoring.next_level(2, 5, 6, false) == 3)
check("level down on bad game over", scoring.next_level(2, 1, 6, true) == 1)
check("grade", scoring.grade({ { ok = true, rank = "S" }, { ok = true, rank = "S" } }) == "S")

-- ── every challenge: fails at start, passes with its reference keys ────────
local function quiet_abort()
  if game.run then
    game.abort("test")
  end
end

for _, ch in ipairs(all) do
  game.start({ mode = "practice", deck = { ch }, countdown = 0 })
  local run = game.run
  check(ch.id .. " starts running", run and run.state == "running")
  check(ch.id .. " NOT solved at start", game.evaluate() == false)
  keys.feed(ch.solution)
  check(ch.id .. " solved by reference keys", game.evaluate() == true,
    vim.inspect({ mode = vim.api.nvim_get_mode().mode, lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }))
  if ch.id == "motions.word-jump" then
    check("on_key logged the typed keys", #run.cur.log == keys.count(ch.solution), #run.cur.log)
  end
  game._tick()
  check(ch.id .. " tick moves to result", game.state() == "result")
  if game.run and game.run.result_ui then
    pcall(game.run.result_ui.close)
  end
  quiet_abort()
  check(ch.id .. " arena torn down", game.run == nil and #vim.api.nvim_list_tabpages() == 1)
end

-- ── a full run: pass, fail by time, finish, persistence ────────────────────
local deck = { catalog.by_id("motions.line-end"), catalog.by_id("editing.swap-lines"), catalog.by_id("search.global-replace") }
game.start({ mode = "run", deck = deck, countdown = 0 })
keys.feed(deck[1].solution)
game._tick()
check("first challenge cleared", game.run.results[1] and game.run.results[1].ok)
check("score recorded", game.run.score > 0 and game.run.streak == 1)
game.next()
check("second challenge running", game.state() == "countdown" or game.state() == "running", game.state())
game.run.cur.countdown_end = 0
game._tick()
check("running after countdown", game.state() == "running")
game.run.cur.ch.time_limit = -1
game._tick()
check("timeout fails and costs a life", game.run.results[2] and not game.run.results[2].ok and game.run.lives == 2)
check("streak reset", game.run.streak == 0)
game.next()
game.run.cur.countdown_end = 0
game._tick()
game.skip()
check("skip scores nothing and keeps lives", game.run.results[3].reason == "skipped" and game.run.lives == 2)
game.next() -- last one -> summary
check("run finished and torn down", game.run == nil)
local prof = store.profile()
check("profile persisted", prof.runs >= 1 and prof.points > 0 and prof.areas.motions and prof.areas.motions.cleared >= 1)
check("personal best persisted", store.bests().challenges["motions.line-end"].score > 0)
check("history persisted", #store.history() >= 1)
for _, w in ipairs(vim.api.nvim_list_wins()) do
  if vim.api.nvim_win_get_config(w).relative ~= "" then
    pcall(vim.api.nvim_win_close, w, true)
  end
end

-- pause locks the buffer and stops the clock
game.start({ mode = "practice", deck = { catalog.by_id("motions.line-end") }, countdown = 0 })
game.pause()
check("pause state", game.state() == "paused")
check("pause locks buffer", vim.bo[game.run.cur.buf].modifiable == false)
local e1 = game.run.cur.elapsed
vim.wait(150)
check("clock stopped while paused", game.run.cur.elapsed == e1)
game.toggle()
check("resume", game.state() == "running" and vim.bo[game.run.cur.buf].modifiable == true)
quiet_abort()

-- ── level ramp / daily / areas ─────────────────────────────────────────────
local run_deck = catalog.build_run({ n = 6, level = 1 })
check("run deck has 6 unique challenges", #run_deck == 6)
check("run difficulty ramps", run_deck[#run_deck].level >= run_deck[1].level, run_deck[1].level .. ">" .. run_deck[#run_deck].level)
local d1, d2 = catalog.build_daily("20260101"), catalog.build_daily("20260101")
local same = #d1 == #d2
for i = 1, #d1 do
  same = same and d1[i].id == d2[i].id
end
check("daily deterministic", same and #d1 == config.options.daily_length)
check("practice deck easiest first", catalog.for_area("motions")[1].level == 1)
config.setup({ data_dir = tmp, areas = { "motions" } })
check("area selection limits offer", #catalog.areas() == 1 and catalog.areas()[1] == "motions")
config.setup({ data_dir = tmp })

-- ── environment detection ──────────────────────────────────────────────────
local info = env.detect()
check("env detect shape", type(info.plugins) == "table" and type(info.groups) == "table" and info.nvim)
package.loaded["flash"] = {}
local info2 = env.detect()
check("detects loaded flash.nvim as jump group", info2.groups.jump and info2.groups.jump[1] == "flash.nvim")
local plug = catalog.available({ env = info2 })
local has_jump = false
for _, ch in ipairs(plug) do
  has_jump = has_jump or ch.id == "plugins.jump-far"
end
check("plugin challenge offered when installed", has_jump)
package.loaded["flash"] = nil
local none = catalog.available({ env = env.detect() })
local still = false
for _, ch in ipairs(none) do
  still = still or ch.needs ~= nil
end
check("plugin challenges hidden when not installed", not still)
local lesson = require("skill_arcade.coach").lesson(catalog.by_id("motions.word-jump"), { log = {}, habits = {} }, info2)
check("lesson names the player's plugin", table.concat(lesson.tools, "\n"):find("flash.nvim", 1, true))
local lesson_none = require("skill_arcade.coach").lesson(catalog.by_id("motions.word-jump"), { log = {}, habits = {} }, env.detect())
check("lesson suggests a plugin when missing", table.concat(lesson_none.tools, "\n"):find("try", 1, true))

-- ── habit analysis ─────────────────────────────────────────────────────────
local coach = require("skill_arcade.coach")
local log = {}
for _ = 1, 8 do log[#log + 1] = { "j", "n" } end
log[#log + 1] = { "<Up>", "n" }
log[#log + 1] = { "<LeftMouse>", "n" }
local m = coach.metrics(log)
check("metrics: spam/arrows/mouse", m.spam == 4 and m.arrows == 1 and m.mouse == 1 and m.keys == 10, vim.inspect(m))
check("habit tips", #coach.habit_tips(coach.habits(log)) >= 3)

-- ── menu shows REAL keybindings ────────────────────────────────────────────
vim.keymap.set("n", "<leader>Gm", "<cmd>ArcadeMenu<cr>", { desc = "x" })
vim.keymap.set("n", "<leader>zz", "<cmd>ArcadeRun<cr>", { desc = "x" })
local menu = require("skill_arcade.menu")
check("menu hint reads user mapping", menu.hint("menu") == "<leader>Gm", menu.hint("menu"))
check("menu hint maps by rhs", menu.hint("run") == "<leader>zz", menu.hint("run"))
check("menu hint falls back to command", menu.hint("quit") == ":ArcadeQuit", menu.hint("quit"))
check("idle menu items", #menu.items() >= 5)
local lines = menu.render(menu.items())
check("render lists the binding", table.concat(lines, "\n"):find("<leader>zz", 1, true))
local h = menu.open()
check("menu opens as float", vim.api.nvim_win_get_config(h.win).relative == "editor")
vim.api.nvim_win_close(h.win, true)

game.start({ mode = "practice", deck = { catalog.by_id("motions.line-end") }, countdown = 0 })
local labels = {}
for _, it in ipairs(menu.items()) do labels[#labels + 1] = it.action end
check("running menu offers toggle/skip/hint/quit", vim.deep_equal(labels, { "toggle", "skip", "hint", "quit" }), vim.inspect(labels))
game._tick()
local hudwin = require("skill_arcade.ui").hud_win()
check("HUD float exists", hudwin and vim.api.nvim_win_is_valid(hudwin))
local hudtext = table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(hudwin), 0, -1, false), "\n")
check("HUD shows brief and real key", hudtext:find("last character", 1, true) and hudtext:find("<leader>Gm", 1, true), hudtext)
-- control keys are not counted as play keys
local run = game.run
run.cur.log = { { "<Space>", "n" }, { "G", "n" }, { "p", "n" } }
vim.keymap.set("n", "<leader>Gp", function() end, { desc = "SkillArcade toggle" })
game.pause()
check("pause mapping keys discounted from key log", #run.cur.log == 0, #run.cur.log)
quiet_abort()

-- ── generator ──────────────────────────────────────────────────────────────
local gen = require("skill_arcade.generator")
local good = gen.validate({
  title = "t", brief = "b", text = "a b", expect = { text = "a c" }, level = 2, solution = "wcwc<Esc>",
}, "editing")
check("generator accepts valid challenge", good ~= nil)
check("generator rejects already-solved", gen.validate({ title = "t", brief = "b", text = "x", expect = { text = "x" } }, "editing") == nil)
check("generator rejects missing expect", gen.validate({ title = "t", brief = "b", text = "x" }, "editing") == nil)
check("extract_json handles fences", gen.extract_json('```json\n[{"title":"t"}]\n```')[1].title == "t")
check("prompt mentions area and level", gen.build_prompt("macros", 3, 3, env.detect()):find("macros", 1, true))
local saved = store.save_generated(good)
local back = catalog.by_id("editing." .. saved.id)
check("generated challenge joins the catalog", back and back.generated == true)
local p = require("skill_arcade.provider")
local got_err
p.request("x", function(_, err) got_err = err end)
check("provider none explains itself", got_err and got_err:find("none", 1, true))

-- ── community challenges: data-only schema ─────────────────────────────────
local schema = require("skill_arcade.schema")
local validate = require("skill_arcade.validate")
local community = require("skill_arcade.community")

for _, bad in ipairs({
  ":!rm -rf /<CR>", ":lua os.execute('x')<CR>", [[:%s/a/\=system('x')/<CR>]], ":g/a/d | q<CR>",
  "i<C-r>=system('ls')<CR><Esc>", ":w!<CR>", ":e foo<CR>", ":source x<CR>", "",
}) do
  check("unsafe solution rejected: " .. bad, schema.unsafe_solution(bad) ~= nil)
end
for _, good in ipairs({
  'ci"x<Esc>', ":%s/foo/bar/g<CR>", ":g/x/norm A!<CR>", ":'<,'>s/a/b/<CR>", ":1,3d<CR>", ":$m0<CR>",
  ":/foo/s/a/b/<CR>", ":cc 3<CR>", "<C-w>v",
}) do
  check("safe solution accepted: " .. good, schema.unsafe_solution(good) == nil, schema.unsafe_solution(good))
end

local function base()
  return {
    id = "swap-words", title = "Swap two words", area = "editing", level = 2,
    brief = "Make the line read: world hello", text = "hello world", cursor = { 1, 0 },
    solution = "dwA <Esc>p", expect = { text = "world hello" }, why = "dw then paste.", author = "tester",
  }
end
check("schema accepts a valid challenge", schema.validate(base()) ~= nil)
local function mutated(fn)
  local c = base()
  fn(c)
  return select(2, schema.validate(c))
end
check("schema: unknown area", mutated(function(c) c.area = "hacking" end))
check("schema: level out of range", mutated(function(c) c.level = 9 end))
check("schema: bad id", mutated(function(c) c.id = "../../etc" end))
check("schema: missing expect", mutated(function(c) c.expect = nil end))
check("schema: empty expect", mutated(function(c) c.expect = {} end))
check("schema: cursor outside text", mutated(function(c) c.cursor = { 5, 0 } end))
check("schema: too many lines", mutated(function(c) c.text = string.rep("x\n", 50) end))
check("schema: control chars", mutated(function(c) c.title = "a\0b" end))
check("schema: unsafe solution", mutated(function(c) c.solution = ":!ls<CR>" end))
check("schema: unknown preset", mutated(function(c) c.preset = "shell" end))
check("schema: unknown helps group", mutated(function(c) c.helps = { evil = "x" } end))
local extra = base()
extra.check = "os.execute('x')"
extra.setup = "x"
extra.evil = true
local cleaned = schema.validate(extra)
check("schema drops unknown fields (no code can ride along)", cleaned and cleaned.check == nil and cleaned.setup == nil and cleaned.evil == nil)

-- replay in the real engine
check("replay: valid challenge passes", validate.challenge(base()) ~= nil)
local wrong = base()
wrong.solution = "dd"
local _, e1 = validate.challenge(wrong)
check("replay: wrong solution rejected", e1 and e1:find("does not satisfy", 1, true), e1)
local solved = base()
solved.expect = { text = "hello world" }
local _, e2 = validate.challenge(solved)
check("replay: already-solved rejected", e2 and e2:find("already solved", 1, true), e2)
check("replay left no run behind", game.run == nil)

local presets = {
  {
    id = "p-split", title = "Split", area = "windows", level = 1, brief = "Open a vertical split", text = "x",
    solution = "<C-w>v", expect = { windows = 2, layout = "row" }, why = "w",
  },
  {
    id = "p-qf", title = "Third hit", area = "quickfix", level = 2, brief = "Jump to the third hit",
    text = "a\nTODO b\nc\nTODO d\ne\nTODO f", preset = "quickfix_hits", preset_rows = { 2, 4, 6 },
    solution = ":cc 3<CR>", expect = { quickfix = { idx = 3 }, at = { 6, "TODO" } }, why = "w",
  },
  {
    id = "p-diag", title = "Next diagnostic", area = "diagnostics", level = 1, brief = "Go to the first diagnostic",
    text = "a\nb\nc\nd\ne\nf\ng\nh\ni\nj", preset = "diagnostics", preset_rows = { 4, 9 }, solution = "]d",
    expect = { cursor = { 4 } }, why = "w",
  },
  {
    id = "p-alt", title = "Alt buffer", area = "windows", level = 1, brief = "Flip back", text = "A",
    preset = "alt_buffer", solution = "<C-^>", expect = { alt_buffer = true }, why = "w",
  },
  {
    id = "p-tab", title = "New tab", area = "windows", level = 1, brief = "New tab", text = "A",
    solution = ":tabnew<CR>", expect = { extra_tabs = 1 }, why = "w",
  },
  {
    id = "p-float", title = "Diag float", area = "diagnostics", level = 2, brief = "Show the message", text = "a\nb\nc\nd",
    cursor = { 4, 0 }, preset = "diagnostics", preset_rows = { 4 }, solution = "<C-w>d",
    expect = { float_text = "ARC:" }, why = "w",
  },
}
for _, raw in ipairs(presets) do
  local ok, err = validate.challenge(raw)
  check("preset/assertion challenge replays: " .. raw.id, ok ~= nil, err)
end

-- bundle acceptance, storage, load
local bundle = { challenges = { base(), base(), { id = "bad", title = "x" }, presets[1] } }
local clean, rejected = community.accept(bundle)
check("bundle: keeps valid, rejects duplicate + invalid", #clean == 2 and #rejected == 2, vim.inspect(rejected))
vim.fn.mkdir(tmp, "p")
local f = io.open(tmp .. "/community.json", "w")
local tampered = base()
tampered.id = "tampered"
tampered.solution = ":!touch /tmp/pwned<CR>"
f:write(vim.json.encode({ fetched = os.time(), challenges = { base(), tampered } }))
f:close()
local loaded = community.load()
check("load re-validates stored data (tampered file ignored)", #loaded == 1 and loaded[1].id == "community.swap-words")
local cc = catalog.by_id("community.swap-words")
check("community challenge joins catalog", cc and cc.community and cc.area == "editing" and cc.par_keys == 6)
config.setup({ data_dir = tmp, community = { enabled = false } })
check("community can be disabled", catalog.by_id("community.swap-words") == nil)
config.setup({ data_dir = tmp })
-- daily challenges written for one day (date field) replace the built-in daily set; other days fall back
do
  local function day_item(i, level)
    local c = base()
    c.id, c.title, c.level, c.date, c.generated = "daily-" .. i, "Daily " .. i, level, "2026-03-05", true
    return c
  end
  local bad_date = base()
  bad_date.id, bad_date.date = "bad-date", "05/03/2026"
  check("date must be YYYY-MM-DD", schema.validate(bad_date) == nil)
  local dd = vim.fn.tempname()
  vim.fn.mkdir(dd, "p")
  local fh = io.open(dd .. "/community.json", "w")
  fh:write(vim.json.encode({ fetched = os.time(), challenges = { day_item(1, 3), day_item(2, 1), day_item(3, 2), day_item(4, 5) } }))
  fh:close()
  config.setup({ data_dir = dd })
  local today = catalog.build_daily("20260305")
  local ids = vim.tbl_map(function(c) return c.id end, today)
  check("daily uses the challenges written for that day, easiest first",
    #today == 4 and ids[1] == "community.daily-2" and ids[4] == "community.daily-4", vim.inspect(ids))
  local other = catalog.build_daily("20260306")
  check("other days fall back to the built-in set", #other == config.options.daily_length and not other[1].community)
  config.setup({ data_dir = dd, community = { enabled = false } })
  check("daily falls back when community challenges are off", not catalog.build_daily("20260305")[1].community)
  config.setup({ data_dir = tmp })
  vim.fn.delete(dd, "rf")
end
-- AI challenges: the `ai` collection of the bundle, their own section, kept out of normal runs unless opted in
do
  local function ai_item(id, area, level, date)
    local c = base()
    c.id, c.title, c.area, c.level, c.date, c.model, c.prompt = id, "AI " .. id, area, level, date, "model-x", "v1.1:abcdef123456"
    return c
  end
  local human = base()
  human.id, human.title = "human-one", "Human one"
  local bundle = { challenges = { human }, ai = { ai_item("a1", "editing", 1, "2026-03-01"), ai_item("a2", "search", 2, "2026-03-03"), ai_item("a3", "editing", 3, "2026-03-03"), ai_item("human-one", "editing", 1, "2026-03-04") } }
  local clean_h, rejected_ai, clean_ai = community.accept(bundle)
  check("accept splits the ai collection, flags it generated, drops a duplicate id",
    #clean_h == 1 and #clean_ai == 3 and clean_ai[1].generated == true and #rejected_ai == 1, vim.inspect(rejected_ai))
  check("provenance is kept", clean_ai[1].model == "model-x" and clean_ai[1].prompt == "v1.1:abcdef123456")
  local dd = vim.fn.tempname()
  vim.fn.mkdir(dd, "p")
  local fh = io.open(dd .. "/community.json", "w")
  fh:write(vim.json.encode({ fetched = os.time(), challenges = clean_h, ai = clean_ai }))
  fh:close()
  config.setup({ data_dir = dd })
  local list = catalog.ai()
  check("AI list is newest first (date, then id)", #list == 3 and list[1].id == "community.a2" and list[2].id == "community.a3" and list[3].id == "community.a1",
    vim.inspect(vim.tbl_map(function(c) return c.id end, list)))
  check("AI list filters by area and count", #catalog.ai({ area = "editing" }) == 2 and #catalog.ai({ n = 1 }) == 1)
  check("AI challenges keep their model", list[1].model == "model-x")
  local function in_pool(id)
    for _, ch in ipairs(catalog.available()) do
      if ch.id == id then
        return true
      end
    end
    return false
  end
  check("AI challenges stay out of normal runs and practice", not in_pool("community.a1") and in_pool("community.human-one"))
  config.setup({ data_dir = dd, ai = { in_runs = true } })
  check("ai.in_runs puts them back", in_pool("community.a1"))
  config.setup({ data_dir = dd, community = { enabled = false } })
  check("no AI challenges when community is off", #catalog.ai() == 0)
  config.setup({ data_dir = tmp })
  vim.fn.delete(dd, "rf")
end
local sync_err
config.options.community.url = "http://insecure.example/x.json"
community.sync(function(_, err) sync_err = err end)
check("sync refuses non-https", sync_err and sync_err:find("https", 1, true))

-- :ArcadeTry plays a draft file once and saves nothing
check(":ArcadeTry command exists", vim.fn.exists(":ArcadeTry") == 2)
local store = require("skill_arcade.store")
local before = vim.json.encode({ store.profile(), store.bests(), store.history() })
local draft = tmp .. "/my-draft.json" -- file name differs from id on purpose
local df = io.open(draft, "w")
df:write(vim.json.encode(base()))
df:close()
local errs = {}
local real_notify = vim.notify
vim.notify = function(msg) errs[#errs + 1] = msg end
require("skill_arcade").try(tmp .. "/missing.json")
check(":ArcadeTry reports a missing file", errs[1] and errs[1]:find("cannot read", 1, true), errs[1])
local bad_draft = tmp .. "/bad-draft.json"
local bf = io.open(bad_draft, "w")
bf:write(vim.json.encode({ id = "x", title = "x", area = "editing", level = 1, brief = "b", text = "t", solution = ":!ls<CR>", expect = { text = "u" }, why = "w" }))
bf:close()
require("skill_arcade").try(bad_draft)
check(":ArcadeTry refuses an unsafe draft", errs[2] and game.run == nil, errs[2])
vim.notify = real_notify
config.options.countdown = 0
require("skill_arcade").try(draft)
game._tick() -- countdown 0 -> running
check(":ArcadeTry starts a try round", game.run and game.run.try and game.run.mode == "practice" and game.run.state == "running")
check(":ArcadeTry round is not solved at start", not game.evaluate())
keys.feed(base().solution)
game._tick()
check(":ArcadeTry round is won by the keys", game.run and game.run.state == "result" and game.run.results[1].ok)
game.quit()
check(":ArcadeTry leaves no run behind", game.run == nil)
check(":ArcadeTry saves nothing", vim.json.encode({ store.profile(), store.bests(), store.history() }) == before)

-- draft codes (ARC1.<base64url json>) and the clipboard source
local function code_of(tbl)
  local b64 = vim.base64.encode(vim.json.encode(tbl)):gsub("+", "-"):gsub("/", "_"):gsub("=", "")
  return "ARC1." .. b64
end
local code = code_of(base())
local clean_c = validate.read(code)
check("draft code decodes and validates", clean_c and clean_c.id == "swap-words")
local junk = select(2, validate.read("ARC1.@@@not-base64@@@"))
check("damaged draft code is rejected", junk ~= nil)
local unsafe = base()
unsafe.solution = ":!ls<CR>"
check("draft code runs through the safety schema", select(2, validate.read(code_of(unsafe))) ~= nil)
check(":ArcadeJoin command exists", vim.fn.exists(":ArcadeJoin") == 2)
vim.fn.setreg("+", code)
local from_reg = validate.read("+")
check("'+' reads a code from the clipboard register", from_reg == nil or from_reg.id == "swap-words")

-- ── tracks (text-grid maps judged by the end state) ────────────────────────
do
  local function start_track(id)
    game.start({ mode = "practice", deck = { catalog.by_id(id) }, countdown = 0 })
    return game.run
  end
  -- checkpoints are ordered: the goal alone does not count
  start_track("track.ordered-stops")
  keys.feed("fX")
  check("track: goal before the checkpoints does not count", not game.evaluate())
  quiet_abort()
  -- wrong order (2 before 1) does not count either, even after visiting all of them
  start_track("track.ordered-stops")
  keys.feed("f2f1f3fX")
  check("track: checkpoints out of order do not count", not game.evaluate(), game.run.cur.state.cp)
  quiet_abort()
  -- a track is judged on an untouched buffer
  start_track("track.straight-road")
  keys.feed("$x")
  check("track: editing the map breaks the goal", not game.evaluate())
  quiet_abort()
  -- key rules: hjkl are off on grid-run, f and G still work
  local run = start_track("track.grid-run")
  local before_cur = vim.api.nvim_win_get_cursor(0)
  keys.feed("llj")
  check("track: hjkl are blocked when forbidden", vim.deep_equal(vim.api.nvim_win_get_cursor(0), before_cur),
    vim.inspect(vim.api.nvim_win_get_cursor(0)))
  keys.feed("4Gf1")
  check("track: other motions work and count the first checkpoint", game.evaluate() == false and run.cur.state.cp == 1,
    run.cur.state.cp)
  quiet_abort()
  -- the HUD must not cover the map: it sits at the bottom on a track
  start_track("track.straight-road")
  local tw = require("skill_arcade.ui").hud_win()
  local tcfg = tw and vim.api.nvim_win_get_config(tw)
  check("track: HUD sits at the bottom, not over the map", tcfg and tcfg.anchor == "SE", vim.inspect(tcfg and tcfg.anchor))
  quiet_abort()
  -- hjkl stay free on a track that does not forbid them
  start_track("track.straight-road")
  keys.feed("3l")
  check("track: hjkl work when not forbidden", vim.api.nvim_win_get_cursor(0)[2] == 3)
  quiet_abort()

  -- schema
  local function trk()
    return {
      id = "my-track", title = "My track", area = "track", level = 2, brief = "Reach X.", text = "S...X\n.....\n.....",
      cursor = { 1, 0 }, solution = "$", why = "w", track = { goal = { 1, 4 } },
    }
  end
  check("track schema: valid track", schema.validate(trk()) ~= nil, select(2, schema.validate(trk())))
  local t1 = schema.validate(trk())
  check("track schema: expect is derived from the goal", t1 and t1.expect.cursor[1] == 1 and t1.expect.cursor[2] == 4
    and t1.expect.text == t1.text)
  local function bad(fn)
    local c = trk()
    fn(c)
    return select(2, schema.validate(c))
  end
  check("track schema: needs the track object", bad(function(c) c.track = nil end) ~= nil)
  check("track schema: goal outside the map", bad(function(c) c.track.goal = { 9, 0 } end) ~= nil)
  check("track schema: goal column outside the line", bad(function(c) c.track.goal = { 1, 40 } end) ~= nil)
  check("track schema: start equal to goal", bad(function(c) c.track.goal = { 1, 0 } end) ~= nil)
  check("track schema: unknown forbid", bad(function(c) c.track.forbid = { "everything" } end) ~= nil)
  check("track schema: checkpoint equal to goal", bad(function(c) c.track.checkpoints = { { 1, 4 } } end) ~= nil)
  check("track schema: too many checkpoints", bad(function(c)
    c.track.checkpoints = { { 2, 0 }, { 2, 1 }, { 2, 2 }, { 2, 3 }, { 2, 4 }, { 3, 0 }, { 3, 1 } }
  end) ~= nil)
  check("track schema: track data needs area track", bad(function(c)
    c.area = "motions"
    c.expect = { text = "x" }
  end) ~= nil)
  check("track schema: checkpoints and rules accepted", (function()
    local c = trk()
    c.track.checkpoints = { { 2, 2 } }
    c.track.forbid = { "hjkl", "arrows", "mouse" }
    return schema.validate(c) ~= nil
  end)())

  -- a community track replays in the real engine, and an unsolvable one is rejected
  local ok_track = trk()
  check("track replay: reference keys reach the goal", validate.challenge(ok_track) ~= nil,
    select(2, validate.challenge(ok_track)))
  local wrong = trk()
  wrong.solution = "j"
  check("track replay: wrong reference keys are rejected",
    (select(2, validate.challenge(wrong)) or ""):find("does not satisfy", 1, true) ~= nil)
  local skip = trk()
  skip.track.checkpoints = { { 2, 2 } }
  check("track replay: skipping a checkpoint is rejected", validate.challenge(skip) == nil)
  local with_cp = trk()
  with_cp.track.checkpoints = { { 2, 2 } }
  with_cp.solution = "j2lgg$"
  check("track replay: checkpoint then goal", validate.challenge(with_cp) ~= nil, select(2, validate.challenge(with_cp)))

  -- :ArcadeJoin with a track code
  require("skill_arcade").try(code_of(ok_track))
  game._tick()
  check(":ArcadeJoin plays a track draft", game.run and game.run.try and game.run.cur.ch.track ~= nil)
  keys.feed(ok_track.solution)
  check(":ArcadeJoin track is won by the keys", game.evaluate())
  quiet_abort()
end

-- ── packaging ──────────────────────────────────────────────────────────────
local spec = dofile("examples/lazy.lua")
check("lazy example loads", type(spec) == "table" and spec[1][1] == "dev-vinicius-andrade/nvim-skill-arcade")
for _, name in ipairs({ "Arcade", "ArcadeMenu", "ArcadeRun", "ArcadeDaily", "ArcadePractice", "ArcadeQuit", "ArcadeStats", "ArcadeSetup" }) do
  check("command " .. name, vim.fn.exists(":" .. name) == 2)
end

vim.notify = real_notify
vim.fn.delete(tmp, "rf")
print(failures == 0 and "\nALL OK" or ("\n" .. failures .. " FAILURE(S)"))
vim.cmd(failures == 0 and "qa!" or "cq!")
