if vim.g.loaded_skill_arcade then
  return
end
vim.g.loaded_skill_arcade = true

local function arcade()
  return require("skill_arcade")
end

local function area_complete()
  return require("skill_arcade.config").all_areas
end

local simple = {
  Arcade = { "menu", "Open the Skill Arcade menu" },
  ArcadeMenu = { "menu", "State-aware floating menu (start, pause, skip, quit ...)" },
  ArcadeToggle = { "toggle", "Pause / resume the clock" },
  ArcadePause = { "pause", "Pause the clock and lock the arena" },
  ArcadePlay = { "play", "Resume (or continue after a result)" },
  ArcadeSkip = { "skip", "Skip this challenge (no points, streak resets)" },
  ArcadeHint = { "hint", "Show a hint (costs points)" },
  ArcadeNext = { "next", "Next challenge after a result" },
  ArcadeQuit = { "quit", "Quit the run and show the summary" },
  ArcadeStats = { "stats", "Points, weak areas, personal bests" },
  ArcadeSetup = { "setup_report", "Show which of your plugins the game found" },
  ArcadeDaily = { "daily", "Daily challenge set" },
  ArcadeSync = { "sync", "Download community challenges (data only, validated)" },
}
for name, def in pairs(simple) do
  vim.api.nvim_create_user_command(name, function()
    arcade()[def[1]]()
  end, { desc = def[2] })
end

vim.api.nvim_create_user_command("ArcadeRun", function(o)
  arcade().run(o.fargs[1])
end, { nargs = "?", desc = "Start a run: :ArcadeRun [level 1-5]" })

vim.api.nvim_create_user_command("ArcadePractice", function(o)
  arcade().practice(o.fargs[1])
end, { nargs = "?", complete = area_complete, desc = "Practice an area without lives: :ArcadePractice [area]" })

vim.api.nvim_create_user_command("ArcadeAI", function(o)
  arcade().ai(o.fargs[1])
end, {
  nargs = "?",
  complete = function()
    return vim.list_extend({ "latest" }, vim.deepcopy(require("skill_arcade.config").all_areas))
  end,
  desc = "AI challenges (model-written, from :ArcadeSync): :ArcadeAI [latest | area]",
})

for _, name in ipairs({ "ArcadeTry", "ArcadeJoin" }) do
  vim.api.nvim_create_user_command(name, function(o)
    arcade().try(o.args)
  end, {
    nargs = 1, complete = "file",
    desc = "Play a draft once, nothing is saved: :" .. name .. " <ARC1.code | + | file.json>",
  })
end

vim.api.nvim_create_user_command("ArcadeGenerate", function(o)
  arcade().generate(o.fargs[1], o.fargs[2])
end, { nargs = "*", complete = area_complete, desc = "Generate challenges with a model: :ArcadeGenerate [area] [level]" })
