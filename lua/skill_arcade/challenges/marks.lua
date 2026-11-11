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
  {
    id = "last-change", title = "Back to the last edit", level = 2,
    brief = "Delete one character on line 20, scroll off to the last line, then jump back to the spot you edited.",
    lines = numbered(30),
    solution = "20GxG`.",
    check = function(c)
      return c.cursor and c.cursor[1] == 20 and c.lines[20] == "ow 20"
    end,
    why = "`` `. `` jumps to the exact position of the last change (`'.` to its line). `g;` / `g,` walk the whole change list.",
  },
  {
    id = "jumplist-forward", title = "Back twice, forward once", level = 4,
    brief = "Go to line 25, then line 50. Walk back through the jump list to line 1, then forward one step so you end up on line 25.",
    lines = numbered(60),
    solution = "25G50G<C-o><C-o><C-i>",
    expect = { cursor = { 25 } },
    why = "`<C-o>` goes back in the jump list, `<C-i>` forward. Every `G`, search, mark jump and `%` is a jump.",
  },
  {
    id = "mark-range-delete", title = "Delete between marks", level = 4,
    brief = "Set mark a on line 3 and mark b on line 6, then delete lines a through b with one command.",
    lines = numbered(10),
    solution = "3Gma6Gmb:'a,'bd<CR>",
    expect = { text = "row 1\nrow 2\nrow 7\nrow 8\nrow 9\nrow 10" },
    why = "Marks are line addresses: `:'a,'bd` deletes from mark a to mark b. Also `:'a,'bs/x/y/`, `:'a,.m0`, `:'<,'>` for a selection.",
  },
}
