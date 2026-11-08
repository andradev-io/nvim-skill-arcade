-- Replays a community challenge's reference solution in the real engine (used by the challenges repo CI
-- and by the tests). Unsafe solutions never get here: schema.validate rejects them first.
local schema = require("skill_arcade.schema")
local community = require("skill_arcade.community")
local catalog = require("skill_arcade.catalog")
local game = require("skill_arcade.game")
local keys = require("skill_arcade.keys")

local M = {}

local function stop()
  if game.run then
    local real = vim.notify
    vim.notify = function() end
    game.abort("validate")
    vim.notify = real
  end
end

--- raw: decoded JSON table. returns clean (schema output) or nil, reason
function M.challenge(raw)
  local clean, err = schema.validate(raw)
  if not clean then
    return nil, err
  end
  local ch = catalog.normalize(community.to_challenge(clean), clean.area)
  local ok, res = pcall(function()
    game.start({ mode = "practice", deck = { ch }, countdown = 0 })
    if not game.run then
      return "could not start the engine"
    end
    if game.evaluate() then
      return "already solved at the start - the challenge must need at least one action"
    end
    keys.feed(clean.solution)
    if not game.evaluate() then
      return "the reference solution does not satisfy expect"
    end
    return nil
  end)
  stop()
  if not ok then
    return nil, "replay crashed: " .. tostring(res)
  end
  if res then
    return nil, res
  end
  return clean
end

--- path to a challenge .json file; also checks filename == id
function M.file(path)
  local f = io.open(path, "r")
  if not f then
    return nil, "cannot read file"
  end
  local raw = f:read("*a")
  f:close()
  local ok, data = pcall(vim.json.decode, raw)
  if not ok or type(data) ~= "table" then
    return nil, "not valid JSON"
  end
  local clean, err = M.challenge(data)
  if not clean then
    return nil, err
  end
  local base = vim.fn.fnamemodify(path, ":t:r")
  if base ~= clean.id then
    return nil, ("file name '%s' must match id '%s'"):format(base, clean.id)
  end
  return clean
end

return M
