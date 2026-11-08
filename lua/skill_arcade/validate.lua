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

local CODE_PREFIX = "ARC1."

--- "ARC1.<base64url(json)>" (a draft code copied from the challenges website) -> JSON text, or nil, reason
function M.decode_code(code)
  code = vim.trim(code or "")
  if code:sub(1, #CODE_PREFIX) ~= CODE_PREFIX then
    return nil, "not a draft code (expected ARC1.<code>)"
  end
  local b64 = code:sub(#CODE_PREFIX + 1):gsub("%s", ""):gsub("-", "+"):gsub("_", "/")
  b64 = b64 .. string.rep("=", (4 - #b64 % 4) % 4)
  local ok, raw = pcall(vim.base64.decode, b64)
  if not ok or not raw or raw == "" then
    return nil, "draft code is damaged (could not decode)"
  end
  return raw
end

--- JSON text -> schema-checked clean challenge (no replay), or nil, reason
function M.parse(raw)
  local ok, data = pcall(vim.json.decode, raw)
  if not ok or type(data) ~= "table" then
    return nil, "not valid JSON"
  end
  return schema.validate(data)
end

--- source for :ArcadeTry: a draft code, "+" (system clipboard: JSON or code), or a .json file path.
--- Read + schema-check without replaying. returns clean or nil, reason
function M.read(src)
  src = vim.trim(src or "")
  local raw
  if src == "+" then
    raw = vim.trim(vim.fn.getreg("+"))
    if raw == "" then
      return nil, "the clipboard is empty"
    end
  elseif src:sub(1, #CODE_PREFIX) == CODE_PREFIX then
    raw = src
  else
    local path = vim.fn.expand(src)
    local f = io.open(path, "r")
    if not f then
      return nil, "cannot read " .. path
    end
    raw = f:read("*a")
    f:close()
  end
  if vim.trim(raw):sub(1, #CODE_PREFIX) == CODE_PREFIX then
    local err
    raw, err = M.decode_code(raw)
    if not raw then
      return nil, err
    end
  end
  return M.parse(raw)
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
