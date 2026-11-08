local function numbered(n, special)
  local t = {}
  for i = 1, n do
    t[i] = special and special[i] or ("row " .. i)
  end
  return t
end

return {
  {
    id = "two-marks", title = "Drop two marks", level = 2,
    brief = "Set mark a on line 3 and mark b on line 11.",
    lines = numbered(15),
    solution = "3Gma11Gmb",
    expect = { marks = { a = 3, b = 11 } },
    helps = { bookmarks = "bookmark plugins (harpoon/grapple) are marks for files; here plain marks do the job" },
    why = "`m{a-z}` sets a mark, `'a` jumps to its line, `` `a `` to its exact position. Capital marks work across files.",
  },
  {
    id = "jump-back", title = "Visit and return", level = 2,
    brief = "Go to line 25, then come back to where you started (line 1).",
    lines = numbered(30),
    solution = "25G<C-o>",
    check = function(c)
      if not c.cursor or c.cursor[1] ~= 1 then
        return false
      end
      local jl = vim.fn.getjumplist()[1]
      for _, j in ipairs(jl) do
        if j.lnum == 25 and j.bufnr == c.buf then
          return true
        end
      end
      return false
    end,
    why = "`<C-o>` walks back the jump list, `<C-i>` forward. ` `` ` toggles between the last two positions.",
  },
}
