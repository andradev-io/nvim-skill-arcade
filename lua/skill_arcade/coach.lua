-- Turns the key log into metrics + "do this instead" tips, and builds the post-round lesson.
local M = {}

local ARROWS = { ["<Up>"] = true, ["<Down>"] = true, ["<Left>"] = true, ["<Right>"] = true }

--- log: list of { key, mode } in typed order
function M.metrics(log)
  local m = { keys = #log, arrows = 0, mouse = 0, spam = 0 }
  local last, streak = nil, 0
  for _, e in ipairs(log) do
    local key, mode = e[1], e[2]
    if ARROWS[key] then
      m.arrows = m.arrows + 1
    elseif key:find("Mouse", 1, true) or key:find("ScrollWheel", 1, true) then
      m.mouse = m.mouse + 1
    end
    if mode == "n" and key:match("^[hjkl]$") then
      streak = (last == key) and streak + 1 or 1
      if streak > 4 then
        m.spam = m.spam + 1
      end
    else
      streak = 0
    end
    last = key
  end
  return m
end

--- counts of bad habits found in runs of repeated keys
function M.habits(log)
  local h = { vertical = 0, horizontal = 0, words = 0, xs = 0, bs = 0, arrows = 0, mouse = 0 }
  local i, n = 1, #log
  while i <= n do
    local e = log[i]
    local j = i
    while j < n and log[j + 1][1] == e[1] and log[j + 1][2] == e[2] do
      j = j + 1
    end
    local run, key, mode = j - i + 1, e[1], e[2]
    if mode == "n" then
      if key:match("^[jk]$") and run >= 5 then
        h.vertical = h.vertical + run
      elseif key:match("^[hl]$") and run >= 5 then
        h.horizontal = h.horizontal + run
      elseif key:match("^[wbWB]$") and run >= 4 then
        h.words = h.words + run
      elseif key == "x" and run >= 4 then
        h.xs = h.xs + run
      end
    elseif mode == "i" and key == "<BS>" and run >= 6 then
      h.bs = h.bs + run
    end
    i = j + 1
  end
  local m = M.metrics(log)
  h.arrows, h.mouse = m.arrows, m.mouse
  return h
end

local HABIT_TIPS = {
  vertical = "Long runs of j/k: use a count (`12j`), `}`/`{`, `<C-d>`/`<C-u>`, `/pattern`, `G`/`gg` or `:{line}`.",
  horizontal = "Long runs of h/l: use `f{char}`/`t{char}`, `w`/`e`/`b`, `0`/`^`/`$`.",
  words = "Chains of w/b: jump with `f{char}`, `W`/`B`, `e`/`ge`, or search with `/`.",
  xs = "Repeated `x`: use `dw`, `daw`, `D` or `d$`.",
  bs = "Long backspace runs: `<C-w>` deletes a word, `<C-u>` the line; or fix it with `ciw`/`cw`.",
  arrows = "Arrow keys: stay on the home row; counts, word and search motions are faster.",
  mouse = "Mouse clicks: try `/pattern`, `*`, `%`, marks (`ma` / `'a`).",
}
local HABIT_ORDER = { "vertical", "horizontal", "words", "xs", "bs", "arrows", "mouse" }

--- tips for one round's habits
function M.habit_tips(h)
  local out = {}
  for _, k in ipairs(HABIT_ORDER) do
    if (h[k] or 0) > 0 then
      out[#out + 1] = string.format("%d x %s", h[k], HABIT_TIPS[k])
    end
  end
  return out
end

local GENERIC = {
  "`ci\"`, `ci(`, `cit` change what is inside a pair; `ca\"` includes the delimiters.",
  "`.` repeats the last change: make one good edit, then `n.` or `j.` through the rest.",
  "`:g/pattern/normal {keys}` runs normal-mode keys on every matching line.",
  "`<C-v>` + `I`/`A` edits many lines at once; `$A` appends at every line end.",
  "`<C-o>` / `<C-i>` walk the jump list; `` `` `` jumps back to where you were.",
  "`\"0p` pastes the last yank even after you deleted something; `\"_d` deletes without clobbering.",
  "`*` searches the word under the cursor; `cgn` then `.` replaces matches one by one.",
  "`qq ... q` records, `@q` plays, `@@` repeats, `10@q` runs it ten times.",
  "`%` jumps between brackets; `]]`/`[[` move between top-level blocks.",
  "`<C-w>` is the window prefix: `s`/`v` split, `o` only, `T` to its own tab, `=` equalize.",
  "`]d` / `[d` jump between diagnostics, `<C-w>d` shows the message.",
  "`:cdo s/a/b/ | update` applies a substitution to every quickfix entry.",
}

--- tip for the menu: the player's worst habit first, otherwise a rotating generic tip. returns tip, is_habit
function M.pick_tip(habits)
  local best, bestn = nil, 0
  for _, k in ipairs(HABIT_ORDER) do
    if (habits[k] or 0) > bestn then
      best, bestn = k, habits[k]
    end
  end
  if best then
    return HABIT_TIPS[best], true
  end
  return GENERIC[math.random(#GENERIC)], false
end

--- Lesson after a round. envinfo = env.detect()
--- returns { better = string|nil, why = string|nil, tools = {strings}, habits = {strings}, typed = string }
function M.lesson(ch, result, envinfo)
  local lesson = { tools = {}, habits = M.habit_tips(result.habits or {}) }
  if ch.solution then
    lesson.better = ch.solution
    lesson.better_keys = ch.par_keys
  end
  lesson.why = ch.why
  local groups = {}
  for g in pairs(ch.helps or {}) do
    groups[#groups + 1] = g
  end
  table.sort(groups)
  local env = require("skill_arcade.env")
  for _, g in ipairs(groups) do
    local tip = ch.helps[g]
    local have = envinfo.groups[g]
    if have then
      local keys = {}
      for _, id in ipairs(vim.tbl_keys(envinfo.plugins)) do
        local p = envinfo.plugins[id]
        if p.group == g and p.keys then
          keys[#keys + 1] = p.label .. " (" .. p.keys .. ")"
        end
      end
      table.sort(keys)
      lesson.tools[#lesson.tools + 1] = string.format("You have %s: %s%s", table.concat(have, ", "), tip,
        #keys > 0 and ("  -> " .. table.concat(keys, "; ")) or "")
    else
      local info = env.groups[g]
      lesson.tools[#lesson.tools + 1] = string.format("No %s found. %s  (try %s)", info and info.title or g, tip,
        info and info.suggest or g)
    end
  end
  local typed = {}
  for i = 1, math.min(#(result.log or {}), 48) do
    typed[#typed + 1] = result.log[i][1]
  end
  lesson.typed = table.concat(typed, " ") .. (#(result.log or {}) > 48 and " ..." or "")
  return lesson
end

return M
