-- JSON storage: profile.json, bests.json, history.json, generated/<id>.json, arena/ (temporary files)
local config = require("skill_arcade.config")

local M = {}

local function dir(sub)
  local p = config.options.data_dir .. (sub and ("/" .. sub) or "")
  vim.fn.mkdir(p, "p")
  return p
end

local function read_json(path, default)
  local f = io.open(path, "r")
  if not f then
    return default
  end
  local raw = f:read("*a")
  f:close()
  local ok, data = pcall(vim.json.decode, raw)
  if not ok or type(data) ~= "table" then
    return default
  end
  return data
end

local function write_json(path, data)
  local f, err = io.open(path, "w")
  if not f then
    return false, err
  end
  f:write(vim.json.encode(data))
  f:close()
  return true
end

function M.profile()
  local p = read_json(dir() .. "/profile.json", {})
  p.points = p.points or 0
  p.level = p.level or 1
  p.runs = p.runs or 0
  p.clears = p.clears or 0
  p.areas = p.areas or {}
  p.habits = p.habits or {}
  return p
end

function M.save_profile(p)
  return write_json(dir() .. "/profile.json", p)
end

--- { challenges = { [id] = {score, keys, seconds, rank, plays, clears} }, run = n, daily = { [yyyymmdd] = n } }
function M.bests()
  local b = read_json(dir() .. "/bests.json", {})
  b.challenges = b.challenges or {}
  b.daily = b.daily or {}
  b.run = b.run or 0
  return b
end

function M.save_bests(b)
  return write_json(dir() .. "/bests.json", b)
end

--- campaign progress: { stages = { [challenge id] = {stars, keys, plays} } }
function M.campaign()
  local c = read_json(dir() .. "/campaign.json", {})
  c.stages = c.stages or {}
  return c
end

function M.save_campaign(c)
  return write_json(dir() .. "/campaign.json", c)
end

function M.history()
  return read_json(dir() .. "/history.json", {})
end

function M.push_history(entry)
  local h = M.history()
  h[#h + 1] = entry
  while #h > 200 do
    table.remove(h, 1)
  end
  return write_json(dir() .. "/history.json", h)
end

function M.new_id()
  return os.date("%Y%m%d-%H%M%S") .. "-" .. string.format("%04x", math.random(0, 0xffff))
end

function M.save_generated(ch)
  if type(ch.id) ~= "string" or not ch.id:match("^[%w%-_]+$") then
    ch.id = M.new_id() -- never trust a model-supplied id as a path
  end
  write_json(dir("generated") .. "/" .. ch.id .. ".json", ch)
  return ch
end

function M.generated_list()
  local out = {}
  for _, path in ipairs(vim.fn.glob(dir("generated") .. "/*.json", false, true)) do
    local ch = read_json(path)
    if ch then
      out[#out + 1] = ch
    end
  end
  return out
end

function M.arena_dir()
  return dir("arena")
end

function M.clear_arena()
  for _, f in ipairs(vim.fn.glob(M.arena_dir() .. "/*", false, true)) do
    os.remove(f)
  end
end

return M
