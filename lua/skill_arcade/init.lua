local config = require("skill_arcade.config")
local game = require("skill_arcade.game")
local catalog = require("skill_arcade.catalog")
local store = require("skill_arcade.store")

local M = {}

local MAP_DESC = {
  menu = "Arcade: menu", run = "Arcade: start a run", daily = "Arcade: daily challenge",
  practice = "Arcade: practice an area", toggle = "Arcade: pause / resume", skip = "Arcade: skip",
  hint = "Arcade: hint", next = "Arcade: next challenge", quit = "Arcade: quit run",
  stats = "Arcade: stats", setup = "Arcade: my setup",
}

function M.setup(opts)
  config.setup(opts)
  math.randomseed(os.time() + (vim.uv.hrtime() % 100000))
  local km = config.options.keymaps
  if type(km) == "table" then
    for action, lhs in pairs(km) do
      if lhs and M[action == "setup" and "setup_report" or action] then
        vim.keymap.set("n", lhs, function()
          M[action == "setup" and "setup_report" or action]()
        end, { desc = "SkillArcade " .. action, silent = true })
      end
    end
  end
end

function M.menu()
  require("skill_arcade.menu").open()
end

local function current_level()
  return config.options.level or store.profile().level
end

--- start a ramped run
function M.run(level)
  game.start({
    mode = "run",
    deck = catalog.build_run({ n = config.options.run_length, level = tonumber(level) or current_level() }),
  })
end

function M.daily()
  game.start({ mode = "daily", deck = catalog.build_daily() })
end

--- practice one area; without an argument asks which
function M.practice(area)
  local function go(a)
    game.start({ mode = "practice", deck = catalog.for_area(a) })
  end
  if area and area ~= "" then
    return go(area)
  end
  local areas = catalog.areas()
  local p = store.profile()
  local labels = {}
  for _, a in ipairs(areas) do
    local s = p.areas[a]
    labels[#labels + 1] = s and string.format("%s  (%d%% cleared)", a, math.floor(100 * s.cleared / math.max(1, s.seen))) or a
  end
  vim.ui.select(areas, {
    prompt = "Practice area",
    format_item = function(a)
      return labels[vim.fn.index(areas, a) + 1]
    end,
  }, function(choice)
    if choice then
      go(choice)
    end
  end)
end

--- play one challenge from a JSON file (e.g. a draft from the challenges website): one practice round,
--- schema-checked like any community challenge, nothing saved (no points, bests or stats).
function M.try(path)
  if not path or path == "" then
    return vim.notify("SkillArcade: usage :ArcadeTry <challenge.json>", vim.log.levels.WARN)
  end
  local clean, err = require("skill_arcade.validate").read(path)
  if not clean then
    return vim.notify("SkillArcade: " .. tostring(err), vim.log.levels.ERROR)
  end
  local ch = catalog.normalize(require("skill_arcade.community").to_challenge(clean), clean.area)
  game.start({ mode = "practice", deck = { ch }, try = true })
end

function M.toggle() game.toggle() end
function M.pause() game.pause() end
function M.play() game.play() end
function M.skip() game.skip() end
function M.hint() game.hint() end
function M.next() game.next() end
function M.quit() game.quit() end

function M.stats()
  require("skill_arcade.ui").stats(store.profile(), store.bests(), store.history(), config.all_areas)
end

function M.setup_report()
  require("skill_arcade.ui").setup_report(require("skill_arcade.env").detect(), catalog.areas())
end

function M.sync()
  vim.notify("SkillArcade: syncing community challenges ...")
  require("skill_arcade.community").sync(function(n, err, rejected)
    if not n then
      return vim.notify("SkillArcade: sync failed: " .. tostring(err), vim.log.levels.ERROR)
    end
    local msg = string.format("SkillArcade: %d community challenge(s) ready", n)
    if rejected and #rejected > 0 then
      msg = msg .. string.format(" (%d rejected by the safety schema)", #rejected)
    end
    vim.notify(msg)
  end)
end

function M.generate(area, level)
  if config.options.provider == "none" then
    return vim.notify('SkillArcade: set provider = "anthropic" or "openai" in setup() first', vim.log.levels.WARN)
  end
  local function go(a)
    vim.notify(string.format("SkillArcade: generating %s challenges ...", a))
    require("skill_arcade.generator").generate(a, tonumber(level) or current_level(), function(list, err)
      if not list then
        return vim.notify("SkillArcade: " .. tostring(err), vim.log.levels.ERROR)
      end
      vim.notify(string.format("SkillArcade: %d new %s challenge(s) saved - they join your runs and practice", #list, a))
    end)
  end
  if area and area ~= "" then
    return go(area)
  end
  vim.ui.select(catalog.active_areas(), { prompt = "Generate for area" }, function(choice)
    if choice then
      go(choice)
    end
  end)
end

return M
