-- Community challenges: downloaded JSON (data only), re-validated with schema.lua, turned into
-- ordinary challenges whose checks/setups come from this file's fixed presets - never from the download.
local config = require("skill_arcade.config")
local schema = require("skill_arcade.schema")

local M = {}

-- ── fixed presets (code lives here, not in the upload) ─────────────────────
local PRESET = {}

function PRESET.diagnostics(rows)
  return function(x)
    local W = vim.diagnostic.severity.WARN
    local list = {}
    for _, row in ipairs(rows and #rows > 0 and rows or { 4, 9 }) do
      list[#list + 1] = { lnum = row - 1, col = 0, end_col = 1, severity = W,
        message = "ARC: community diagnostic on line " .. row, source = "arcade" }
    end
    vim.diagnostic.set(x.diag_ns, x.buf, list)
  end
end

function PRESET.splits()
  return function()
    vim.cmd("vsplit")
    vim.cmd("split")
  end
end

function PRESET.alt_buffer()
  return function(x)
    local b = x.new_buf({ "the other buffer" }, "b")
    vim.api.nvim_set_current_buf(b)
    x.state.a = x.buf
  end
end

function PRESET.quickfix_hits(rows)
  return function(x)
    local items = {}
    for _, row in ipairs(rows or {}) do
      items[#items + 1] = { bufnr = x.buf, lnum = row, col = 1, text = x.lines[row] or "" }
    end
    vim.fn.setqflist({}, "r", { title = "arcade", items = items, idx = 1 })
  end
end

--- builds the state check for the non-text assertions of `expect`
function M.check_fn(e)
  if not (e.windows or e.layout or e.extra_tabs or e.quickfix or e.float_text or e.alt_buffer) then
    return nil
  end
  return function(c)
    if e.windows and not (c.in_arena and c.wins == e.windows) then
      return false
    end
    if e.layout and vim.fn.winlayout()[1] ~= e.layout then
      return false
    end
    if e.extra_tabs and (c.extra_tabs ~= e.extra_tabs or (e.extra_tabs > 0 and c.in_arena)) then
      return false
    end
    if e.alt_buffer and c.cur_buf ~= c.state.a then
      return false
    end
    if e.float_text then
      local found = false
      for _, f in ipairs(c.floats) do
        if table.concat(f.lines, "\n"):find(e.float_text, 1, true) then
          found = true
        end
      end
      if not found then
        return false
      end
    end
    if e.quickfix then
      local q, items = e.quickfix, c.qf.items or {}
      if q.idx and c.qf.idx ~= q.idx then
        return false
      end
      if q.size and #items ~= q.size then
        return false
      end
      if q.all_contain then
        if #items == 0 then
          return false
        end
        for _, it in ipairs(items) do
          if not (it.text or ""):find(q.all_contain, 1, true) then
            return false
          end
        end
      end
    end
    return true
  end
end

--- validated community data -> a normal challenge table (ready for catalog.normalize)
function M.to_challenge(c)
  local e = vim.deepcopy(c.expect)
  local text_e = { text = e.text, cursor = e.cursor, at = e.at, marks = e.marks }
  local ch = {
    id = "community." .. c.id, area = c.area, title = c.title, level = c.level, brief = c.brief, text = c.text,
    cursor = c.cursor, ft = c.ft, loose = c.loose, solution = c.solution, why = c.why, hint = c.hint,
    helps = c.helps, plugin_par = c.plugin_par, par_seconds = c.par_seconds, needs = c.needs,
    author = c.author, community = true, track = c.track,
    expect = next(text_e) and text_e or nil,
    check = M.check_fn(e),
  }
  if c.preset then
    ch.setup = PRESET[c.preset](c.preset_rows)
  end
  return ch
end

-- ── storage / loading ──────────────────────────────────────────────────────
local function file()
  return config.options.data_dir .. "/community.json"
end

local function read()
  local f = io.open(file(), "r")
  if not f then
    return nil
  end
  local raw = f:read("*a")
  f:close()
  local ok, data = pcall(vim.json.decode, raw)
  return ok and type(data) == "table" and data or nil
end

--- challenge tables (not yet normalized); re-validates everything on every load
function M.load()
  local out = {}
  local data = read()
  if not data or config.options.community.enabled == false then
    return out
  end
  for _, raw in ipairs(data.challenges or {}) do
    local clean = schema.validate(raw)
    if clean then
      out[#out + 1] = M.to_challenge(clean)
    end
  end
  return out
end

function M.info()
  local data = read()
  return data and { fetched = data.fetched, count = #(data.challenges or {}), url = data.url } or nil
end

--- validates a decoded bundle; returns clean list + list of "id: reason" rejections
function M.accept(bundle)
  local clean, rejected = {}, {}
  local seen = {}
  for i, raw in ipairs(type(bundle) == "table" and bundle.challenges or {}) do
    local c, err = schema.validate(raw)
    if c and seen[c.id] then
      c, err = nil, "duplicate id"
    end
    if c then
      seen[c.id] = true
      clean[#clean + 1] = c
    else
      rejected[#rejected + 1] = string.format("%s: %s", type(raw) == "table" and raw.id or ("#" .. i), err)
    end
  end
  return clean, rejected
end

--- cb(count|nil, err|nil, rejected)
function M.sync(cb)
  local url = config.options.community.url
  if not url or url == "" then
    return cb(nil, "community.url not set")
  end
  if not url:match("^https://") then
    return cb(nil, "community.url must be https")
  end
  if vim.fn.executable("curl") ~= 1 then
    return cb(nil, "curl not found")
  end
  vim.system({ "curl", "-fsSL", "--max-time", "30", "--max-filesize", "5000000", url }, { text = true },
    vim.schedule_wrap(function(res)
      if res.code ~= 0 then
        return cb(nil, "download failed: " .. vim.trim(res.stderr or tostring(res.code)))
      end
      local ok, bundle = pcall(vim.json.decode, res.stdout)
      if not ok or type(bundle) ~= "table" then
        return cb(nil, "bad JSON from " .. url)
      end
      local clean, rejected = M.accept(bundle)
      vim.fn.mkdir(config.options.data_dir, "p")
      local f, err = io.open(file(), "w")
      if not f then
        return cb(nil, tostring(err))
      end
      f:write(vim.json.encode({ fetched = os.time(), url = url, challenges = clean }))
      f:close()
      cb(#clean, nil, rejected)
    end))
end

return M
