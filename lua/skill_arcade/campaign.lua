-- The campaign: "Learn Vim" as a row of worlds, each a row of short stages that teach one new key at a time.
-- Stages are normal challenges (track maps or edit tasks), so the same engine, HUD and result screen play them.
-- Rules: no lives, a missed stage is simply retried; a stage opens when the one before it is cleared and a world
-- opens when the world before it is fully cleared; stars come from the number of keys against the stage's par
-- (the key count of the reference solution): 3 stars at par or better, 2 within 1.5x par, 1 for any clear.
local config = require("skill_arcade.config")
local store = require("skill_arcade.store")

local M = {}

local AREA = "campaign"
local DEFAULT_TIME_LIMIT = 300 -- generous: beginners are not racing the clock

--- stage spec -> normalized challenge (`campaign.<world>-<nn>`)
local function make(world, i, spec, level)
  local raw
  if spec.map then
    raw = require("skill_arcade.track").build(spec)
  else
    raw = vim.deepcopy(spec)
  end
  raw.id = string.format("%s-%02d", world.id, i)
  raw.area = AREA
  raw.level = spec.level or level
  raw.title = spec.title
  raw.task = spec.brief
  raw.brief = (spec.teach and ("NEW: " .. spec.teach .. " ") or "") .. (spec.brief or "")
  raw.hint = spec.hint or spec.teach
  raw.time_limit = spec.time_limit or DEFAULT_TIME_LIMIT
  raw.ft = raw.ft or "text"
  local ch = require("skill_arcade.catalog").normalize(raw, AREA)
  ch.boss, ch.teach, ch.world, ch.stage = spec.boss, spec.teach, world.id, i
  return ch
end

local cache
--- { { id, name, topic, blurb, stages = {challenge...} } ... } in play order
function M.worlds()
  if cache then
    return cache
  end
  cache = {}
  for n, w in ipairs(require("skill_arcade.campaign.worlds")) do
    local ok, specs = pcall(require, w.module)
    if ok and type(specs) == "table" then
      local world = { id = w.id, name = w.name, topic = w.topic, blurb = w.blurb, index = n, stages = {} }
      local level = math.min(5, math.ceil(n / 2))
      for i, spec in ipairs(specs) do
        world.stages[i] = make(world, i, spec, level)
      end
      cache[#cache + 1] = world
    end
  end
  return cache
end

function M.reset_cache()
  cache = nil
end

function M.stage(id)
  for _, w in ipairs(M.worlds()) do
    for _, s in ipairs(w.stages) do
      if s.id == id then
        return s, w
      end
    end
  end
end

local function progress()
  return store.campaign().stages
end

--- 0 = not cleared yet, 1..3 stars
function M.stars_of(id)
  local p = progress()[id]
  return p and p.stars or 0
end

--- stars a clear with `nkeys` earns
function M.stars(ch, nkeys)
  local par = math.max(1, ch.par_keys or 1)
  if nkeys <= par then
    return 3
  elseif nkeys <= par * 1.5 then
    return 2
  end
  return 1
end

--- { cleared, total, stars, max }
function M.world_status(world)
  local cleared, stars = 0, 0
  for _, s in ipairs(world.stages) do
    local n = M.stars_of(s.id)
    cleared = cleared + (n > 0 and 1 or 0)
    stars = stars + n
  end
  return { cleared = cleared, total = #world.stages, stars = stars, max = 3 * #world.stages }
end

local function unlock_all()
  return config.options.campaign and config.options.campaign.unlock_all
end

function M.world_unlocked(world)
  if world.index == 1 or unlock_all() then
    return true
  end
  local prev = M.worlds()[world.index - 1]
  if not prev then
    return true
  end
  local st = M.world_status(prev)
  return st.cleared >= st.total
end

function M.stage_unlocked(world, i)
  if not M.world_unlocked(world) then
    return false
  end
  return i == 1 or unlock_all() or M.stars_of(world.stages[i - 1].id) > 0
end

--- the first stage that is open and not cleared yet, or nil when everything is cleared
function M.next_stage()
  for _, w in ipairs(M.worlds()) do
    for i, s in ipairs(w.stages) do
      if M.stage_unlocked(w, i) and M.stars_of(s.id) == 0 then
        return s, w
      end
    end
  end
end

--- saves a cleared stage; returns stars, note (a line for the result screen: stars gained, world complete ...)
function M.record(ch, nkeys)
  local data = store.campaign()
  local p = data.stages[ch.id] or { stars = 0, plays = 0 }
  local before = p.stars
  local stars = M.stars(ch, nkeys)
  p.plays = p.plays + 1
  p.stars = math.max(before, stars)
  if not p.keys or nkeys < p.keys then
    p.keys = nkeys
  end
  data.stages[ch.id] = p
  store.save_campaign(data)
  local world = M.stage(ch.id) and select(2, M.stage(ch.id))
  local note
  if world then
    local st = M.world_status(world)
    if before == 0 and st.cleared >= st.total then
      local nxt = M.worlds()[world.index + 1]
      note = string.format("WORLD COMPLETE: %s! %s", world.name,
        nxt and ("World " .. nxt.index .. " (" .. nxt.name .. ") is open.") or "That is every world for now.")
    elseif stars > before and before > 0 then
      note = string.format("stars up: %d -> %d", before, stars)
    end
  end
  return p.stars, note
end

function M.reset()
  store.save_campaign({ stages = {} })
end

local function stars_text(n)
  return string.rep("*", n) .. string.rep(".", 3 - n)
end
M.stars_text = stars_text

--- the stages from `i` to the end of the world, played one after another
local function play(world, i)
  local deck = {}
  for k = i, #world.stages do
    deck[#deck + 1] = world.stages[k]
  end
  require("skill_arcade.game").start({ mode = "campaign", deck = deck })
end

local function pick_stage(world)
  local rows = {}
  for i, s in ipairs(world.stages) do
    rows[#rows + 1] = { i = i, s = s, open = M.stage_unlocked(world, i) }
  end
  vim.ui.select(rows, {
    prompt = string.format("World %d: %s (%s)", world.index, world.name, world.topic),
    format_item = function(r)
      local mark = r.open and ("[" .. stars_text(M.stars_of(r.s.id)) .. "]") or "[lock]"
      return string.format("%s %02d  %s%s", mark, r.i, r.s.title, r.s.boss and "  (boss)" or "")
    end,
  }, function(r)
    if r then
      if r.open then
        play(world, r.i)
      else
        vim.notify("SkillArcade: clear the stage before it first.", vim.log.levels.WARN)
      end
    end
  end)
end

--- :ArcadeCampaign [continue | reset | <world id>]
function M.open(arg)
  local worlds = M.worlds()
  if arg == "reset" then
    M.reset()
    return vim.notify("SkillArcade: campaign progress reset. Your points, bests and stats are untouched.")
  end
  if arg == "continue" or arg == "" or arg == nil then
    local nxt, w = M.next_stage()
    if arg == "continue" then
      if not nxt then
        return vim.notify("SkillArcade: every stage is cleared. Pick one to improve its stars: :ArcadeCampaign")
      end
      return play(w, nxt.stage)
    end
  end
  for _, w in ipairs(worlds) do
    if w.id == arg then
      if not M.world_unlocked(w) then
        return vim.notify("SkillArcade: clear the world before it first.", vim.log.levels.WARN)
      end
      return pick_stage(w)
    end
  end
  local nxt, nw = M.next_stage()
  local rows = {}
  if nxt then
    rows[#rows + 1] = { label = string.format("Continue: World %d, stage %02d - %s", nw.index, nxt.stage, nxt.title),
      run = function() play(nw, nxt.stage) end }
  end
  for _, w in ipairs(worlds) do
    local st = M.world_status(w)
    local open = M.world_unlocked(w)
    rows[#rows + 1] = {
      label = string.format("World %d  %-8s %-14s %s", w.index, w.name, w.topic,
        open and string.format("%d/%d cleared  stars %d/%d", st.cleared, st.total, st.stars, st.max) or "(locked)"),
      run = function() if open then pick_stage(w) else vim.notify("SkillArcade: clear World " .. (w.index - 1) .. " first.", vim.log.levels.WARN) end end,
    }
  end
  vim.ui.select(rows, { prompt = "Campaign: Learn Vim", format_item = function(r) return r.label end }, function(r)
    if r then
      r.run()
    end
  end)
end

return M
