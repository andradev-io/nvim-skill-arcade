-- lazy.nvim / LazyVim spec. Drop into lua/plugins/skill-arcade.lua (LazyVim and most lazy.nvim setups import
-- that folder), or add the table to your own `require("lazy").setup({...})`.
return {
  {
    "dev-vinicius-andrade/nvim-skill-arcade",
    -- dir = "~/path/to/nvim-skill-arcade", -- use this instead of the line above for a local checkout
    cmd = {
      "Arcade", "ArcadeMenu", "ArcadeRun", "ArcadeDaily", "ArcadePractice", "ArcadeToggle", "ArcadePause",
      "ArcadePlay", "ArcadeSkip", "ArcadeHint", "ArcadeNext", "ArcadeQuit", "ArcadeStats", "ArcadeSetup",
      "ArcadeGenerate", "ArcadeSync", "ArcadeTry", "ArcadeJoin",
    },
    -- lazy-load on first use; `keys` also registers the mappings (and shows them in which-key)
    keys = {
      { "<leader>Gm", "<cmd>ArcadeMenu<cr>", desc = "Arcade: menu" },
      { "<leader>Gg", "<cmd>ArcadeRun<cr>", desc = "Arcade: start a run" },
      { "<leader>Gd", "<cmd>ArcadeDaily<cr>", desc = "Arcade: daily challenge" },
      { "<leader>Gr", "<cmd>ArcadePractice<cr>", desc = "Arcade: practice an area" },
      { "<leader>Gp", "<cmd>ArcadeToggle<cr>", desc = "Arcade: pause / resume" },
      { "<leader>Gs", "<cmd>ArcadeSkip<cr>", desc = "Arcade: skip" },
      { "<leader>Gh", "<cmd>ArcadeHint<cr>", desc = "Arcade: hint" },
      { "<leader>Gn", "<cmd>ArcadeNext<cr>", desc = "Arcade: next challenge" },
      { "<leader>Gq", "<cmd>ArcadeQuit<cr>", desc = "Arcade: quit run" },
      { "<leader>Gt", "<cmd>ArcadeStats<cr>", desc = "Arcade: stats" },
      { "<leader>Ge", "<cmd>ArcadeSetup<cr>", desc = "Arcade: what the game found in my setup" },
    },
    opts = {
      keymaps = false, -- `keys` above owns the mappings
      -- areas = { "motions", "textobjects", "editing" }, -- limit what the game offers
      -- lives = 3, run_length = 6, countdown = 3,
      -- Optional model-made challenges (any OpenAI-compatible server, e.g. local Ollama):
      -- provider = "openai",
      -- openai = { base_url = "http://localhost:11434/v1", model = "qwen2.5-coder:14b" },
      -- or: provider = "anthropic",  (needs ANTHROPIC_API_KEY)
    },
  },
  { "folke/which-key.nvim", optional = true, opts = { spec = { { "<leader>G", group = "skill arcade" } } } },
}
