-- Floating windows: HUD, result screen, run summary, stats, setup report.
local scoring = require("skill_arcade.scoring")

local M = {}

local NS = vim.api.nvim_create_namespace("skill_arcade_ui")

-- ── tiny line builder ──────────────────────────────────────────────────────
local B = {}
B.__index = B

function M.builder()
  return setmetatable({ lines = {}, spans = {} }, B)
end

function B:add(text, hl)
  self.lines[#self.lines + 1] = text
  if hl then
    self.spans[#self.spans + 1] = { #self.lines - 1, 0, -1, hl }
  end
  return self
end

--- highlight a part of the last added line
function B:mark(from, to, hl)
  self.spans[#self.spans + 1] = { #self.lines - 1, from, to, hl }
  return self
end

function B:wrap(text, width, indent, hl)
  indent = indent or ""
  local line = indent
  for word in text:gmatch("%S+") do
    if #line + #word + 1 > width and #line > #indent then
      self:add(line, hl)
      line = indent .. word
    else
      line = (line == indent) and (line .. word) or (line .. " " .. word)
    end
  end
  if #line > #indent then
    self:add(line, hl)
  end
  return self
end

local function apply(buf, b)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, b.lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
  for _, sp in ipairs(b.spans) do
    local line = b.lines[sp[1] + 1] or ""
    pcall(vim.api.nvim_buf_set_extmark, buf, NS, sp[1], sp[2], {
      end_row = sp[1], end_col = sp[3] >= 0 and sp[3] or #line, hl_group = sp[4],
    })
  end
end

local function widest(lines, min)
  local w = min or 0
  for _, l in ipairs(lines) do
    w = math.max(w, vim.fn.strdisplaywidth(l))
  end
  return w
end

-- ── generic centered float ─────────────────────────────────────────────────
--- o: { title, keys = { lhs = fn }, min_width, on_close }
--- returns { win, buf, close }
function M.float(b, o)
  o = o or {}
  local prev = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "skill_arcade"
  apply(buf, b)
  local width = math.min(widest(b.lines, o.min_width or 40) + 2, math.max(20, vim.o.columns - 6))
  local height = math.min(#b.lines, math.max(5, vim.o.lines - 6))
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", style = "minimal", border = "rounded",
    title = o.title and (" " .. o.title .. " ") or nil, title_pos = "center",
    width = width, height = height,
    row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
  })
  vim.wo[win].wrap = true
  local closed = false
  local function close()
    if closed then
      return
    end
    closed = true
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
    if vim.api.nvim_win_is_valid(prev) then
      pcall(vim.api.nvim_set_current_win, prev)
    end
    if o.on_close then
      o.on_close()
    end
  end
  local function map(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true })
  end
  for lhs, fn in pairs(o.keys or {}) do
    map(lhs, function()
      close()
      vim.schedule(fn)
    end)
  end
  for _, lhs in ipairs({ "q", "<Esc>" }) do
    if not (o.keys and o.keys[lhs]) then
      map(lhs, close)
    end
  end
  vim.api.nvim_create_autocmd("WinLeave", { buffer = buf, once = true, callback = close })
  return { win = win, buf = buf, close = close }
end

-- ── HUD ────────────────────────────────────────────────────────────────────
local hud = { buf = nil, win = nil, text = nil }

function M.hud_close()
  if hud.win and vim.api.nvim_win_is_valid(hud.win) then
    pcall(vim.api.nvim_win_close, hud.win, true)
  end
  if hud.buf and vim.api.nvim_buf_is_valid(hud.buf) then
    pcall(vim.api.nvim_buf_delete, hud.buf, { force = true })
  end
  hud.buf, hud.win, hud.text = nil, nil, nil
end

function M.hud_win()
  return hud.win
end

function M.hud_show(b)
  local sig = (b.bottom and "B" or "T") .. table.concat(b.lines, "\n")
  local in_tab = hud.win and vim.api.nvim_win_is_valid(hud.win)
    and vim.api.nvim_win_get_tabpage(hud.win) == vim.api.nvim_get_current_tabpage()
  if sig == hud.text and in_tab then
    return
  end
  hud.text = sig
  if not (hud.buf and vim.api.nvim_buf_is_valid(hud.buf)) then
    hud.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[hud.buf].bufhidden = "hide"
    vim.bo[hud.buf].filetype = "skill_arcade_hud"
  end
  apply(hud.buf, b)
  local width = math.min(widest(b.lines, 44) + 1, math.max(30, vim.o.columns - 4))
  local cfg = {
    relative = "editor", anchor = "NE", row = 1, col = vim.o.columns - 1,
    width = width, height = #b.lines,
  }
  if b.bottom then
    -- the buffer is the playing field (track maps): keep the top free, sit just above the status/command line
    cfg.anchor = "SE"
    cfg.row = vim.o.lines - vim.o.cmdheight - (vim.o.laststatus > 0 and 1 or 0)
  end
  if in_tab then
    vim.api.nvim_win_set_config(hud.win, cfg)
  else
    if hud.win and vim.api.nvim_win_is_valid(hud.win) then
      pcall(vim.api.nvim_win_close, hud.win, true)
    end
    cfg.style, cfg.border, cfg.focusable, cfg.zindex, cfg.noautocmd = "minimal", "rounded", false, 40, true
    hud.win = vim.api.nvim_open_win(hud.buf, false, cfg)
    vim.wo[hud.win].wrap = false
  end
end

-- ── screens ────────────────────────────────────────────────────────────────
local function key(action)
  return require("skill_arcade.menu").hint(action)
end

local function rank_hl(rank)
  return (rank == "S" or rank == "A") and "DiagnosticOk" or (rank == "B" and "DiagnosticWarn" or "DiagnosticError")
end

--- r: result table from game.finish_challenge, lesson from coach.lesson
function M.result(r, lesson, run, on_next, on_quit, on_retry)
  local b = M.builder()
  local ch = r.ch
  if r.ok then
    b:add(string.format(" CLEARED  %s", ch.title), "DiagnosticOk")
    local s = r.score
    b:add(string.format(" rank %s    +%d points%s", s.rank, s.total, r.streak > 0 and ("    streak x" .. r.streak) or ""),
      rank_hl(s.rank))
    b:add(string.format(" keys %d (par %d)   time %s (par %s)", r.keys, ch.par_keys, scoring.clock(r.seconds),
      scoring.clock(ch.par_seconds)))
    if r.stars then
      b:add(string.format(" stars %s   (%d keys or fewer for three)", require("skill_arcade.campaign").stars_text(r.stars),
        ch.par_keys), "Special")
    end
    if r.note then
      b:add(" " .. r.note, "DiagnosticOk")
    end
    local parts = { "base " .. s.base }
    if s.key_bonus > 0 then parts[#parts + 1] = "keys +" .. s.key_bonus end
    if s.time_bonus > 0 then parts[#parts + 1] = "time +" .. s.time_bonus end
    if s.tool_bonus > 0 then parts[#parts + 1] = "toolbelt +" .. s.tool_bonus end
    if s.habit > 0 then parts[#parts + 1] = "habits -" .. s.habit end
    if s.hint > 0 then parts[#parts + 1] = "hints -" .. s.hint end
    if s.mult > 1 then parts[#parts + 1] = string.format("streak x%.1f", s.mult) end
    b:add(" " .. table.concat(parts, "   "), "Comment")
    for _, rec in ipairs(r.records or {}) do
      b:add(" NEW BEST: " .. rec, "Special")
    end
    if s.tool_bonus > 0 then
      b:add(" Toolbelt bonus: you beat the native par - your plugins paid off.", "Special")
    end
  else
    local why = r.reason == "time" and "TIME UP" or "SKIPPED"
    b:add(string.format(" %s  %s", why, ch.title), "DiagnosticError")
    if r.reason == "time" and run.lives_on then
      b:add(string.format(" lost a life - %d left", run.lives), "WarningMsg")
    end
  end
  b:add("")
  if lesson.better then
    b:add(string.format(" A better way (%d keys):", lesson.better_keys or 0), "Title")
    b:add("   " .. lesson.better, "String")
  end
  if lesson.why then
    b:wrap(lesson.why, 74, "   ", "Comment")
  end
  for _, t in ipairs(lesson.tools) do
    b:add("")
    b:wrap(t, 74, " > ", "Identifier")
  end
  if #lesson.habits > 0 then
    b:add("")
    b:add(" Habits spotted:", "WarningMsg")
    for _, h in ipairs(lesson.habits) do
      b:wrap(h, 74, "   - ")
    end
  end
  if lesson.typed ~= "" then
    b:add("")
    b:add(" You typed: " .. lesson.typed, "Comment")
  end
  b:add("")
  local nextlabel = (run.index >= #run.deck or (run.lives_on and run.lives <= 0)) and "see summary"
    or (run.mode == "campaign" and (r.ok and "next stage" or "try the stage again") or "next challenge")
  local footer = string.format(" <CR> %s    q quit run", nextlabel)
  if on_retry then
    footer = footer .. "    r retry"
  end
  b:add(footer, "Special")
  b:add(string.format(" any time: menu %s   next %s", key("menu"), key("next")), "Comment")
  local keys = { ["<CR>"] = on_next, ["q"] = on_quit, ["<Esc>"] = function() end }
  if on_retry then
    keys["r"] = on_retry
  end
  return M.float(b, { title = r.ok and "Cleared" or "Missed", keys = keys, min_width = 60 })
end

function M.summary(s)
  local b = M.builder()
  b:add(string.format(" %s over - grade %s", s.mode_label, s.grade), s.grade_hl)
  b:add(string.format(" score %d   cleared %d/%d   best streak %d", s.score, s.cleared, s.total, s.best_streak))
  b:add(string.format(" time %s   keys %d", scoring.clock(s.seconds), s.keys))
  if s.new_best then
    b:add(" NEW PERSONAL BEST for this mode!", "Special")
  end
  if s.level_change ~= 0 then
    b:add(string.format(" Difficulty %s: level %d -> %d", s.level_change > 0 and "up" or "down", s.level_from, s.level_to),
      s.level_change > 0 and "DiagnosticOk" or "WarningMsg")
  else
    b:add(string.format(" Level stays at %d (clear 80%% without game over to level up)", s.level_to), "Comment")
  end
  b:add("")
  for _, r in ipairs(s.results) do
    local mark = r.ok and ("[" .. r.rank .. "]") or (r.reason == "time" and "[X]" or "[-]")
    b:add(string.format("  %s %-28s %3d keys  %s  %+d", mark, r.ch.title, r.keys, scoring.clock(r.seconds), r.points or 0),
      r.ok and nil or "Comment")
  end
  if #s.tips > 0 then
    b:add("")
    b:add(" Work on:", "WarningMsg")
    for _, t in ipairs(s.tips) do
      b:wrap(t, 72, "   - ")
    end
  end
  b:add("")
  b:add(string.format(" play again: %s   menu: %s   stats: %s", key("run"), key("menu"), key("stats")), "Comment")
  return M.float(b, { title = "Run summary", min_width = 60 })
end

function M.stats(p, bests, history, areas_all)
  local b = M.builder()
  b:add(string.format(" level %d   points %d   runs %d   challenges cleared %d", p.level, p.points, p.runs, p.clears), "Title")
  b:add(string.format(" best run %d", bests.run or 0), "Special")
  local today = os.date("%Y%m%d")
  if bests.daily[today] then
    b:add(" today's daily: " .. bests.daily[today], "Special")
  end
  b:add("")
  b:add(" Skill by area (weakest first):", "Title")
  local rows = {}
  for _, a in ipairs(areas_all) do
    local s = p.areas[a]
    if s and s.seen > 0 then
      rows[#rows + 1] = { a = a, rate = s.cleared / s.seen, seen = s.seen }
    end
  end
  table.sort(rows, function(x, y) return x.rate < y.rate end)
  if #rows == 0 then
    b:add("   nothing played yet - start a run!", "Comment")
  end
  for _, r in ipairs(rows) do
    local bar = string.rep("#", math.floor(r.rate * 10)) .. string.rep(".", 10 - math.floor(r.rate * 10))
    b:add(string.format("   %-12s %s %3d%%  (%d played)", r.a, bar, math.floor(r.rate * 100), r.seen))
  end
  local list = {}
  for id, v in pairs(bests.challenges) do
    list[#list + 1] = { id = id, v = v }
  end
  table.sort(list, function(x, y) return x.v.score > y.v.score end)
  b:add("")
  b:add(" Personal bests (top 8):", "Title")
  for i = 1, math.min(8, #list) do
    local it = list[i]
    b:add(string.format("   %-26s %4d pts  %2d keys  %s  [%s]", it.id, it.v.score, it.v.keys, scoring.clock(it.v.seconds),
      it.v.rank))
  end
  if #list == 0 then
    b:add("   none yet", "Comment")
  end
  b:add("")
  b:add(" Recent runs:", "Title")
  for i = #history, math.max(1, #history - 4), -1 do
    local h = history[i]
    b:add(string.format("   %s  %-8s score %4d  %d/%d  %s", os.date("%m-%d %H:%M", h.time), h.mode, h.score, h.cleared,
      h.total, h.grade))
  end
  if #history == 0 then
    b:add("   none yet", "Comment")
  end
  return M.float(b, { title = "Arcade stats", min_width = 56 })
end

--- what the game found in the player's setup
function M.setup_report(envinfo, areas)
  local envmod = require("skill_arcade.env")
  local b = M.builder()
  b:add(string.format(" Neovim %s   LSP clients attached: %d   plugin manager: %s", envinfo.nvim, envinfo.lsp,
    envinfo.lazy and "lazy.nvim" or "unknown"), "Title")
  b:add("")
  b:add(" Found in your setup:", "Title")
  local names = vim.tbl_keys(envinfo.plugins)
  table.sort(names)
  if #names == 0 then
    b:add("   no known plugins detected (built-in Neovim only - the game works fine that way)", "Comment")
  end
  for _, id in ipairs(names) do
    local p = envinfo.plugins[id]
    b:add(string.format("   %-28s %-14s %s", p.label, p.group, p.keys and ("keys: " .. p.keys) or ""))
  end
  b:add("")
  b:add(" Not found (suggestions, optional):", "Title")
  local missing = {}
  for g, info in pairs(envmod.groups) do
    if not envinfo.groups[g] then
      missing[#missing + 1] = string.format("   %-12s %s", g, info.suggest)
    end
  end
  table.sort(missing)
  for _, l in ipairs(missing) do
    b:add(l, "Comment")
  end
  b:add("")
  b:add(" Challenge areas on offer: " .. table.concat(areas, ", "))
  b:add(" Plugin-featured challenges appear only for groups you have; every one stays solvable natively.", "Comment")
  return M.float(b, { title = "Your setup", min_width = 60 })
end

return M
