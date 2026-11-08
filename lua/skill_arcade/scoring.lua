-- Pure scoring functions (no editor state), easy to test.
local M = {}

local function clamp(x, a, b)
  return math.max(a, math.min(b, x))
end

function M.base(level)
  return 100 + 40 * ((level or 1) - 1)
end

function M.rank(keys, seconds, par_keys, par_seconds)
  if keys <= par_keys and seconds <= par_seconds then
    return "S"
  elseif keys <= par_keys * 1.5 and seconds <= par_seconds * 2 then
    return "A"
  elseif keys <= par_keys * 2 then
    return "B"
  end
  return "C"
end

--- ch: { level, par_keys, par_seconds, plugin_par? }
--- r: { keys, seconds, hints, spam, arrows, mouse, streak, toolbelt? }
function M.score(ch, r)
  local base = M.base(ch.level)
  local par, pars = math.max(1, ch.par_keys), math.max(1, ch.par_seconds)
  local key_bonus = math.floor(clamp((2 * par - r.keys) / par, 0, 1) * 0.5 * base)
  local time_bonus = math.floor(clamp((2 * pars - r.seconds) / pars, 0, 1) * 0.25 * base)
  local tool_bonus = r.toolbelt and math.floor(0.25 * base) or 0
  local habit = math.min(math.floor(0.4 * base), (r.spam or 0) * 2 + (r.arrows or 0) * 5 + (r.mouse or 0) * 5)
  local hint = (r.hints or 0) * math.floor(0.25 * base)
  local penalty = habit + hint
  local sub = math.max(0, base + key_bonus + time_bonus + tool_bonus - penalty)
  local mult = 1 + 0.1 * math.min(r.streak or 0, 10)
  return {
    base = base, key_bonus = key_bonus, time_bonus = time_bonus, tool_bonus = tool_bonus,
    habit = habit, hint = hint, mult = mult, total = math.floor(sub * mult),
    rank = M.rank(r.keys, r.seconds, par, pars),
  }
end

local RANK_VALUE = { S = 4, A = 3, B = 2, C = 1 }

--- results: list of { ok, rank }
function M.grade(results)
  if #results == 0 then
    return "-"
  end
  local sum = 0
  for _, r in ipairs(results) do
    sum = sum + (r.ok and RANK_VALUE[r.rank] or 0)
  end
  local ratio = sum / (4 * #results)
  if ratio >= 0.9 then
    return "S"
  elseif ratio >= 0.7 then
    return "A"
  elseif ratio >= 0.5 then
    return "B"
  elseif ratio >= 0.25 then
    return "C"
  end
  return "D"
end

--- level after a run
function M.next_level(level, cleared, total, game_over)
  if not game_over and cleared >= math.ceil(0.8 * total) then
    return math.min(5, level + 1)
  elseif game_over and cleared < total * 0.5 then
    return math.max(1, level - 1)
  end
  return level
end

function M.clock(sec)
  sec = math.max(0, math.floor(sec))
  return string.format("%02d:%02d", math.floor(sec / 60), sec % 60)
end

return M
