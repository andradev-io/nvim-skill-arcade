-- Tracks: the buffer is a text-grid map. Reach the goal cell, touching the numbered checkpoints in order, with
-- motions. Markers in the map: S = start, X = goal, 1..6 = checkpoints. A spec may give `start`, `goal` or
-- `checkpoints` explicitly instead ({row, col}, row 1-based, col 0-based). `forbid` switches whole key families off.
local function build(spec)
  local lines = vim.split(spec.map, "\n", { plain = true })
  local start, goal, cps = spec.start, spec.goal, spec.checkpoints
  local found = {}
  for r, line in ipairs(lines) do
    for c = 1, #line do
      local ch = line:sub(c, c)
      if ch == "S" and not start then
        start = { r, c - 1 }
      elseif ch == "X" and not goal then
        goal = { r, c - 1 }
      elseif ch:match("^[1-6]$") and not spec.checkpoints then
        found[tonumber(ch)] = { r, c - 1 }
      end
    end
  end
  if not cps and #found > 0 then
    cps = {}
    for i = 1, #found do
      cps[i] = found[i]
    end
  end
  return {
    id = spec.id, title = spec.title, level = spec.level, brief = spec.brief, text = spec.map, cursor = start,
    track = { goal = goal, checkpoints = cps, forbid = spec.forbid },
    solution = spec.solution, why = spec.why, hint = spec.hint, par_seconds = spec.par_seconds,
  }
end

return {
  build({
    id = "straight-road", title = "Straight road", level = 1,
    brief = "Run from S to X along the road, in as few keys as you can.",
    map = [[
S........................X]],
    solution = "$",
    why = "$ jumps to the end of the line in one key. Holding l would be 24 keys.",
  }),
  build({
    id = "word-hop", title = "Hop to the marker", level = 1,
    brief = "Start at S and land on the X.",
    map = [[
Start here, hop skip jump leap X then the rest of the road]],
    solution = "fX",
    why = "f{char} jumps to the next {char} on the line; ; repeats it and , goes back.",
  }),
  build({
    id = "way-down", title = "All the way down", level = 1,
    brief = "Go from S down to the X at the bottom.",
    map = [[
S
.
.
.
.
.
X]],
    solution = "G",
    why = "G jumps to the last line and gg to the first; {n}G goes to line n.",
  }),
  build({
    id = "bracket-jump", title = "Over the brackets", level = 2,
    brief = "You stand on the opening ( . Land on its matching ) .",
    map = [[
(~~~~[~~~~{~~}~~~~]~~~~)~~~]],
    start = { 1, 0 }, goal = { 1, 23 },
    solution = "%",
    why = "% jumps to the partner of the bracket under the cursor, skipping every other pair in between.",
  }),
  build({
    id = "paragraph-hop", title = "Block to block", level = 2,
    brief = "Start at S and reach the X, which opens the third block.",
    map = [[
S the first block
of text

the second block
of text

X the third block
more text]],
    solution = "}}j",
    why = "} jumps to the next blank line and { to the previous one, so paragraphs are one key each.",
  }),
  build({
    id = "search-the-wall", title = "Find the door", level = 3,
    brief = "Start at S and reach the door marked X.",
    map = [[
Start of the wall of words
nothing to see here, keep reading
more words and more words
a long hallway of letters
and then a door marked X
beyond it only silence]],
    solution = "/X<CR>",
    why = "/ searches the whole buffer and lands on the match; n and N repeat it in both directions.",
  }),
  build({
    id = "ordered-stops", title = "Three stops, then out", level = 3,
    brief = "Touch checkpoints 1, 2 and 3 in that order, then reach X.",
    map = [[
S ..1.. ..2.. ..3.. ..X..]],
    solution = "f1f2f3fX",
    why = "Each f lands exactly on a checkpoint. The order matters: reaching X early does not count until the stops are done.",
  }),
  build({
    id = "mark-and-return", title = "Out and back", level = 4,
    brief = "Touch the checkpoint at the bottom, then come back to exactly where you started.",
    map = [[
* home
.
.
.
* far away]],
    start = { 1, 0 }, goal = { 1, 0 }, checkpoints = { { 5, 0 } },
    solution = "maG`a",
    why = "ma drops a mark, `a returns to its exact position (' only returns to the line). <C-o> also takes you back.",
  }),
  build({
    id = "grid-run", title = "Grid run without hjkl", level = 4,
    brief = "Touch 1 then 2, then reach X. h, j, k and l are switched off on this map.",
    forbid = { "hjkl" },
    map = [[
S.........
..........
....2.....
.1........
..........
.........X]],
    solution = "4Gf1-f2G$",
    why = "{n}G jumps to a line, - and + step a line, f{char} lands on a character, $ ends the line: no hjkl needed.",
  }),
  build({
    id = "bracket-relay", title = "Bracket relay", level = 5,
    brief = "Touch the ( , then its ) , then reach X. No hjkl and no arrow keys.",
    forbid = { "hjkl", "arrows" },
    map = [[
S.....................
..(...............)...
......................
......................
...................X..]],
    checkpoints = { { 2, 2 }, { 2, 18 } },
    solution = "2Gf(%GfX",
    why = "2G picks the line, f( lands on the bracket, % jumps to its partner and G + fX finishes: five different motions, no hjkl.",
  }),
}
