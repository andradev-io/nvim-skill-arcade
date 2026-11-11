local function with_marker(n, marker, rows)
  local t = {}
  for i = 1, n do
    t[i] = vim.tbl_contains(rows, i) and (marker .. " item at " .. i) or ("plain line " .. i)
  end
  return t
end

return {
  {
    id = "open-list", title = "Open the list", level = 1,
    brief = "Open the quickfix window (your list-UI plugin counts too).",
    text = "nothing to see",
    solution = ":copen<CR>",
    check = function(c)
      for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local b = vim.api.nvim_win_get_buf(w)
        if vim.bo[b].buftype == "quickfix" or vim.bo[b].filetype == "Trouble" then
          return true
        end
      end
      return false
    end,
    helps = { trouble = "`:Trouble qflist toggle` is a nicer quickfix window" },
    why = "`:copen` opens, `:cclose` closes; `:cwindow` opens only when there are entries.",
  },
  {
    id = "jump-third", title = "Third hit", level = 2,
    brief = "The quickfix list holds four TODO hits. Jump to the THIRD one.",
    lines = with_marker(12, "TODO", { 2, 5, 8, 11 }),
    setup = function(x)
      local items = {}
      for _, row in ipairs({ 2, 5, 8, 11 }) do
        items[#items + 1] = { bufnr = x.buf, lnum = row, col = 1, text = x.lines[row] }
      end
      vim.fn.setqflist({}, "r", { title = "arcade todo", items = items, idx = 1 })
    end,
    solution = ":cc 3<CR>",
    check = function(c)
      return c.cur_buf == c.buf and c.qf.idx == 3 and c.cursor and c.cursor[1] == 8
    end,
    why = "`:cc 3` jumps to entry 3; `]q` / `[q` (0.11+) or `:cnext` / `:cprev` step; `:cfirst` / `:clast` hit the ends.",
  },
  {
    id = "grep-fill", title = "Fill the list", level = 3,
    brief = "Fill the quickfix list with every line that contains FIXME (any method).",
    lines = with_marker(14, "FIXME", { 3, 7, 12 }),
    setup = function()
      vim.fn.setqflist({}, "r")
    end,
    solution = ":vim /FIXME/ %<CR>",
    check = function(c)
      local items = c.qf.items or {}
      if #items ~= 3 then
        return false
      end
      for _, it in ipairs(items) do
        if not it.text:find("FIXME", 1, true) then
          return false
        end
      end
      return true
    end,
    helps = { picker = "a picker's quickfix action (send selected/all to quickfix) fills the list from a live grep" },
    why = "`:vimgrep /pat/ %` (internal) or `:grep` (external rg) fill the list; then `:cdo` / `:cfdo` act on every entry.",
  },
  {
    id = "next-entry", title = "Next hit", level = 1,
    brief = "The quickfix list holds four TODO hits and you are on the first. Go to the next one.",
    lines = with_marker(12, "TODO", { 2, 5, 8, 11 }),
    setup = function(x)
      local items = {}
      for _, row in ipairs({ 2, 5, 8, 11 }) do
        items[#items + 1] = { bufnr = x.buf, lnum = row, col = 1, text = x.lines[row] }
      end
      vim.fn.setqflist({}, "r", { title = "arcade todo", items = items, idx = 1 })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
    end,
    solution = ":cnext<CR>",
    check = function(c)
      return c.cur_buf == c.buf and c.qf.idx == 2 and c.cursor and c.cursor[1] == 5
    end,
    why = "`:cnext` / `:cprev` step through the list (`]q` / `[q` in Neovim 0.11+). `:cc N` jumps to entry N.",
  },
  {
    id = "last-entry", title = "Last hit", level = 2,
    brief = "The quickfix list holds four TODO hits. Jump straight to the LAST one.",
    lines = with_marker(12, "TODO", { 2, 5, 8, 11 }),
    setup = function(x)
      local items = {}
      for _, row in ipairs({ 2, 5, 8, 11 }) do
        items[#items + 1] = { bufnr = x.buf, lnum = row, col = 1, text = x.lines[row] }
      end
      vim.fn.setqflist({}, "r", { title = "arcade todo", items = items, idx = 1 })
    end,
    solution = ":clast<CR>",
    check = function(c)
      return c.cur_buf == c.buf and c.qf.idx == 4 and c.cursor and c.cursor[1] == 11
    end,
    why = "`:clast` / `:cfirst` jump to the ends of the list; `:cnfile` skips to the next file.",
  },
  {
    id = "cdo-replace", title = "Edit every hit", level = 5,
    brief = "The quickfix list holds the three TODO lines. Replace TODO with DONE on every entry of the list, and nowhere else.",
    lines = with_marker(8, "TODO", { 2, 5, 7 }),
    setup = function(x)
      local items = {}
      for _, row in ipairs({ 2, 5, 7 }) do
        items[#items + 1] = { bufnr = x.buf, lnum = row, col = 1, text = x.lines[row] }
      end
      vim.fn.setqflist({}, "r", { title = "arcade todo", items = items, idx = 1 })
    end,
    solution = ":cdo s/TODO/DONE/<CR>",
    expect = {
      text = "plain line 1\nDONE item at 2\nplain line 3\nplain line 4\nDONE item at 5\nplain line 6\nDONE item at 7\nplain line 8",
    },
    why = "`:cdo {cmd}` runs a command on every entry of the quickfix list (`:cfdo` once per file). Add `| update` to save as you go.",
  },
}
