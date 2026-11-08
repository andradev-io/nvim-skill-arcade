-- Detects which of the player's own plugins / mappings the game can lean on.
local M = {}

-- group -> { title, suggest }
M.groups = {
  jump = { title = "jump / motion plugin", suggest = "flash.nvim or leap.nvim" },
  surround = { title = "surround plugin", suggest = "nvim-surround or mini.surround" },
  textobjects = { title = "extra text objects", suggest = "mini.ai or nvim-treesitter-textobjects" },
  comment = { title = "comment plugin", suggest = "Neovim 0.10+ has gc built in" },
  picker = { title = "fuzzy picker", suggest = "telescope.nvim, fzf-lua or snacks.nvim" },
  keyhints = { title = "key hints", suggest = "which-key.nvim" },
  files = { title = "file explorer", suggest = "oil.nvim or mini.files" },
  bookmarks = { title = "file bookmarks", suggest = "harpoon or grapple.nvim" },
  trouble = { title = "diagnostics list UI", suggest = "trouble.nvim" },
  replace = { title = "project search/replace", suggest = "grug-far.nvim or nvim-spectre" },
  multicursor = { title = "multiple cursors", suggest = "multicursor.nvim or vim-visual-multi" },
  move = { title = "line mover", suggest = "mini.move" },
  treesitter = { title = "treesitter", suggest = "nvim-treesitter" },
}

-- id, label, group, lazy plugin names, lua modules, runtime files, keys worth knowing
M.catalog = {
  { "flash", "flash.nvim", "jump", { "flash.nvim" }, { "flash" }, nil, "s{char}{char}{label}" },
  { "leap", "leap.nvim", "jump", { "leap.nvim" }, { "leap" }, nil, "s{char}{char}{label}" },
  { "hop", "hop.nvim", "jump", { "hop.nvim" }, { "hop" }, nil, ":HopWord" },
  { "mini.jump2d", "mini.jump2d", "jump", { "mini.jump2d" }, { "mini.jump2d" }, nil, "<CR>" },
  { "nvim-surround", "nvim-surround", "surround", { "nvim-surround" }, { "nvim-surround" }, nil, "ys{motion}{char} cs ds" },
  { "mini.surround", "mini.surround", "surround", { "mini.surround" }, { "mini.surround" }, nil, "sa sd sr" },
  { "vim-surround", "vim-surround", "surround", { "vim-surround" }, nil, { "plugin/surround.vim" }, "ys cs ds" },
  { "mini.ai", "mini.ai", "textobjects", { "mini.ai" }, { "mini.ai" }, nil, "a/i + f function, a argument, q quote" },
  { "ts-textobjects", "nvim-treesitter-textobjects", "textobjects", { "nvim-treesitter-textobjects" },
    { "nvim-treesitter-textobjects" }, nil, "af if ac ic" },
  { "targets", "targets.vim", "textobjects", { "targets.vim" }, nil, { "plugin/targets.vim" }, "ia aa in" },
  { "Comment", "Comment.nvim", "comment", { "Comment.nvim" }, { "Comment" }, nil, "gcc gc{motion}" },
  { "mini.comment", "mini.comment", "comment", { "mini.comment" }, { "mini.comment" }, nil, "gcc gc{motion}" },
  { "telescope", "telescope.nvim", "picker", { "telescope.nvim" }, { "telescope" }, nil, nil },
  { "fzf-lua", "fzf-lua", "picker", { "fzf-lua" }, { "fzf-lua" }, nil, nil },
  { "snacks", "snacks.nvim", "picker", { "snacks.nvim" }, { "snacks" }, nil, nil },
  { "mini.pick", "mini.pick", "picker", { "mini.pick" }, { "mini.pick" }, nil, nil },
  { "which-key", "which-key.nvim", "keyhints", { "which-key.nvim" }, { "which-key" }, nil, "<leader> and wait" },
  { "oil", "oil.nvim", "files", { "oil.nvim" }, { "oil" }, nil, "- opens the parent directory" },
  { "mini.files", "mini.files", "files", { "mini.files" }, { "mini.files" }, nil, nil },
  { "harpoon", "harpoon", "bookmarks", { "harpoon" }, { "harpoon" }, nil, nil },
  { "grapple", "grapple.nvim", "bookmarks", { "grapple.nvim" }, { "grapple" }, nil, nil },
  { "trouble", "trouble.nvim", "trouble", { "trouble.nvim" }, { "trouble" }, nil, ":Trouble diagnostics" },
  { "grug-far", "grug-far.nvim", "replace", { "grug-far.nvim" }, { "grug-far" }, nil, nil },
  { "spectre", "nvim-spectre", "replace", { "nvim-spectre" }, { "spectre" }, nil, nil },
  { "multicursor", "multicursor.nvim", "multicursor", { "multicursor.nvim" }, { "multicursor-nvim" }, nil, nil },
  { "vim-visual-multi", "vim-visual-multi", "multicursor", { "vim-visual-multi" }, nil, { "plugin/visual-multi.vim" }, "<C-n>" },
  { "mini.move", "mini.move", "move", { "mini.move" }, { "mini.move" }, nil, "<M-j> <M-k>" },
  { "nvim-treesitter", "nvim-treesitter", "treesitter", { "nvim-treesitter" }, { "nvim-treesitter" }, nil, nil },
}

local function lazy_plugins()
  local ok, cfg = pcall(require, "lazy.core.config")
  if ok and type(cfg.plugins) == "table" then
    return cfg.plugins
  end
end

local function lower_set(list)
  local s = {}
  for _, n in ipairs(list or {}) do
    s[n:lower()] = true
  end
  return s
end

local function runtime_has(path)
  return #vim.api.nvim_get_runtime_file(path, false) > 0
end

--- returns installed, loaded for one catalog entry
local function probe(e, plugins)
  local names, mods, files = e[4], e[5], e[6]
  if plugins then
    local want = lower_set(names)
    for key, p in pairs(plugins) do
      local name = (type(p) == "table" and p.name or key) or key
      if want[tostring(name):lower()] then
        local loaded = type(p) == "table" and p._ and p._.loaded ~= nil
        return true, loaded or false
      end
    end
  end
  for _, m in ipairs(mods or {}) do
    if package.loaded[m] then
      return true, true
    end
    local path = m:gsub("%.", "/")
    if runtime_has("lua/" .. path .. "/init.lua") or runtime_has("lua/" .. path .. ".lua") then
      return true, false
    end
  end
  for _, f in ipairs(files or {}) do
    if runtime_has(f) then
      return true, true
    end
  end
  return false, false
end

--- { plugins = {id -> {label, group, loaded, keys}}, groups = {group -> {labels...}}, lsp = n, nvim = "0.12" }
function M.detect()
  local plugins = lazy_plugins()
  local out = { plugins = {}, groups = {}, lazy = plugins ~= nil }
  for _, e in ipairs(M.catalog) do
    local installed, loaded = probe(e, plugins)
    if installed then
      out.plugins[e[1]] = { label = e[2], group = e[3], loaded = loaded, keys = e[7] }
      local g = out.groups[e[3]] or {}
      g[#g + 1] = e[2]
      out.groups[e[3]] = g
    end
  end
  out.lsp = #vim.lsp.get_clients()
  local v = vim.version()
  out.nvim = v.major .. "." .. v.minor
  out.native = {
    comment = vim.fn.has("nvim-0.10") == 1,
    diag_keys = vim.fn.has("nvim-0.10") == 1,
    qf_keys = vim.fn.has("nvim-0.11") == 1,
  }
  return out
end

--- does the user have a mapping on `lhs` in `mode`?  returns desc or rhs string, or nil
function M.mapping(mode, lhs)
  local m = vim.fn.maparg(lhs, mode, false, true)
  if type(m) == "table" and m.lhs then
    return m.desc or m.rhs or "(lua)"
  end
end

return M
