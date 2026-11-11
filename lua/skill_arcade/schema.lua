-- Strict, data-only schema for community challenges. Anything not whitelisted here is dropped, and no
-- uploaded value is ever executed as Lua. Used by the plugin (on sync/load) and by the challenges repo CI.
local config = require("skill_arcade.config")
local keys = require("skill_arcade.keys")

local M = {}

M.PRESETS = { diagnostics = true, splits = true, alt_buffer = true, quickfix_hits = true }
M.FILETYPES = {
  text = true, lua = true, python = true, javascript = true, markdown = true, json = true, html = true,
  typescript = true, go = true, cs = true,
}
M.GROUPS = { "jump", "surround", "textobjects", "comment", "picker", "keyhints", "files", "bookmarks", "trouble",
  "replace", "multicursor", "move", "treesitter" }

-- ex commands a reference solution may use (the CI replays solutions, so keep it conservative)
local EX_ALLOWED = {
  s = true, substitute = true, g = true, global = true, v = true, vglobal = true, m = true, move = true,
  t = true, co = true, copy = true, d = true, delete = true, y = true, yank = true, j = true, join = true,
  norm = true, normal = true, sort = true, noh = true, nohlsearch = true, tabnew = true, copen = true,
  cclose = true, cc = true, cn = true, cnext = true, cp = true, cprev = true, vim = true, vimgrep = true,
  only = true, sp = true, split = true, vs = true, vsplit = true, b = true, buffer = true, tabclose = true,
}

--- returns a reason string when the reference keys could do more than edit the buffer, else nil
function M.unsafe_solution(sol)
  if type(sol) ~= "string" or sol == "" then
    return "empty solution"
  end
  if #sol > 120 then
    return "solution too long"
  end
  local low = sol:lower()
  if low:find("<c-r>=", 1, true) or low:find("\\=", 1, true) then
    return "expression evaluation is not allowed"
  end
  -- shell filters / bang commands: ':!', '%!', '/!' (after a :g pattern), ' !'
  if sol:find(":", 1, true) and (sol:find("[:/%%%s%d,$.]!") ~= nil) then
    return "'!' in a command line is not allowed"
  end
  if sol:find("|", 1, true) then
    return "'|' command chaining is not allowed"
  end
  -- every ':' command line: text up to <CR>
  local pos = 1
  while true do
    local s = sol:find(":", pos, true)
    if not s then
      break
    end
    local e = sol:find("<CR>", s, true) or sol:find("<cr>", s, true) or (#sol + 1)
    local name = M.ex_name(sol:sub(s + 1, e - 1))
    if not name or not EX_ALLOWED[name] then
      return "command ':" .. (name or sol:sub(s + 1, s + 10)) .. "' is not allowed in solutions"
    end
    pos = e + 1
  end
  return nil
end

--- command name of a command line, after its range (1,5 / % / 'a,'b / /pat/ ...)
function M.ex_name(cmdline)
  local s = cmdline
  while true do
    local before = s
    s = s:gsub("^[%s%d,;%%%.%$%+%-]+", ""):gsub("^'[%a<>'`%[%]]", ""):gsub("^/[^/]*/", "")
    if s == before then
      break
    end
  end
  return s:match("^%a+")
end

local function str(v, max, field, required)
  if v == nil then
    if required then
      return nil, "missing " .. field
    end
    return nil
  end
  if type(v) ~= "string" then
    return nil, field .. " must be a string"
  end
  if #v > max then
    return nil, field .. " too long (max " .. max .. ")"
  end
  if v:find("[%z\1-\8\11\12\14-\31]") then
    return nil, field .. " contains control characters"
  end
  if required and v == "" then
    return nil, "missing " .. field
  end
  return v
end

local function int(v, lo, hi, field)
  if v == nil then
    return nil
  end
  if type(v) ~= "number" or v ~= math.floor(v) or v < lo or v > hi then
    return nil, field .. " must be an integer " .. lo .. ".." .. hi
  end
  return v
end

local function in_list(v, list, field)
  for _, x in ipairs(list) do
    if x == v then
      return v
    end
  end
  return nil, field .. " must be one of: " .. table.concat(list, ", ")
end

local function cell(v, lines, field)
  if type(v) ~= "table" or type(v[1]) ~= "number" or type(v[2]) ~= "number" or v[1] ~= math.floor(v[1])
    or v[2] ~= math.floor(v[2]) then
    return nil, field .. " must be [row, col]"
  end
  local line = lines[v[1]]
  if not line then
    return nil, field .. " is outside the map"
  end
  if v[2] < 0 or v[2] > math.max(0, #line - 1) then
    return nil, field .. " is outside the map"
  end
  return { v[1], v[2] }
end

--- track object: { goal = {r,c}, checkpoints? = {{r,c}...}, forbid? = {"hjkl"|"arrows"|"mouse"} }
function M.validate_track(t, text, start)
  if type(t) ~= "table" then
    return nil, "a track challenge needs a track object with a goal"
  end
  local lines = vim.split(((text or ""):gsub("\n$", "")), "\n", { plain = true })
  local out = {}
  local goal, e1 = cell(t.goal, lines, "track.goal")
  if not goal then
    return nil, e1
  end
  out.goal = goal
  if t.checkpoints ~= nil then
    if type(t.checkpoints) ~= "table" or #t.checkpoints > require("skill_arcade.track").MAX_CHECKPOINTS then
      return nil, "track.checkpoints must be a short list of [row, col]"
    end
    local seen = { [goal[1] .. ":" .. goal[2]] = true }
    out.checkpoints = {}
    for i, raw in ipairs(t.checkpoints) do
      local p, e2 = cell(raw, lines, "track.checkpoints[" .. i .. "]")
      if not p then
        return nil, e2
      end
      local key = p[1] .. ":" .. p[2]
      if seen[key] then
        return nil, "track.checkpoints must be different cells, none of them the goal"
      end
      seen[key] = true
      out.checkpoints[i] = p
    end
    if #out.checkpoints == 0 then
      out.checkpoints = nil
    end
  end
  if t.forbid ~= nil then
    if type(t.forbid) ~= "table" then
      return nil, "track.forbid must be a list"
    end
    local seen = {}
    out.forbid = {}
    for _, f in ipairs(t.forbid) do
      if not require("skill_arcade.track").FORBID[f] then
        return nil, "track.forbid allows: hjkl, arrows, mouse"
      end
      if not seen[f] then
        seen[f] = true
        out.forbid[#out.forbid + 1] = f
      end
    end
    if #out.forbid == 0 then
      out.forbid = nil
    end
  end
  if start and start[1] == goal[1] and start[2] == goal[2] and not out.checkpoints then
    return nil, "the start cell is already the goal"
  end
  return out
end

--- validates a raw (decoded JSON) challenge. returns clean table, or nil + error message
function M.validate(raw)
  if type(raw) ~= "table" then
    return nil, "not an object"
  end
  local c, err = {}, nil
  local function take(field, value, e)
    if e then
      err = err or e
    end
    c[field] = value
  end

  take("id", str(raw.id, 40, "id", true))
  if c.id and not c.id:match("^[a-z0-9][a-z0-9%-]*$") then
    err = err or "id must be lowercase letters, digits and dashes"
  end
  take("title", str(raw.title, 60, "title", true))
  take("brief", str(raw.brief, 240, "brief", true))
  take("text", str(raw.text, 2000, "text", true))
  take("why", str(raw.why, 300, "why", true))
  take("hint", str(raw.hint, 120, "hint"))
  take("author", str(raw.author, 40, "author"))
  -- daily challenges: the day (YYYY-MM-DD) a challenge is the featured one, and a flag for model-written ones
  local day, eday = str(raw.date, 10, "date")
  if day and not day:match("^%d%d%d%d%-%d%d%-%d%d$") then
    eday = "date must be YYYY-MM-DD"
    day = nil
  end
  take("date", day, eday)
  c.generated = raw.generated == true or nil
  take("solution", str(raw.solution, 120, "solution", true))
  if c.solution then
    err = err or M.unsafe_solution(c.solution)
  end
  local a, ea = in_list(raw.area, config.all_areas, "area")
  take("area", a, ea)
  take("level", int(raw.level, 1, 5, "level"))
  if not c.level then
    err = err or "missing level"
  end
  take("par_seconds", int(raw.par_seconds, 3, 120, "par_seconds"))
  take("plugin_par", int(raw.plugin_par, 1, 50, "plugin_par"))
  c.loose = raw.loose == true or nil

  if raw.ft ~= nil then
    take("ft", raw.ft, not M.FILETYPES[raw.ft] and "ft must be one of the allowed filetypes" or nil)
  end
  if raw.needs ~= nil then
    local n, en = in_list(raw.needs, M.GROUPS, "needs")
    take("needs", n, en)
  end

  local nlines = 0
  if c.text then
    nlines = #vim.split((c.text:gsub("\n$", "")), "\n", { plain = true })
    if nlines > 40 then
      err = err or "text has more than 40 lines"
    end
  end

  -- cursor
  local cur = raw.cursor or { 1, 0 }
  if type(cur) ~= "table" or type(cur[1]) ~= "number" or type(cur[2] or 0) ~= "number" then
    err = err or "cursor must be [row, col]"
  elseif cur[1] < 1 or cur[1] > math.max(1, nlines) or cur[2] and cur[2] < 0 then
    err = err or "cursor is outside the text"
  else
    c.cursor = { math.floor(cur[1]), math.floor(cur[2] or 0) }
  end

  -- presets
  if raw.preset ~= nil then
    if not M.PRESETS[raw.preset] then
      err = err or "unknown preset"
    else
      c.preset = raw.preset
    end
  end
  if raw.preset_rows ~= nil then
    if type(raw.preset_rows) ~= "table" or #raw.preset_rows > 10 then
      err = err or "preset_rows must be a short list of line numbers"
    else
      c.preset_rows = {}
      for _, r in ipairs(raw.preset_rows) do
        if type(r) ~= "number" or r < 1 or r > math.max(1, nlines) then
          err = err or "preset_rows outside the text"
        else
          c.preset_rows[#c.preset_rows + 1] = math.floor(r)
        end
      end
    end
  end

  -- helps: group -> tip
  if raw.helps ~= nil then
    if type(raw.helps) ~= "table" then
      err = err or "helps must be an object"
    else
      c.helps = {}
      for g, tip in pairs(raw.helps) do
        if not vim.tbl_contains(M.GROUPS, g) then
          err = err or ("helps: unknown group " .. tostring(g))
        else
          local t, et = str(tip, 200, "helps." .. g, true)
          c.helps[g] = t
          err = err or et
        end
      end
    end
  end

  -- track: goal cell, ordered checkpoints, key rules. The assertions are derived (cursor on the goal, buffer untouched).
  local is_track = c.area == "track"
  if raw.track ~= nil and not is_track then
    err = err or "track data needs area = \"track\""
  end
  if is_track then
    local t, et = M.validate_track(raw.track, c.text, c.cursor)
    err = err or et
    c.track = t
    if t then
      c.expect = { text = c.text, cursor = { t.goal[1], t.goal[2] } }
    end
  end

  -- expect: declarative assertions only
  local e = raw.expect
  if is_track then
    -- derived above
  elseif type(e) ~= "table" then
    err = err or "missing expect"
  else
    local x = {}
    if e.text ~= nil then
      local t, et = str(e.text, 2000, "expect.text")
      x.text, err = t, err or et
    end
    if e.cursor ~= nil then
      if type(e.cursor) ~= "table" or type(e.cursor[1]) ~= "number" then
        err = err or "expect.cursor must be [row, col?]"
      else
        x.cursor = { math.floor(e.cursor[1]), type(e.cursor[2]) == "number" and math.floor(e.cursor[2]) or nil }
      end
    end
    if e.at ~= nil then
      if type(e.at) ~= "table" or type(e.at[1]) ~= "number" or type(e.at[2]) ~= "string" or #e.at[2] == 0
        or #e.at[2] > 60 or (e.at[3] ~= nil and e.at[3] ~= "first" and e.at[3] ~= "last") then
        err = err or "expect.at must be [row, \"needle\", \"first\"|\"last\"]"
      else
        x.at = { math.floor(e.at[1]), e.at[2], e.at[3] }
      end
    end
    if e.marks ~= nil then
      if type(e.marks) ~= "table" then
        err = err or "expect.marks must be an object"
      else
        x.marks = {}
        for k, row in pairs(e.marks) do
          if type(k) ~= "string" or not k:match("^[a-z]$") or type(row) ~= "number" then
            err = err or "expect.marks needs lowercase mark names and line numbers"
          else
            x.marks[k] = math.floor(row)
          end
        end
      end
    end
    local n1, e1 = int(e.windows, 1, 6, "expect.windows")
    x.windows, err = n1, err or e1
    local n2, e2 = int(e.extra_tabs, 0, 3, "expect.extra_tabs")
    x.extra_tabs, err = n2, err or e2
    if e.layout ~= nil then
      local l, el = in_list(e.layout, { "row", "col" }, "expect.layout")
      x.layout, err = l, err or el
    end
    if e.quickfix ~= nil then
      if type(e.quickfix) ~= "table" then
        err = err or "expect.quickfix must be an object"
      else
        local q = {}
        local i1, ei1 = int(e.quickfix.idx, 1, 100, "expect.quickfix.idx")
        local i2, ei2 = int(e.quickfix.size, 0, 100, "expect.quickfix.size")
        local s3, es3 = str(e.quickfix.all_contain, 60, "expect.quickfix.all_contain")
        q.idx, q.size, q.all_contain = i1, i2, s3
        err = err or ei1 or ei2 or es3
        x.quickfix = q
      end
    end
    local ft, eft = str(e.float_text, 80, "expect.float_text")
    x.float_text, err = ft, err or eft
    x.alt_buffer = e.alt_buffer == true or nil
    c.expect = x
    if not (x.text or x.cursor or x.at or x.marks or x.windows or x.extra_tabs or x.layout or x.quickfix
      or x.float_text or x.alt_buffer) then
      err = err or "expect has no assertion"
    end
  end
  if err then
    return nil, err
  end
  return c
end

--- the solution's key count (par)
function M.par(c)
  return keys.count(c.solution)
end

return M
