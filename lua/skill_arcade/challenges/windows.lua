return {
  {
    id = "vsplit", title = "Side by side", level = 1,
    brief = "Open a vertical split (two windows next to each other).",
    text = "split me",
    solution = "<C-w>v",
    check = function(c)
      return c.in_arena and c.wins == 2 and vim.fn.winlayout()[1] == "row"
    end,
    why = "`<C-w>v` splits vertically, `<C-w>s` horizontally; `:vs file` / `:sp file` open a file in the split.",
  },
  {
    id = "split-down", title = "Down to the lower window", level = 2,
    brief = "Open a horizontal split and end up with the cursor in the LOWER window.",
    text = "split me",
    solution = "<C-w>s<C-w>j",
    check = function(c)
      local l = vim.fn.winlayout()
      return c.in_arena and l[1] == "col" and #l[2] == 2 and l[2][2][2] == c.cur_win
    end,
    why = "A new split opens on top and takes focus. `<C-w>j/k/h/l` move between windows; `<C-w>w` cycles.",
  },
  {
    id = "new-tab", title = "Fresh tab", level = 1,
    brief = "Open a new tab page and stay in it.",
    text = "tabs are layouts, not files",
    solution = ":tabnew<CR>",
    check = function(c)
      return c.extra_tabs == 1 and not c.in_arena
    end,
    why = "`:tabnew` (or `<C-w>T` to move a window to its own tab). `gt` / `gT` switch, `:tabclose` closes.",
  },
  {
    id = "alt-buffer", title = "Back to the other buffer", level = 2,
    brief = "You are in buffer B. Flip back to the buffer you were editing before (buffer A).",
    text = "this is buffer A",
    setup = function(x)
      local b = x.new_buf({ "this is buffer B" }, "b")
      vim.api.nvim_set_current_buf(b)
      x.state.a = x.buf
    end,
    solution = "<C-^>",
    check = function(c)
      return c.cur_buf == c.state.a
    end,
    helps = { picker = "your picker's buffer list gets you there, but <C-^> is one key" },
    why = "`<C-^>` (or `:b#`) toggles the alternate buffer. `:ls`, `:b {name}` and your buffer picker go further.",
  },
  {
    id = "only-window", title = "Clear the clutter", level = 2,
    brief = "Three windows are open. Keep only the window you are in.",
    text = "too many windows",
    setup = function()
      vim.cmd("vsplit")
      vim.cmd("split")
    end,
    solution = "<C-w>o",
    check = function(c)
      return c.in_arena and c.wins == 1
    end,
    why = "`<C-w>o` (`:only`) closes every other window; `<C-w>c` closes just this one; `<C-w>=` evens sizes.",
  },
  {
    id = "close-window", title = "Close this split", level = 1,
    brief = "Two windows are open. Close the one you are in.",
    text = "two windows, close one",
    setup = function()
      vim.cmd("vsplit")
    end,
    solution = "<C-w>c",
    check = function(c)
      return c.in_arena and c.wins == 1
    end,
    why = "`<C-w>c` (`:close`) closes the current window; `<C-w>o` keeps only this one; `:q` closes it too, and quits when it is the last.",
  },
  {
    id = "window-right", title = "Move to the right", level = 2,
    brief = "Two windows side by side. You are in the left one: move to the window on the right.",
    text = "left and right",
    setup = function()
      vim.cmd("vsplit")
      vim.cmd("wincmd h")
    end,
    solution = "<C-w>l",
    check = function(c)
      local l = vim.fn.winlayout()
      return c.in_arena and l[1] == "row" and #l[2] == 2 and l[2][2][2] == c.cur_win
    end,
    why = "`<C-w>h/j/k/l` move between windows by direction; `<C-w>w` cycles; `<C-w>p` goes to the previous one.",
  },
  {
    id = "move-to-tab", title = "Window to its own tab", level = 3,
    brief = "Two windows are open. Move the current window into a tab of its own.",
    text = "give me a tab",
    setup = function()
      vim.cmd("vsplit")
    end,
    solution = "<C-w>T",
    check = function(c)
      return c.extra_tabs == 1 and not c.in_arena
    end,
    why = "`<C-w>T` breaks the current window out into a new tab. `:tab split` copies it into a tab instead.",
  },
}
