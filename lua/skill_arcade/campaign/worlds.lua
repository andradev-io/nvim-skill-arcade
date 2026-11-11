-- The campaign map: worlds in play order. To add a world, write `campaign/<module>.lua` (a list of stages, see
-- world1.lua) and add one line here. Worlds unlock in this order; nothing else needs to change.
--
-- Planned (see README, "Campaign"): 3 Search, 4 Text objects, 5 Visual mode, 6 Registers and macros, 7 Files,
-- windows and marks, 8 Boss rush with the h j k l and the arrow keys switched off.
return {
  { id = "w1", name = "Meadow", topic = "Moving around", module = "skill_arcade.campaign.world1",
    blurb = "Cursor first: h j k l, counts, words, line ends." },
  { id = "w2", name = "Quarry", topic = "Editing", module = "skill_arcade.campaign.world2",
    blurb = "Delete, insert, change, copy, paste, undo, repeat." },
}
