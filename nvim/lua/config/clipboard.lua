-- Cmd+C copy plumbing for presses with no live visual selection (the <D-c>
-- maps in config/keymaps/general.lua and config/keymaps/terminal.lua).
-- Ghostty forwards every Cmd+C to nvim as <D-c> (super+c -> CSI-u, see
-- ghostty/shared-keybinds.conf), so a press with nothing selected used to
-- silently no-op while the clipboard kept its previous — stale — content,
-- which pasted as a "half showed up" mystery. copy_or_warn makes that
-- press honest: it copies the last selection in this buffer when there is
-- one, and otherwise warns and names the emulator-side chord.
local M = {}

-- True when the previous visual marks ('<, '>) point at a real position in
-- the current buffer: a just-released mouse drag, or a selection cleared
-- with Esc. Marks from another buffer are never trusted — Cmd+C means
-- "what I highlighted here", not somewhere else. Buffer-scoped reads, not
-- getpos: getpos reports visual marks with bufnr 0, which cannot tell
-- "this buffer" from "no selection anywhere".
function M.marks_in_current_buffer()
  local buf = vim.api.nvim_get_current_buf()
  local from = vim.api.nvim_buf_get_mark(buf, '<')
  local to = vim.api.nvim_buf_get_mark(buf, '>')
  return from[1] > 0 and to[1] > 0
end

-- One-line confirmation of what just landed on the clipboard: line count
-- plus the first line's head. A resurrected (no-longer-visible) selection
-- must be verifiable at a glance — the confirmation is what keeps a stale
-- copy from becoming another silent paste surprise.
local function confirm()
  local text = vim.fn.getreg('+')
  local first = vim.split(text, '\n', { plain = true })[1] or ''
  local head = first:sub(1, 60)
  if #first > 60 then head = head .. '…' end
  local n = select(2, text:gsub('\n', '')) + 1
  if text:sub(-1) == '\n' then n = n - 1 end
  vim.notify(string.format("Copied %d %s: '%s'", n, n == 1 and 'line' or 'lines', head))
end

-- Copy the last visual selection in this buffer to the system clipboard,
-- or warn when there is nothing nvim-side to copy. A live visual
-- selection never lands here (it takes the visual <D-c> map instead), so
-- this only ever resurrects marks — gv preserves their char/line/block
-- shape, where a '<,'> range yank would silently go linewise.
---@return string 'copied' or 'empty' (handy for tests)
function M.copy_or_warn()
  vim.cmd('stopinsert') -- Terminal-Insert -> Terminal-Normal; no-op elsewhere
  if M.marks_in_current_buffer() and pcall(vim.cmd, 'normal! gv"+y') and vim.fn.getreg('+') ~= '' then
    confirm()
    return 'copied'
  end
  vim.notify('Nothing selected — Shift+Cmd+C copies Ghostty-side selections', vim.log.levels.WARN)
  return 'empty'
end

return M
