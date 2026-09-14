-- Cmd+W target: a normal empty buffer means the tab is done, anything
-- else is just a buffer close (see keymaps/workspace.lua). Empty is an
-- unnamed, unmodified, normal buffer whose lines are all blank.
local M = {}

---@param bufnr? integer buffer to test (defaults to current)
---@return boolean true when the buffer counts as empty
function M.is_empty_buffer(bufnr)
  local buf = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buf) then return false end
  if vim.bo[buf].buftype ~= '' then return false end
  if vim.fn.bufname(buf) ~= '' then return false end
  if vim.bo[buf].modified then return false end
  for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    if line:find('%S') then return false end
  end
  return true
end

-- Close the current buffer, or the tab when it is empty. The tab path is
-- a guarded :tabclose only — never a window close (:quit/:close) and
-- never :qa. On the last tab :tabclose fails, so pcall keeps it a no-op.
---@return string 'tabclose' when the buffer was empty, 'buffer' otherwise
function M.close_buffer_or_tab()
  if M.is_empty_buffer() then
    pcall(vim.cmd, 'tabclose')
    return 'tabclose'
  end
  MiniBufremove.delete(0, true)
  return 'buffer'
end

return M
