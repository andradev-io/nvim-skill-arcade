-- World 1, Meadow: moving around. Maps are tracks (S start, X goal, 1..6 checkpoints, only the end state counts).
-- A stage: { title, teach = "the new thing", brief = "the task", map, solution, why, forbid?, boss? }
-- `teach` is shown first in the HUD; `solution` is replayed by the tests, and its key count is the 3-star par.
return {
  {
    title = "One step right", teach = "l moves the cursor one cell right.",
    brief = "Walk from S to X.",
    map = "S....X",
    solution = "lllll",
    why = "l is right, h is left, j is down, k is up. They sit under your right hand so you never leave the home row.",
  },
  {
    title = "Down we go", teach = "j moves down, k moves up.",
    brief = "Walk from S down to X.",
    map = "S\n.\n.\nX",
    solution = "jjj",
    why = "j points down like the hook of the letter. k is its opposite.",
  },
  {
    title = "Back the other way", teach = "h moves one cell left.",
    brief = "Walk from S back to X.",
    map = "X....S",
    solution = "hhhhh",
    why = "h and l are the left/right pair, just like k and j are up/down.",
  },
  {
    title = "Down the steps", teach = "Mix the four keys.",
    brief = "Walk from S to X in the corner.",
    map = "S.....\n......\n.....X",
    solution = "jjlllll",
    why = "Any mix works. Later stages ask for fewer keys to earn three stars.",
  },
  {
    title = "Long jump", teach = "A count repeats a motion: 16l moves sixteen cells.",
    brief = "Reach X without pressing l sixteen times.",
    map = "S...............X",
    solution = "16l",
    why = "{count}{motion} is everywhere in Vim: 5j, 3w, 10l. Type the number, then the key.",
  },
  {
    title = "Word hopping", teach = "w jumps to the start of the next word.",
    brief = "Land on the X, which starts the fifth word.",
    map = "S one two three four X",
    solution = "5w",
    why = "w hops word to word. With a count, 5w hops five words. W does the same but only stops at spaces.",
  },
  {
    title = "And back", teach = "b jumps back to the start of a word.",
    brief = "Go back to the X at the start of the line.",
    map = "X one two three four S",
    solution = "5b",
    why = "b is the mirror of w. Remember them as 'word' and 'back'.",
  },
  {
    title = "End of the word", teach = "e jumps to the END of a word.",
    brief = "Reach the X, which ends the second word.",
    map = "Sab cdX ef",
    solution = "ee",
    why = "e stops on the last letter of a word. w, b and e together cover most horizontal movement.",
  },
  {
    title = "Edge to edge", teach = "0 goes to the start of the line, $ to the end.",
    brief = "Touch checkpoint 1 at the line start, then finish on X at the line end.",
    map = "1.....S.....X",
    solution = "0$",
    why = "0 is the first column, $ is the last character. ^ is the first non-blank, which matters in indented code.",
  },
  {
    title = "Boss: the meadow gate", boss = true,
    teach = "Everything so far: counts, words, line ends.",
    brief = "Touch 1, then 2, then finish on X. Fewest keys wins.",
    map = "S go 1 fast\nthen 2 jump\nto the X",
    solution = "wwjj$",
    why = "ww lands on the 1; j keeps your column and lands on the 2; j then $ ends on X. Fewer than twenty h/j/k/l presses.",
  },
}
