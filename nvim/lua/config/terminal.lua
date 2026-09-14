-- Focused-terminal exit, shared by <leader>tR and Alt+X (see
-- config/keymaps.lua). Types `exit` + Enter into the focused terminal's
-- shell job — the plain-`exit` equivalent — so the shell ends and the
-- float goes away; reopen with Alt+N for a fresh shell.
local M = {}

function M.exit_focused()
  local ok, terms = pcall(require, 'toggleterm.terminal')
  if not ok then return end
  local id = terms.get_focused_id()
  if not id then
    vim.notify('no focused terminal to exit', vim.log.levels.WARN)
    return
  end
  local term = terms.get(id, true)
  if term and term.job_id then vim.fn.chansend(term.job_id, 'exit\n') end
end

return M
