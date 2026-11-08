-- Optional model-generated challenges. The model supplies DATA only (declarative expect); nothing it writes
-- is executed, and its reference key sequence is only displayed.
local config = require("skill_arcade.config")
local catalog = require("skill_arcade.catalog")
local store = require("skill_arcade.store")

local M = {}

local SCHEMA = [[
Reply with ONLY a JSON array (no prose, no code fences) of challenge objects:
{
  "title": "short name",
  "level": 1-5,
  "brief": "one sentence telling the player the END STATE to reach (never the keys to press)",
  "text": "initial buffer text, \n separated, at most 20 lines",
  "cursor": [row (1-based), col (0-based)],
  "ft": "text|lua|python|javascript|markdown|json|html",
  "expect": { "text": "the full expected buffer text" }   OR   { "cursor": [row, col] }  OR both,
  "solution": "a short reference key sequence in Vim notation, e.g. ci\"x<Esc>",
  "why": "one or two sentences explaining the idea behind the best approach"
}
Rules: the start state must NOT already satisfy expect; the result must be reachable with plain Neovim
(no plugins); judge only buffer text / cursor, never keys; any valid approach must pass.]]

function M.build_prompt(area, level, count, envinfo)
  local have = {}
  for g, labels in pairs(envinfo.groups) do
    have[#have + 1] = g .. " (" .. table.concat(labels, ", ") .. ")"
  end
  table.sort(have)
  return string.format(
    "You design short Neovim skill challenges for a game. Skill area: %s. Difficulty level %d of 5. "
      .. "Create %d different challenges.\nThe player's setup has: %s.\n%s",
    area, level, count, #have > 0 and table.concat(have, "; ") or "no extra plugins", SCHEMA)
end

local function extract_json(text)
  text = text:gsub("^%s*```%w*%s*", ""):gsub("%s*```%s*$", "")
  local s = text:find("[%[{]")
  if not s then
    return nil
  end
  local ok, data = pcall(vim.json.decode, text:sub(s))
  if not ok then
    -- trailing chatter: cut at the last closing bracket
    local e = text:match(".*()[%]}]")
    if e then
      ok, data = pcall(vim.json.decode, text:sub(s, e))
    end
  end
  return ok and data or nil
end

--- validates one model challenge; returns normalized challenge or nil, reason
function M.validate(raw, area)
  if type(raw) ~= "table" then
    return nil, "not an object"
  end
  for _, f in ipairs({ "title", "brief", "text" }) do
    if type(raw[f]) ~= "string" or raw[f] == "" then
      return nil, "missing " .. f
    end
  end
  if type(raw.expect) ~= "table" or (raw.expect.text == nil and raw.expect.cursor == nil) then
    return nil, "missing expect"
  end
  local e = {}
  if raw.expect.text ~= nil then
    if type(raw.expect.text) ~= "string" then
      return nil, "bad expect.text"
    end
    e.text = raw.expect.text
  end
  if raw.expect.cursor ~= nil then
    local c = raw.expect.cursor
    if type(c) ~= "table" or type(c[1]) ~= "number" then
      return nil, "bad expect.cursor"
    end
    e.cursor = { c[1], type(c[2]) == "number" and c[2] or nil }
  end
  local lines = vim.split((raw.text:gsub("\n$", "")), "\n", { plain = true })
  if #lines > 40 then
    return nil, "too many lines"
  end
  local cursor = { 1, 0 }
  if type(raw.cursor) == "table" and type(raw.cursor[1]) == "number" then
    cursor = { math.max(1, math.min(#lines, raw.cursor[1])), math.max(0, raw.cursor[2] or 0) }
  end
  local ch = {
    id = "gen." .. store.new_id(), title = raw.title:sub(1, 60), brief = raw.brief:sub(1, 240),
    level = math.max(1, math.min(5, math.floor(tonumber(raw.level) or 2))), text = raw.text, cursor = cursor,
    ft = type(raw.ft) == "string" and raw.ft:match("^%a+$") and raw.ft or "text",
    expect = e, solution = type(raw.solution) == "string" and raw.solution:sub(1, 120) or nil,
    why = type(raw.why) == "string" and raw.why:sub(1, 300) or nil, area = area, generated = true,
  }
  local n = catalog.normalize(ch, area)
  -- start state must not already be a win
  if e.text and catalog.lines_equal(n.lines, n.expect.lines or {}) then
    return nil, "already solved at start"
  end
  if e.cursor and not e.text and cursor[1] == e.cursor[1] and (e.cursor[2] == nil or e.cursor[2] == cursor[2]) then
    return nil, "already solved at start"
  end
  return ch
end

--- cb(list_of_saved, err)
function M.generate(area, level, cb)
  local envinfo = require("skill_arcade.env").detect()
  local prompt = M.build_prompt(area, level, config.options.generate_count, envinfo)
  require("skill_arcade.provider").request(prompt, function(text, err)
    if not text then
      return cb(nil, err)
    end
    local data = extract_json(text)
    if type(data) == "table" and data.title then
      data = { data }
    end
    if type(data) ~= "table" then
      return cb(nil, "could not parse the model reply as JSON")
    end
    local saved, rejected = {}, {}
    for _, raw in ipairs(data) do
      local ch, why = M.validate(raw, area)
      if ch then
        saved[#saved + 1] = store.save_generated(ch)
      else
        rejected[#rejected + 1] = why
      end
    end
    if #saved == 0 then
      return cb(nil, "no valid challenge in the reply (" .. table.concat(rejected, ", ") .. ")")
    end
    cb(saved)
  end)
end

M.extract_json = extract_json

return M
