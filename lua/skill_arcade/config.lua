local M = {}

M.all_areas = {
  "motions", "textobjects", "editing", "search", "macros", "registers",
  "marks", "windows", "quickfix", "diagnostics", "track", "refactor", "plugins",
}

M.defaults = {
  -- progress, bests, history, generated challenges and the temporary arena files live here
  data_dir = vim.fn.stdpath("data") .. "/skill-arcade",
  -- which skill areas the game offers: nil = all, or a list such as { "motions", "textobjects" }
  areas = nil,
  run_length = 6, -- challenges per run
  daily_length = 5,
  lives = 3, -- failed (timed out) challenges allowed before game over; skip is free but scores 0
  countdown = 3, -- seconds to read the task before the clock starts
  level = nil, -- force the starting difficulty (1-5); nil = your saved level
  plugin_challenges = true, -- offer challenges that feature plugins you have installed
  -- languages of the refactor sprints: nil = all, or a list of filetypes such as { "lua", "go" } (lua, typescript, go, cs, python, javascript)
  refactor_languages = nil,
  hud = true,
  -- community challenges: data only, validated against a strict schema. `:ArcadeSync` downloads them;
  -- nothing is ever fetched automatically.
  community = {
    enabled = true, -- include synced community challenges in runs
    url = "https://dev-vinicius-andrade.github.io/nvim-skill-arcade-challenges/community.json", -- built by CI (GitHub Pages)
  },
  -- optional model-generated challenges: "none" | "anthropic" | "openai" (any OpenAI-compatible endpoint)
  provider = "none",
  generate_count = 3,
  anthropic = {
    api_key_env = "ANTHROPIC_API_KEY",
    model = "claude-sonnet-5-5",
    max_tokens = 4096,
    timeout = 120,
  },
  openai = {
    base_url = "http://localhost:11434/v1", -- Ollama; any OpenAI-compatible server works
    model = nil, -- e.g. "qwen2.5-coder:14b"
    api_key_env = nil,
    max_tokens = 4096,
    timeout = 300,
  },
  -- `false` = define no mappings (use lazy.nvim `keys`); set one to false to drop it.
  -- <leader>G (capital) avoids the common <leader>g / <leader>r groups.
  keymaps = {
    menu = "<leader>Gm", -- state-aware menu: start, pause, skip, quit ...
    run = "<leader>Gg", -- start a run
    daily = "<leader>Gd",
    practice = "<leader>Gr", -- pick an area and practice without lives
    toggle = "<leader>Gp", -- pause / resume
    skip = "<leader>Gs",
    hint = "<leader>Gh",
    next = "<leader>Gn", -- continue after a result
    quit = "<leader>Gq",
    stats = "<leader>Gt",
    setup = "<leader>Ge", -- what the game found in YOUR setup
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  opts = opts or {}
  M.options = vim.tbl_deep_extend("force", M.defaults, opts)
  if type(opts.areas) == "table" and #opts.areas > 0 then
    M.options.areas = opts.areas -- replace, never merge
  end
  return M.options
end

return M
