-- Smart horizontal pane moves (Space+h / Space+l): step to the window on
-- that side when one exists (Diffview panes included), else fall back —
-- left edge focuses the file tree, right edge is a silent no-op like a
-- bare wincmd at the edge. Plain wincmd moves only: one Ghostty tab = one
-- project, so no tab or session logic here.
local M = {}

---@param dir string 'h' | 'l'
---@return boolean true when the window changed
local function step(dir)
  local before = vim.api.nvim_get_current_win()
  vim.cmd('wincmd ' .. dir)
  return vim.api.nvim_get_current_win() ~= before
end

-- Left: prefer the window on the left; at the left edge focus the tree.
function M.left()
  if step('h') then return end
  require('config.tree').focus(false)
end

-- Right: prefer the window on the right; at the right edge do nothing.
function M.right()
  step('l')
end

return M
