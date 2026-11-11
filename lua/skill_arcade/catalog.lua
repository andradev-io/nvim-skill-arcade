-- Loads built-in packs + generated challenges, normalizes them, checks them and builds runs.
local config = require("skill_arcade.config")
local keys = require("skill_arcade.keys")

local M = {}

local EXT = {
  lua = "lua", python = "py", javascript = "js", markdown = "md", text = "txt", html = "html", json = "json",
  typescript = "ts", go = "go", cs = "cs",
}

local AREA_HINT = {
  motions = "Think counts, f/t, %, { }, / search, G.",
  textobjects = "Operator + i/a + object (w, \", (, {, t, p).",
  editing = "One precise edit beats many small ones; try . or visual block.",
  search = "The command line has :s and :g; \\v makes regex readable.",
  macros = "Record once with q, replay with @ and a count.",
  registers = "Registers: \"0 last yank, \"_ black hole, \"a-\"z named.",
  marks = "Marks (m{a-z}), the jump list (<C-o>) and `` help here.",
  windows = "<C-w> is the window prefix; :tab commands for tabs.",
  quickfix = ":copen, :cc N, ]q / [q, :vimgrep.",
  diagnostics = "]d / [d jump, <C-w>d opens the float, vim.diagnostic.* has the rest.",
  track = "Reach the goal cell with motions: w b e, f t ; ,, %, { }, G, | (column), marks, / search.",
  refactor = "Small code refactors: :s with \\< \\>, J, :m, cw, text objects, a macro or the dot.",
  plugins = "This one rewards a plugin you installed.",
}

local function split_lines(text)
  text = text:gsub("\n$", "")
  return vim.split(text, "\n", { plain = true })
end

local function find_col(line, needle, which)
  local pos, from, last = nil, 1, nil
  while true do
    pos = line:find(needle, from, true)
    if not pos then
      break
    end
    last = pos
    if which ~= "last" then
      break
    end
    from = pos + 1
  end
  return last and (last - 1) or nil
end

--- fills defaults and resolves expect.at
function M.normalize(raw, area)
  local ch = vim.deepcopy(raw)
  ch.area = ch.area or area
  ch.id = ch.id:find(".", 1, true) and ch.id or (ch.area .. "." .. ch.id)
  ch.level = math.max(1, math.min(5, ch.level or 1))
  ch.lines = ch.lines or split_lines(ch.text or "")
  ch.cursor = ch.cursor or { 1, 0 }
  ch.ft = ch.ft or "text"
  ch.ext = EXT[ch.ft] or "txt"
  if type(ch.solution) == "string" then
    ch.par_keys = ch.par_keys or keys.count(ch.solution)
  end
  ch.par_keys = ch.par_keys or 10
  ch.par_seconds = ch.par_seconds or (10 + 5 * ch.level)
  ch.time_limit = ch.time_limit or math.max(45, ch.par_seconds * 5)
  ch.hint = ch.hint or AREA_HINT[ch.area]
  ch.helps = ch.helps or {}
  if ch.track then
    -- a track is judged by the end state: cursor on the goal, buffer untouched, checkpoints visited in order
    ch.expect = { text = ch.text or table.concat(ch.lines, "\n"), cursor = ch.track.goal }
    ch.check = ch.check or require("skill_arcade.track").check_fn(ch.track)
  end
  local e = ch.expect
  if e then
    if e.at then
      local col = find_col(ch.lines_after and ch.lines_after[e.at[1]] or ch.lines[e.at[1]] or "", e.at[2], e.at[3])
      e.cursor = { e.at[1], col or 0 }
    end
    if type(e.text) == "string" then
      e.lines = split_lines(e.text)
    end
  end
  return ch
end

local function load_pack(area)
  local ok, list = pcall(require, "skill_arcade.challenges." .. area)
  if not ok then
    return {}
  end
  local out = {}
  for _, raw in ipairs(list) do
    out[#out + 1] = M.normalize(raw, area)
  end
  return out
end

local builtin
function M.builtin()
  if not builtin then
    builtin = {}
    for _, area in ipairs(config.all_areas) do
      vim.list_extend(builtin, load_pack(area))
    end
  end
  return builtin
end

function M.all()
  local list = vim.list_slice(M.builtin())
  for _, raw in ipairs(require("skill_arcade.community").load()) do
    local ok, ch = pcall(M.normalize, raw, raw.area)
    if ok then
      list[#list + 1] = ch
    end
  end
  for _, g in ipairs(require("skill_arcade.store").generated_list()) do
    local ok, ch = pcall(M.normalize, g, g.area or "motions")
    if ok then
      ch.generated = true
      list[#list + 1] = ch
    end
  end
  return list
end

function M.by_id(id)
  for _, ch in ipairs(M.all()) do
    if ch.id == id then
      return ch
    end
  end
end

local function trim_lines(lines, loose)
  local out = {}
  for i, l in ipairs(lines) do
    l = l:gsub("%s+$", "")
    if loose then
      l = l:gsub("^%s+", "")
    end
    out[i] = l
  end
  while #out > 0 and out[#out] == "" do
    out[#out] = nil
  end
  return out
end

function M.lines_equal(a, b, loose)
  a, b = trim_lines(a, loose), trim_lines(b, loose)
  if #a ~= #b then
    return false
  end
  for i = 1, #a do
    if a[i] ~= b[i] then
      return false
    end
  end
  return true
end

--- Decides whether the challenge is solved from the resulting editor state, never from the keys used.
--- ctx: see game.make_ctx
function M.check(ch, ctx)
  if ctx.mode ~= "n" and not ch.any_mode then
    return false
  end
  local e = ch.expect
  if not e and not ch.check then
    return false
  end
  if e then
    if e.lines and not M.lines_equal(ctx.lines, e.lines, ch.loose) then
      return false
    end
    if e.cursor then
      if not ctx.cursor or ctx.cur_buf ~= ctx.buf then
        return false
      end
      if ctx.cursor[1] ~= e.cursor[1] or (e.cursor[2] and ctx.cursor[2] ~= e.cursor[2]) then
        return false
      end
    end
    for name, row in pairs(e.marks or {}) do
      local p = ctx.mark(name)
      if not p or p[1] ~= row then
        return false
      end
    end
  end
  if ch.check then
    local ok, res = pcall(ch.check, ctx)
    if not ok or not res then
      return false
    end
  end
  return true
end

function M.active_areas()
  local want = config.options.areas
  if not want then
    return vim.list_slice(config.all_areas)
  end
  local out = {}
  for _, a in ipairs(config.all_areas) do
    if vim.tbl_contains(want, a) then
      out[#out + 1] = a
    end
  end
  return out
end

--- challenges the player can be offered right now
function M.available(opts)
  opts = opts or {}
  local areas = opts.areas or M.active_areas()
  local set = {}
  for _, a in ipairs(areas) do
    set[a] = true
  end
  local envinfo = opts.env or require("skill_arcade.env").detect()
  local out = {}
  for _, ch in ipairs(M.all()) do
    local ok = set[ch.area]
    if ok and ch.needs then
      ok = config.options.plugin_challenges and envinfo.groups[ch.needs] ~= nil and not opts.fair
    end
    if ok and opts.fair and ch.needs then
      ok = false
    end
    -- model-written challenges of the bundle have their own section (:ArcadeAI) unless the player opted in
    if ok and ch.community and ch.generated and not config.options.ai.in_runs then
      ok = false
    end
    local langs = config.options.refactor_languages
    if ok and ch.area == "refactor" and type(langs) == "table" and #langs > 0 then
      ok = vim.tbl_contains(langs, ch.ft)
    end
    if ok then
      out[#out + 1] = ch
    end
  end
  return out
end

--- areas with at least one available challenge
function M.areas()
  local present, out = {}, {}
  for _, ch in ipairs(M.available()) do
    present[ch.area] = true
  end
  for _, a in ipairs(M.active_areas()) do
    if present[a] then
      out[#out + 1] = a
    end
  end
  return out
end

local function shuffle(list, rand)
  for i = #list, 2, -1 do
    local j = rand(i)
    list[i], list[j] = list[j], list[i]
  end
  return list
end

--- ramped run: difficulty rises every two challenges from the player's level
--- opts: { n, level, areas, rand? }
function M.build_run(opts)
  local n = opts.n or config.options.run_length
  local level = opts.level or 1
  local rand = opts.rand or function(m) return math.random(m) end
  local pool = shuffle(M.available({ areas = opts.areas, fair = opts.fair }), rand)
  local bests = require("skill_arcade.store").bests().challenges
  -- unseen first, so runs keep feeling fresh
  table.sort(pool, function(a, b)
    local pa, pb = (bests[a.id] and bests[a.id].plays) or 0, (bests[b.id] and bests[b.id].plays) or 0
    return pa < pb
  end)
  local out, used = {}, {}
  for i = 1, n do
    local target = math.min(5, level + math.floor((i - 1) / 2))
    local pick, dist = nil, 99
    for _, ch in ipairs(pool) do
      if not used[ch.id] then
        local d = math.abs(ch.level - target)
        if d < dist then
          pick, dist = ch, d
        end
      end
    end
    if not pick then
      break
    end
    used[pick.id] = true
    out[#out + 1] = pick
  end
  return out
end

--- same challenges for everybody on a given day (plugin-featured ones are left out to stay fair)
function M.build_daily(date)
  local day = tostring(date or os.date("%Y%m%d"))
  -- challenges written for this exact day (`:ArcadeSync` downloads them): everybody who synced plays the same set
  local iso = day:sub(1, 4) .. "-" .. day:sub(5, 6) .. "-" .. day:sub(7, 8)
  local featured = {}
  for _, raw in ipairs(require("skill_arcade.community").load()) do
    if raw.date == iso and not raw.needs then
      local ok, ch = pcall(M.normalize, raw, raw.area)
      if ok then
        featured[#featured + 1] = ch
      end
    end
  end
  if #featured >= 3 then
    table.sort(featured, function(a, b) return a.level == b.level and a.id < b.id or a.level < b.level end)
    return vim.list_slice(featured, 1, config.options.daily_length)
  end
  -- no (or too few) challenges for the day, e.g. offline: the built-in set picked by the date
  local seed = tonumber(day)
  local state = seed
  local function rand(m)
    state = (state * 1103515245 + 12345) % 2147483648
    return (state % m) + 1
  end
  local pool = {}
  for _, ch in ipairs(M.builtin()) do
    if not ch.needs then
      pool[#pool + 1] = ch
    end
  end
  table.sort(pool, function(a, b) return a.id < b.id end)
  shuffle(pool, rand)
  local n = config.options.daily_length
  local out = vim.list_slice(pool, 1, n)
  table.sort(out, function(a, b) return a.level < b.level end)
  return out
end

--- the AI challenges (model-written, from the synced bundle), newest first. opts: { area, n }
function M.ai(opts)
  opts = opts or {}
  local out = {}
  for _, raw in ipairs(require("skill_arcade.community").ai_list()) do
    if (not opts.area or raw.area == opts.area) and not raw.needs then
      local ok, ch = pcall(M.normalize, raw, raw.area)
      if ok then
        out[#out + 1] = ch
      end
    end
  end
  return opts.n and vim.list_slice(out, 1, opts.n) or out
end

--- challenges of one area, easiest first
function M.for_area(area)
  local out = {}
  for _, ch in ipairs(M.available({ areas = { area } })) do
    out[#out + 1] = ch
  end
  table.sort(out, function(a, b)
    return a.level == b.level and a.id < b.id or a.level < b.level
  end)
  return out
end

return M
