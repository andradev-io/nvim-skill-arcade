-- Game loop: run state machine, key tracking (vim.on_key), arena management, scoring, persistence.
-- States: nil (idle) | "countdown" | "running" | "paused" | "result"
local config = require("skill_arcade.config")
local store = require("skill_arcade.store")
local catalog = require("skill_arcade.catalog")
local scoring = require("skill_arcade.scoring")
local coach = require("skill_arcade.coach")
local keys = require("skill_arcade.keys")
local ui = require("skill_arcade.ui")
local env = require("skill_arcade.env")

local M = {}

M.run = nil

local KEY_NS = vim.api.nvim_create_namespace("skill_arcade_keys")
local DIAG_NS = vim.api.nvim_create_namespace("skill_arcade_diag")
local AUG = "SkillArcade"
local REGISTERS = vim.split('"0123456789abcdefghijklmnopqrstuvwxyz-', "")

local function now()
  return vim.uv.hrtime() / 1e9
end

local function notify(msg, level)
  vim.notify("SkillArcade: " .. msg, level or vim.log.levels.INFO)
end

function M.state()
  return M.run and M.run.state or nil
end

-- ── arena (a dedicated tab with real temp files) ───────────────────────────
local function arena_prefix()
  return vim.fn.fnamemodify(store.arena_dir(), ":p"):gsub("\\", "/")
end

local function arena_buffers()
  local out, prefix = {}, arena_prefix()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(b):gsub("\\", "/")
    if name:sub(1, #prefix) == prefix then
      out[#out + 1] = b
    end
  end
  return out
end

local function lock(v)
  for _, b in ipairs(arena_buffers()) do
    pcall(function() vim.bo[b].modifiable = not v end)
  end
end

local function arena_wins(tab)
  local out = {}
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    if vim.api.nvim_win_get_config(w).relative == "" then
      out[#out + 1] = w
    end
  end
  return out
end

local function safe_name(s)
  return (s:gsub("[^%w%-_]", "_"))
end

local function write_arena_file(name, ext, lines)
  local path = arena_prefix() .. safe_name(name) .. "." .. ext
  vim.fn.writefile(lines, path)
  return path
end

local function extra_tabs(run)
  local out = {}
  for _, t in ipairs(vim.api.nvim_list_tabpages()) do
    if t ~= run.tab and not run.base_tabs[t] then
      out[#out + 1] = t
    end
  end
  return out
end

local function close_extra_tabs(run)
  for _, t in ipairs(extra_tabs(run)) do
    if vim.api.nvim_tabpage_is_valid(t) then
      pcall(vim.cmd, vim.api.nvim_tabpage_get_number(t) .. "tabclose!")
    end
  end
end

local function wipe_arena_buffers()
  for _, b in ipairs(arena_buffers()) do
    pcall(vim.api.nvim_buf_delete, b, { force = true })
  end
  store.clear_arena()
end

--- bring the arena tab back to a single clean window
local function reset_arena(run)
  close_extra_tabs(run)
  vim.api.nvim_set_current_tabpage(run.tab)
  pcall(vim.cmd, "cclose")
  pcall(vim.cmd, "lclose")
  local wins = arena_wins(run.tab)
  local keep = vim.api.nvim_get_current_win()
  if not vim.tbl_contains(wins, keep) or vim.api.nvim_win_get_config(keep).relative ~= "" then
    keep = wins[1]
  end
  for _, w in ipairs(wins) do
    if w ~= keep then
      pcall(vim.api.nvim_win_close, w, true)
    end
  end
  vim.api.nvim_set_current_win(keep)
  run.win = keep
  local tmp = vim.api.nvim_create_buf(false, true)
  vim.bo[tmp].bufhidden = "wipe"
  vim.api.nvim_win_set_buf(keep, tmp)
  wipe_arena_buffers()
  vim.diagnostic.reset(DIAG_NS)
  vim.fn.setqflist({}, "r")
end

-- ── context for checks ─────────────────────────────────────────────────────
local function floats()
  local out = {}
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(w).relative ~= "" and w ~= ui.hud_win() then
      local b = vim.api.nvim_win_get_buf(w)
      out[#out + 1] = { win = w, buf = b, lines = vim.api.nvim_buf_get_lines(b, 0, -1, false) }
    end
  end
  return out
end

function M.make_ctx()
  local run = M.run
  local cur = run.cur
  local cur_buf = vim.api.nvim_get_current_buf()
  local tab = vim.api.nvim_get_current_tabpage()
  local n_extra = #extra_tabs(run)
  local ctx = {
    buf = cur.buf, cur_buf = cur_buf, cur_win = vim.api.nvim_get_current_win(), state = cur.state,
    mode = vim.api.nvim_get_mode().mode,
    in_arena = tab == run.tab,
    wins = #arena_wins(run.tab),
    extra_tabs = n_extra,
    floats = floats(),
    qf = vim.fn.getqflist({ idx = 0, items = 1, size = 0 }),
    lines = vim.api.nvim_buf_is_valid(cur.buf) and vim.api.nvim_buf_get_lines(cur.buf, 0, -1, false) or {},
  }
  if cur_buf == cur.buf then
    ctx.cursor = vim.api.nvim_win_get_cursor(0)
  end
  ctx.mark = function(name)
    if not vim.api.nvim_buf_is_valid(cur.buf) then
      return nil
    end
    local p = vim.api.nvim_buf_get_mark(cur.buf, name)
    return p[1] > 0 and p or nil
  end
  return ctx
end

function M.evaluate()
  local run = M.run
  if not run or not run.cur then
    return false
  end
  local ok, res = pcall(catalog.check, run.cur.ch, M.make_ctx())
  return ok and res or false
end

-- ── key tracking ───────────────────────────────────────────────────────────
local function on_key(_, typed)
  local run = M.run
  if not run or run.state ~= "running" or typed == "" then
    return
  end
  if vim.bo.filetype:match("^skill_arcade") then
    return -- menu / result screens are not the game
  end
  local ok, k = pcall(vim.fn.keytrans, typed)
  if not ok or k == "" or k:find("MouseMove", 1, true) or k:match("^<%x%x>") or k:find("Focus", 1, true) then
    return
  end
  local log = run.cur.log
  if #log < 5000 then
    log[#log + 1] = { k, vim.api.nvim_get_mode().mode }
  end
end

--- drop the keys that triggered a game control (mapping or :ArcadeX) from the key log
local function discount(action)
  local run = M.run
  if not run or not run.cur or run.state ~= "running" then
    return
  end
  local log = run.cur.log
  local lhs = require("skill_arcade.menu").lhs(action)
  if lhs then
    local toks = keys.tokens(vim.fn.keytrans(lhs))
    local n = #toks
    if n > 0 and #log >= n then
      local same = true
      for i = 1, n do
        if log[#log - n + i][1] ~= toks[i] then
          same = false
          break
        end
      end
      if same then
        for _ = 1, n do
          table.remove(log)
        end
        return
      end
    end
  end
  -- typed as :ArcadeSomething<CR>
  if #log > 0 and log[#log][1] == "<CR>" then
    local text = {}
    for i = #log - 1, math.max(1, #log - 40), -1 do
      if log[i][1] == ":" then
        local s = table.concat(vim.tbl_map(function(e) return e[1] end, vim.list_slice(log, i + 1, #log - 1)))
        if s:lower():match("^arcade") then
          for _ = 1, #log - i + 1 do
            table.remove(log)
          end
        end
        return
      end
      text[#text + 1] = log[i][1]
    end
  end
end

-- ── HUD ────────────────────────────────────────────────────────────────────
local function elapsed(cur)
  local e = cur.elapsed
  if cur.t0 then
    e = e + (now() - cur.t0)
  end
  return e
end

local function controls_line()
  local menu = require("skill_arcade.menu")
  return string.format("pause %s | skip %s | hint %s | quit %s | menu %s", menu.hint("toggle"), menu.hint("skip"),
    menu.hint("hint"), menu.hint("quit"), menu.hint("menu"))
end

local function render_hud()
  local run = M.run
  if not run or not run.cur or not config.options.hud then
    return
  end
  local cur, ch = run.cur, run.cur.ch
  local b = ui.builder()
  local lives = run.lives_on and ("   lives " .. run.lives) or ""
  b:add(string.format(" ARCADE %s %d/%d%s   streak %d   score %d", run.label, run.index, #run.deck, lives, run.streak, run.score),
    "Title")
  b:add(string.format(" Lv%d %s - %s%s", ch.level, ch.area, ch.title, ch.generated and "  (model-made)" or ""), "Special")
  b:wrap(ch.brief or "", 62, " ")
  if run.state == "countdown" then
    local left = math.max(0, math.ceil(cur.countdown_end - now()))
    b:add(string.format(" Get ready... %d", left), "WarningMsg")
  elseif run.state == "paused" then
    b:add(" PAUSED - keys locked, clock stopped", "WarningMsg")
  elseif run.state == "result" then
    b:add(" round over - see the result window", "Comment")
  else
    local e = elapsed(cur)
    local left = ch.time_limit - e
    b:add(string.format(" time %s / %s   keys %d (par %d)", scoring.clock(e), scoring.clock(ch.time_limit), #cur.log,
      ch.par_keys), left < 10 and "WarningMsg" or nil)
  end
  if cur.hints > 0 then
    b:wrap("hint: " .. (ch.hint or ""), 62, " ", "DiagnosticHint")
  end
  b:add(" " .. controls_line(), "Comment")
  pcall(ui.hud_show, b)
end

-- ── run lifecycle ──────────────────────────────────────────────────────────
local function snapshot_registers()
  local snap = {}
  for _, r in ipairs(REGISTERS) do
    local ok, info = pcall(vim.fn.getreginfo, r)
    if ok and type(info) == "table" and next(info) then
      snap[r] = info
    end
  end
  return snap
end

local function restore_registers(snap)
  for _, r in ipairs(REGISTERS) do
    if snap[r] then
      pcall(vim.fn.setreg, r, snap[r])
    end
  end
end

local function teardown()
  local run = M.run
  if not run then
    return
  end
  M.run = nil
  if run.timer then
    run.timer:stop()
    run.timer:close()
  end
  vim.on_key(nil, KEY_NS)
  pcall(vim.api.nvim_clear_autocmds, { group = AUG })
  ui.hud_close()
  pcall(function()
    close_extra_tabs(run)
    if vim.api.nvim_tabpage_is_valid(run.origin) then
      vim.api.nvim_set_current_tabpage(run.origin)
    end
    if vim.api.nvim_tabpage_is_valid(run.tab) then
      pcall(vim.cmd, vim.api.nvim_tabpage_get_number(run.tab) .. "tabclose!")
    end
  end)
  pcall(function()
    wipe_arena_buffers()
    vim.diagnostic.reset(DIAG_NS)
    vim.fn.setqflist({}, "r", run.saved.qf)
    restore_registers(run.saved.regs)
    vim.fn.setreg("/", run.saved.search)
  end)
end

local function load_challenge(run)
  local ch = run.deck[run.index]
  reset_arena(run)
  local path = write_arena_file(ch.id, ch.ext, ch.lines)
  vim.api.nvim_set_current_win(run.win)
  vim.cmd("silent noswapfile keepalt edit " .. vim.fn.fnameescape(path))
  local buf = vim.api.nvim_get_current_buf()
  pcall(function()
    vim.bo[buf].undofile = false
    vim.bo[buf].swapfile = false
    vim.bo[buf].bufhidden = "hide"
    if ch.ft ~= "text" then
      vim.bo[buf].filetype = ch.ft
    end
  end)
  pcall(vim.api.nvim_win_set_cursor, run.win, ch.cursor)
  local cur = {
    ch = ch, buf = buf, log = {}, elapsed = 0, t0 = nil, hints = 0, state = {},
    countdown_end = now() + config.options.countdown,
  }
  run.cur = cur
  if ch.setup then
    local x = {
      buf = buf, win = run.win, lines = ch.lines, state = cur.state, diag_ns = DIAG_NS, ch = ch,
      new_buf = function(lines, name)
        local p = write_arena_file(ch.id .. "_" .. name, "txt", lines)
        local b = vim.fn.bufadd(p)
        vim.fn.bufload(b)
        vim.bo[b].buflisted = true
        vim.bo[b].swapfile = false
        return b
      end,
    }
    local ok, err = pcall(ch.setup, x)
    if not ok then
      notify("challenge setup failed: " .. tostring(err), vim.log.levels.ERROR)
    end
  end
  run.state = "countdown"
  lock(true)
end

local function begin_play()
  local run = M.run
  run.state = "running"
  run.cur.t0 = now()
  run.cur.log = {}
  lock(false)
  render_hud()
end

local function save_area_stats(p, ch, ok)
  local a = p.areas[ch.area] or { seen = 0, cleared = 0 }
  a.seen = a.seen + 1
  a.cleared = a.cleared + (ok and 1 or 0)
  p.areas[ch.area] = a
end

local function plugin_group(ch)
  if ch.needs then
    return ch.needs
  end
  local names = vim.tbl_keys(ch.helps or {})
  table.sort(names)
  return names[1]
end

local function toolbelt(ch, envinfo, keys_used)
  if not ch.plugin_par or keys_used > ch.plugin_par or ch.plugin_par >= ch.par_keys then
    return false
  end
  local g = plugin_group(ch)
  return (g and envinfo.groups[g] ~= nil) or (g == "comment" and envinfo.native.comment) or false
end

local function finish_challenge(ok, reason)
  local run = M.run
  local cur, ch = run.cur, run.cur.ch
  local secs = elapsed(cur)
  cur.elapsed, cur.t0 = secs, nil
  run.state = "result"
  lock(true)
  local m = coach.metrics(cur.log)
  local envinfo = env.detect()
  local r = {
    ch = ch, ok = ok, reason = reason, keys = m.keys, seconds = secs, log = cur.log,
    habits = coach.habits(cur.log), streak = 0, points = 0,
  }
  local p, bests = store.profile(), store.bests()
  if ok then
    r.score = scoring.score(ch, {
      keys = math.max(1, m.keys), seconds = secs, hints = cur.hints, spam = m.spam, arrows = m.arrows,
      mouse = m.mouse, streak = run.streak, toolbelt = toolbelt(ch, envinfo, m.keys),
    })
    r.rank = r.score.rank
    r.points = r.score.total
    run.score = run.score + r.points
    run.streak = run.streak + 1
    run.best_streak = math.max(run.best_streak, run.streak)
    r.streak = run.streak
    p.clears = p.clears + 1
    local b = bests.challenges[ch.id] or { plays = 0, clears = 0, score = 0 }
    r.records = {}
    if r.points > b.score then
      r.records[#r.records + 1] = string.format("score %d%s", r.points, b.score > 0 and (" (was " .. b.score .. ")") or "")
    end
    if not b.keys or m.keys < b.keys then
      b.keys = m.keys
      if b.clears > 0 then
        r.records[#r.records + 1] = "fewest keys: " .. m.keys
      end
    end
    if not b.seconds or secs < b.seconds then
      b.seconds = secs
    end
    b.score = math.max(b.score, r.points)
    local order = { S = 1, A = 2, B = 3, C = 4 }
    if not b.rank or order[r.rank] < order[b.rank] then
      b.rank = r.rank
    end
    b.clears = b.clears + 1
    b.plays = b.plays + 1
    bests.challenges[ch.id] = b
  else
    run.streak = 0
    if reason == "time" and run.lives_on then
      run.lives = run.lives - 1
    end
    local b = bests.challenges[ch.id] or { plays = 0, clears = 0, score = 0 }
    b.plays = b.plays + 1
    bests.challenges[ch.id] = b
  end
  if not run.try then -- :ArcadeTry rounds never touch the saved profile or bests
    save_area_stats(p, ch, ok)
    for k, v in pairs(r.habits) do
      p.habits[k] = (p.habits[k] or 0) + v
    end
    store.save_profile(p)
    store.save_bests(bests)
  end
  run.results[#run.results + 1] = r
  run.keys = run.keys + m.keys
  render_hud()
  local lesson = coach.lesson(ch, r, envinfo)
  r.lesson = lesson
  local on_retry
  if run.mode == "practice" then
    on_retry = function() M.retry() end
  end
  run.result_ui = ui.result(r, lesson, run, function() M.next() end, function() M.quit() end, on_retry)
  return r
end

local function tick()
  local run = M.run
  if not run then
    return
  end
  if not vim.api.nvim_tabpage_is_valid(run.tab) then
    return M.abort("the arena tab was closed")
  end
  if run.state == "countdown" then
    if now() >= run.cur.countdown_end then
      begin_play()
    end
  elseif run.state == "running" then
    if elapsed(run.cur) > run.cur.ch.time_limit then
      return finish_challenge(false, "time")
    end
    if M.evaluate() then
      return finish_challenge(true)
    end
  end
  render_hud()
end
M._tick = tick

local function run_label(mode)
  return ({ run = "run", daily = "daily", practice = "practice" })[mode] or mode
end

--- opts: { mode = "run"|"daily"|"practice", deck = {challenges}, countdown? }
function M.start(opts)
  if M.run then
    return notify("a run is active - quit it first", vim.log.levels.WARN)
  end
  if not opts.deck or #opts.deck == 0 then
    return notify("no challenges available for that selection", vim.log.levels.WARN)
  end
  local origin = vim.api.nvim_get_current_tabpage()
  local base = {}
  for _, t in ipairs(vim.api.nvim_list_tabpages()) do
    base[t] = true
  end
  local saved = {
    regs = snapshot_registers(), qf = vim.fn.getqflist({ all = 1 }), search = vim.fn.getreg("/"),
  }
  vim.cmd("tabnew")
  local run = {
    mode = opts.mode or "run", label = run_label(opts.mode or "run"), deck = opts.deck, index = 1,
    lives_on = (opts.mode ~= "practice") and (config.options.lives or 0) > 0,
    lives = config.options.lives, score = 0, streak = 0, best_streak = 0, results = {}, keys = 0,
    state = nil, tab = vim.api.nvim_get_current_tabpage(), win = vim.api.nvim_get_current_win(),
    origin = origin, base_tabs = base, saved = saved, started = os.time(), clock0 = now(),
    level_from = store.profile().level, try = opts.try or nil,
  }
  M.run = run
  vim.on_key(on_key, KEY_NS)
  run.timer = vim.uv.new_timer()
  run.timer:start(100, 100, vim.schedule_wrap(function()
    local ok, err = pcall(tick)
    if not ok then
      vim.notify("SkillArcade tick failed: " .. tostring(err), vim.log.levels.ERROR)
    end
  end))
  local g = vim.api.nvim_create_augroup(AUG, { clear = true })
  vim.api.nvim_create_autocmd({ "TabEnter", "VimResized" }, { group = g, callback = function() render_hud() end })
  load_challenge(run)
  if opts.countdown ~= nil then
    run.cur.countdown_end = now() + opts.countdown
  end
  if opts.countdown == 0 then
    begin_play()
  end
  render_hud()
  return run
end

local function summarize(run, reason)
  local p = store.profile()
  local cleared = 0
  for _, r in ipairs(run.results) do
    if r.ok then
      cleared = cleared + 1
    end
  end
  local game_over = run.lives_on and run.lives <= 0
  local total = #run.deck
  local s = {
    mode_label = run.label, score = run.score, cleared = cleared, total = total, best_streak = run.best_streak,
    seconds = now() - run.clock0, keys = run.keys, results = run.results, level_from = p.level,
    grade = scoring.grade(run.results), tips = {},
  }
  s.grade_hl = (s.grade == "S" or s.grade == "A") and "DiagnosticOk" or "WarningMsg"
  local lvl = p.level
  if run.mode == "run" and reason ~= "quit" then
    lvl = scoring.next_level(p.level, cleared, total, game_over)
  end
  s.level_to, s.level_change = lvl, lvl - p.level
  -- aggregate habits of this run into tips
  local agg = {}
  for _, r in ipairs(run.results) do
    for k, v in pairs(r.habits) do
      agg[k] = (agg[k] or 0) + v
    end
  end
  s.tips = coach.habit_tips(agg)
  local bests = store.bests()
  if run.mode == "run" then
    if run.score > (bests.run or 0) then
      bests.run, s.new_best = run.score, true
    end
  elseif run.mode == "daily" then
    local d = os.date("%Y%m%d")
    if run.score > (bests.daily[d] or 0) then
      bests.daily[d], s.new_best = run.score, true
    end
  end
  p.points = p.points + run.score
  p.runs = p.runs + 1
  p.level = lvl
  store.save_profile(p)
  store.save_bests(bests)
  store.push_history({
    time = os.time(), mode = run.mode, score = run.score, cleared = cleared, total = total, grade = s.grade,
    quit = reason == "quit" or nil,
  })
  return s
end

local function finish_run(reason)
  local run = M.run
  if not run then
    return
  end
  local s = (#run.results > 0 and not run.try) and summarize(run, reason) or nil
  teardown()
  if s then
    ui.summary(s)
  end
end

function M.next()
  local run = M.run
  if not run or run.state ~= "result" then
    return
  end
  if run.result_ui then
    pcall(run.result_ui.close)
    run.result_ui = nil
  end
  if run.index >= #run.deck and run.mode ~= "practice" or (run.lives_on and run.lives <= 0) then
    return finish_run("done")
  end
  if run.mode == "practice" and run.index >= #run.deck then
    return finish_run("done")
  end
  run.index = run.index + 1
  load_challenge(run)
  render_hud()
end

function M.retry()
  local run = M.run
  if not run or run.state ~= "result" then
    return
  end
  if run.result_ui then
    pcall(run.result_ui.close)
    run.result_ui = nil
  end
  load_challenge(run)
  render_hud()
end

function M.pause()
  local run = M.run
  if not run or run.state ~= "running" then
    return
  end
  discount("toggle")
  run.cur.elapsed = elapsed(run.cur)
  run.cur.t0 = nil
  run.state = "paused"
  lock(true)
  render_hud()
end

function M.play()
  local run = M.run
  if not run then
    return
  end
  if run.state == "paused" then
    run.cur.t0 = now()
    run.state = "running"
    lock(false)
    render_hud()
  elseif run.state == "result" then
    M.next()
  end
end

function M.toggle()
  if M.state() == "paused" then
    M.play()
  else
    M.pause()
  end
end

function M.skip()
  local run = M.run
  if not run or (run.state ~= "running" and run.state ~= "paused" and run.state ~= "countdown") then
    return
  end
  discount("skip")
  if run.state == "countdown" then
    begin_play()
  end
  finish_challenge(false, "skipped")
end

function M.hint()
  local run = M.run
  if not run or run.state ~= "running" then
    return
  end
  discount("hint")
  run.cur.hints = run.cur.hints + 1
  render_hud()
end

function M.quit()
  local run = M.run
  if not run then
    return
  end
  if run.result_ui then
    pcall(run.result_ui.close)
  end
  finish_run("quit")
end

--- stop without scoring (errors, closed tab)
function M.abort(reason)
  teardown()
  notify("run aborted: " .. (reason or "unknown"), vim.log.levels.WARN)
end

return M
