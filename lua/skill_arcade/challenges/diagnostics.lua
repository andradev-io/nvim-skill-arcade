-- Diagnostics are planted by the game in its own namespace, so these work with or without a language server.
-- They exercise the same built-in diagnostic mappings and API your LSP uses.
local function code(n)
  local t = {}
  for i = 1, n do
    t[i] = "local value_" .. i .. " = compute(" .. i .. ")"
  end
  return t
end

local function plant(x)
  local W = vim.diagnostic.severity.WARN
  vim.diagnostic.set(x.diag_ns, x.buf, {
    { lnum = 3, col = 0, end_col = 5, severity = W, message = "ARC: unused variable 'tmp'", source = "arcade" },
    { lnum = 8, col = 0, end_col = 5, severity = W, message = "ARC: shadowed name 'value'", source = "arcade" },
  })
end

return {
  {
    id = "next", title = "Next diagnostic", level = 1,
    brief = "Jump to the first diagnostic below the cursor.",
    lines = code(10),
    setup = plant,
    solution = "]d",
    expect = { cursor = { 4 } },
    helps = { trouble = "a diagnostics list shows every problem at once so you can jump to the one you want" },
    why = "`]d` / `[d` move between diagnostics (Neovim 0.10+ defaults). `]D` / `[D` jump to the last / first.",
  },
  {
    id = "float", title = "Read the message", level = 2,
    brief = "The cursor sits on a line with a diagnostic. Show its message in a floating window.",
    lines = code(10),
    cursor = { 4, 0 },
    setup = plant,
    solution = "<C-w>d",
    check = function(c)
      for _, f in ipairs(c.floats) do
        if table.concat(f.lines, "\n"):find("ARC:", 1, true) then
          return true
        end
      end
      return false
    end,
    why = "`<C-w>d` (or `vim.diagnostic.open_float()`) shows the line's diagnostics; `K` is hover for LSP docs.",
  },
  {
    id = "to-quickfix", title = "All problems in a list", level = 3,
    brief = "Send all diagnostics to the quickfix list.",
    lines = code(10),
    setup = plant,
    solution = ":lua vim.diagnostic.setqflist()<CR>",
    check = function(c)
      local n = 0
      for _, it in ipairs(c.qf.items or {}) do
        if (it.text or ""):find("ARC:", 1, true) then
          n = n + 1
        end
      end
      return n >= 2
    end,
    helps = { trouble = "`:Trouble diagnostics` / `:Trouble qflist` give the same list in a nicer view; any mapping you made for setqflist counts" },
    why = "`vim.diagnostic.setqflist()` / `setloclist()` fill the lists; then `]q`, `:cdo` and friends work on them.",
  },
  {
    id = "prev-diag", title = "Previous diagnostic", level = 1,
    brief = "The cursor is at the bottom. Jump to the closest diagnostic ABOVE it.",
    lines = code(10),
    cursor = { 10, 0 },
    setup = plant,
    solution = "[d",
    expect = { cursor = { 9 } },
    why = "`[d` goes to the previous diagnostic, `]d` to the next. They wrap or stop at the ends depending on your config.",
  },
  {
    id = "last-diag", title = "Last diagnostic", level = 2,
    brief = "Jump to the LAST diagnostic in the buffer in one command (you start at the top).",
    lines = code(10),
    setup = plant,
    solution = "]D",
    expect = { cursor = { 9 } },
    why = "`]D` jumps to the last diagnostic and `[D` to the first (Neovim 0.11+), no matter where you are.",
  },
}
