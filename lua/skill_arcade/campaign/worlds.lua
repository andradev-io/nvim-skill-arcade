-- The campaign map: worlds in play order. To add a world, write `campaign/<module>.lua` (a list of stages, see
-- world1.lua) and add one line here. Worlds unlock in this order; nothing else needs to change.
--
-- Planned (see README, "Campaign"): 6 Registers and macros, 7 Files, windows and marks, 8 Boss rush with the
-- h j k l and the arrow keys switched off.
return {
  { id = "w1", name = "Meadow", topic = "Moving around", module = "skill_arcade.campaign.world1",
    blurb = "Cursor first: h j k l, counts, words, line ends." },
  { id = "w2", name = "Quarry", topic = "Editing", module = "skill_arcade.campaign.world2",
    blurb = "Delete, insert, change, copy, paste, undo, repeat." },
  { id = "w3", name = "Forest", topic = "Finding your way", module = "skill_arcade.campaign.world3",
    blurb = "f t ; , search, n, *, %, paragraphs, gg and G." },
  { id = "w4", name = "Temple", topic = "Text objects", module = "skill_arcade.campaign.world4",
    blurb = "diw, ci\", di(, ci{, dap: act on a thing, not on keys." },
  { id = "w5", name = "Peak", topic = "Visual mode", module = "skill_arcade.campaign.world5",
    blurb = "v, V and <C-v>: select first, then act, even on a column." },
}
