-- Key-notation helpers: split "ci\"x<Esc>" into keys, count them, replay them.
local M = {}

function M.tokens(s)
  local out, i, n = {}, 1, #s
  while i <= n do
    local name = s:sub(i, i) == "<" and s:match("^<[%w%-_]+>", i) or nil
    if name and #name <= 14 then
      out[#out + 1] = name
      i = i + #name
    else
      local ch = s:match("^[%z\1-\127\194-\244][\128-\191]*", i) or s:sub(i, i)
      out[#out + 1] = ch
      i = i + #ch
    end
  end
  return out
end

function M.count(s)
  return #M.tokens(s)
end

--- replay keys as typed, with remapping on, so default mappings like ]d work (used by tests)
function M.feed(s)
  vim.api.nvim_feedkeys(vim.keycode(s), "tx", false)
end

return M
