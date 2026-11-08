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
check("at least 15 built-in challenges", #all >= 15, #all)
local areas = {}
for _, ch in ipairs(all) do
  areas[ch.area] = (areas[ch.area] or 0) + 1
end
check("covers all 11 skill areas", vim.tbl_count(areas) == 11, vim.inspect(areas))
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
