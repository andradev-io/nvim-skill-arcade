-- State-aware floating menu. Shows only what is valid right now, with the player's REAL keybindings.
local game = require("skill_arcade.game")

local M = {}

local NS = vim.api.nvim_create_namespace("skill_arcade_menu")

local COMMANDS = {
  menu = "ArcadeMenu", campaign = "ArcadeCampaign", run = "ArcadeRun", daily = "ArcadeDaily", practice = "ArcadePractice",
  toggle = "ArcadeToggle", skip = "ArcadeSkip", hint = "ArcadeHint", next = "ArcadeNext", retry = "ArcadeRetry",
  quit = "ArcadeQuit", stats = "ArcadeStats", setup = "ArcadeSetup", generate = "ArcadeGenerate", sync = "ArcadeSync", ai = "ArcadeAI", login = "ArcadeLogin", account = "ArcadeAccount",
}

local function api()
  return require("skill_arcade")
end

local function normalize_rhs(rhs)
  rhs = (rhs or ""):lower():gsub("^<cmd>", ""):gsub("^:", ""):gsub("<cr>$", ""):gsub("%s+$", "")
  return rhs
end

--- "<Space>Gm" / " Gm" -> "<leader>Gm"
local function display_lhs(lhs)
  local leader = vim.g.mapleader or "\\"
  for _, prefix in ipairs({ leader == " " and "<Space>" or leader, leader }) do
    if prefix ~= "" and lhs:sub(1, #prefix) == prefix then
      return "<leader>" .. lhs:sub(#prefix + 1)
    end
  end
  return lhs
end

--- { by_cmd = {normalized cmd -> raw lhs}, by_action = {action -> raw lhs} } from global normal-mode maps
function M.mappings()
  local by_cmd, by_action = {}, {}
  for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
    if m.rhs and m.rhs ~= "" then
      local k = normalize_rhs(m.rhs)
      by_cmd[k] = by_cmd[k] or m.lhs
    end
    local action = (m.desc or ""):match("^SkillArcade (%S+)$")
    if action then
      by_action[action] = by_action[action] or m.lhs
    end
  end
  return { by_cmd = by_cmd, by_action = by_action }
end

--- raw key notation mapped to `action`, or nil
function M.lhs(action, maps)
  maps = maps or M.mappings()
  local cmd = COMMANDS[action]
  return (cmd and maps.by_cmd[cmd:lower()]) or maps.by_action[action]
end

--- what to show the player: their key, or the command
function M.hint(action, maps)
  local lhs = M.lhs(action, maps)
  if lhs then
    return display_lhs(lhs)
  end
  return ":" .. (COMMANDS[action] or action)
end

--- items for the current state: { key, label, action, run }
function M.items()
  local function item(key, label, action, run)
    return { key = key, label = label, action = action, cmd = COMMANDS[action], run = run }
  end
  local st = game.state()
  local a = api()
  if not st then
    local rows = {
      item("c", "Campaign: learn Vim step by step", "campaign", function() a.campaign() end),
      item("g", "Start a run (difficulty ramps up)", "run", function() a.run() end),
      item("d", "Daily challenge (same for everyone)", "daily", function() a.daily() end),
      item("r", "Practice an area (no lives)", "practice", function() a.practice() end),
      item("i", "AI challenges (model-written)", "ai", function() a.ai() end),
      item("t", "Stats and personal bests", "stats", function() a.stats() end),
      item("e", "What the game found in my setup", "setup", function() a.setup_report() end),
      item("y", "Sync community challenges", "sync", function() a.sync() end),
      require("skill_arcade.account").logged_in()
          and item("o", "Leaderboard account", "account", function() a.account() end)
        or item("o", "Sign in to send scores (optional)", "login", function() a.login() end),
    }
    if require("skill_arcade.config").options.provider ~= "none" then
      rows[#rows + 1] = item("n", "Generate new challenges (model)", "generate", function() a.generate() end)
    end
    return rows
  elseif st == "paused" then
    return {
      item("p", "Resume", "toggle", function() a.toggle() end),
      item("x", "Quit run", "quit", function() a.quit() end),
    }
  elseif st == "result" then
    local rows = { item("n", "Next challenge", "next", function() a.next() end) }
    if game.can_retry() then
      rows[#rows + 1] = item("r", "Retry this challenge", "retry", function() a.retry() end)
    end
    rows[#rows + 1] = item("x", "Quit run", "quit", function() a.quit() end)
    return rows
  end
  local rows = { -- countdown / running
    item("p", "Pause", "toggle", function() a.toggle() end),
    item("s", "Skip (no points, streak resets)", "skip", function() a.skip() end),
    item("h", "Hint (costs points)", "hint", function() a.hint() end),
  }
  if game.can_retry() then
    rows[#rows + 1] = item("r", "Retry this challenge", "retry", function() a.retry() end)
  end
  rows[#rows + 1] = item("x", "Quit run", "quit", function() a.quit() end)
  return rows
end

local function title()
  local run = game.run
  if not run then
    return " Skill Arcade "
  end
  return string.format(" Skill Arcade - %s %d/%d  score %d ", run.state, run.index, #run.deck, run.score)
end

function M.render(items)
  local maps = M.mappings()
  local label_w, bind_w, rows, any = 0, 0, {}, false
  for _, it in ipairs(items) do
    local lhs = M.lhs(it.action, maps)
    local b = lhs and display_lhs(lhs) or "-"
    any = any or lhs ~= nil
    rows[#rows + 1] = { it = it, bind = b }
    label_w = math.max(label_w, vim.fn.strdisplaywidth(it.label))
    bind_w = math.max(bind_w, vim.fn.strdisplaywidth(b))
  end
  local lines, spans = {}, {}
  local function span(row, from, to, hl)
    spans[#spans + 1] = { row - 1, from, to, hl }
  end
  lines[1] = string.format("  %-3s %-" .. label_w .. "s  %-" .. bind_w .. "s  %s", "key", "action", "mapped to", "command")
  span(1, 0, -1, "Comment")
  for _, r in ipairs(rows) do
    lines[#lines + 1] = string.format("  %-3s %-" .. label_w .. "s  %-" .. bind_w .. "s  :%s", r.it.key, r.it.label,
      r.bind, r.it.cmd)
    local row = #lines
    span(row, 2, 3, "Special")
    local bstart = 2 + 3 + 1 + label_w + 2
    span(row, bstart, bstart + #r.bind, r.bind == "-" and "Comment" or "Identifier")
    span(row, bstart + bind_w + 2, -1, "Comment")
  end
  local n_items = #lines
  local help = {
    "",
    "  How to use this menu:",
    "  - press the letter in the first column, or j/k + Enter",
    "  - q or Esc closes it without doing anything",
    "  - \"mapped to\" is the key that does the same without the menu",
    "  - reopen this menu: " .. M.hint("menu", maps),
  }
  local st = game.state()
  if st == "running" or st == "countdown" then
    help[#help + 1] = "  - the goal is checked automatically: just reach the end state, any way you like"
  elseif not st then
    help[#help + 1] = "  - use your own keys and plugins; only the end result counts"
  end
  local tip, habit = require("skill_arcade.coach").pick_tip(require("skill_arcade.store").profile().habits)
  help[#help + 1] = ""
  help[#help + 1] = (habit and "  Tip for your habits: " or "  Tip: ") .. tip
  if not any then
    help[#help + 1] = "  - no keys mapped yet: add `keys = {...}` to your plugin spec (see README)"
  end
  for _, h in ipairs(help) do
    lines[#lines + 1] = h
    span(#lines, 0, -1, "Comment")
  end
  local width = vim.fn.strdisplaywidth(title())
  for _, l in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l) + 2)
  end
  return lines, spans, math.min(width, vim.o.columns - 4), n_items
end

function M.open()
  local items = M.items()
  local prev = vim.api.nvim_get_current_win()
  local lines, spans, width, n_items = M.render(items)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "skill_arcade_menu"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  for _, sp in ipairs(spans) do
    pcall(vim.api.nvim_buf_set_extmark, buf, NS, sp[1], sp[2], {
      end_row = sp[1], end_col = sp[3] >= 0 and sp[3] or #lines[sp[1] + 1], hl_group = sp[4],
    })
  end
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", style = "minimal", border = "rounded", title = title(), title_pos = "center",
    width = width, height = #lines,
    row = math.max(0, math.floor((vim.o.lines - #lines) / 2) - 1),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
  })
  vim.wo[win].cursorline = true
  vim.wo[win].winhighlight = "CursorLine:PmenuSel"
  vim.api.nvim_win_set_cursor(win, { 2, 0 })
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = buf,
    callback = function()
      if not vim.api.nvim_win_is_valid(win) then
        return
      end
      local row = vim.api.nvim_win_get_cursor(win)[1]
      local c = math.min(math.max(row, 2), n_items)
      if c ~= row then
        vim.api.nvim_win_set_cursor(win, { c, 0 })
      end
    end,
  })
  local closed = false
  local function close()
    if closed then
      return
    end
    closed = true
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if vim.api.nvim_win_is_valid(prev) then
      vim.api.nvim_set_current_win(prev)
    end
  end
  local function run(it)
    close()
    vim.schedule(it.run)
  end
  local function map(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true })
  end
  for _, it in ipairs(items) do
    map(it.key, function() run(it) end)
  end
  map("<CR>", function()
    local it = items[vim.api.nvim_win_get_cursor(win)[1] - 1]
    if it then
      run(it)
    end
  end)
  for _, lhs in ipairs({ "q", "<Esc>", "<C-c>" }) do
    map(lhs, close)
  end
  vim.api.nvim_create_autocmd("WinLeave", { buffer = buf, once = true, callback = close })
  return { win = win, buf = buf, items = items }
end

return M
