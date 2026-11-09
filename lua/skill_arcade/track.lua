-- "Track" challenges: the buffer is a text-grid map, you start on one cell and must reach the goal cell with
-- motions, optionally touching ordered checkpoints on the way. Only the END STATE is judged (cursor on the goal,
-- every checkpoint visited in order, buffer untouched), never the keys, so your own keybinds and plugins work.
-- Optional rules (`forbid`) switch off whole key families on that map so the motions you have not practised
-- are the only way through: hjkl, arrows, mouse.
local M = {}

M.FORBID = { hjkl = true, arrows = true, mouse = true }
M.MAX_CHECKPOINTS = 6

local BLOCKED = {
  hjkl = { "h", "j", "k", "l", "gj", "gk" },
  arrows = { "<Left>", "<Right>", "<Up>", "<Down>" },
  mouse = { "<LeftMouse>", "<2-LeftMouse>", "<RightMouse>", "<MiddleMouse>", "<ScrollWheelUp>", "<ScrollWheelDown>" },
}
local RULE_NAME = { hjkl = "h j k l", arrows = "the arrow keys", mouse = "the mouse" }

--- human line for the HUD, e.g. "rules: no h j k l, no the arrow keys" -> "no h j k l | no the arrow keys"
function M.rules_line(t)
  local out = {}
  for _, f in ipairs(t.forbid or {}) do
    out[#out + 1] = "no " .. RULE_NAME[f]
  end
  return #out > 0 and table.concat(out, " | ") or nil
end

--- the check a track adds on top of "cursor on the goal, buffer untouched": all checkpoints visited in order
function M.check_fn(t)
  local n = #(t.checkpoints or {})
  if n == 0 then
    return nil
  end
  return function(ctx)
    return (ctx.state.cp or 0) >= n
  end
end

--- counts a checkpoint when the cursor lands exactly on the next one (checkpoints are ordered)
function M.step(t, state, pos)
  local nxt = (t.checkpoints or {})[(state.cp or 0) + 1]
  if nxt and pos[1] == nxt[1] and pos[2] == nxt[2] then
    state.cp = (state.cp or 0) + 1
  end
end

--- progress "n/m" for the HUD
function M.progress(t, state)
  local n = #(t.checkpoints or {})
  return n > 0 and string.format("checkpoints %d/%d", math.min(state.cp or 0, n), n) or nil
end

--- hooks one challenge buffer: checkpoint tracking and the key rules. Everything is buffer-local.
function M.attach(ch, buf, state, group)
  local t = ch.track
  if not t then
    return
  end
  state.cp = 0
  if #(t.checkpoints or {}) > 0 then
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
      group = group, buffer = buf,
      callback = function()
        M.step(t, state, vim.api.nvim_win_get_cursor(0))
      end,
    })
  end
  for _, family in ipairs(t.forbid or {}) do
    local msg = "SkillArcade: " .. RULE_NAME[family] .. " are off on this track"
    for _, lhs in ipairs(BLOCKED[family] or {}) do
      vim.keymap.set({ "n", "x", "o" }, lhs, function()
        vim.api.nvim_echo({ { msg, "WarningMsg" } }, false, {})
      end, { buffer = buf, nowait = true, desc = "skill-arcade track rule" })
    end
  end
end

return M
