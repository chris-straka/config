-- Smart horizontal pane moves (Space+h / Space+l): step to the window on
-- that side when one exists (Diffview panes included), else fall back —
-- left edge focuses the file tree, right edge is a silent no-op like a
-- bare wincmd at the edge. no-neck-pain padding ("gutters") is never a
-- destination: it is stepped straight over, and the start window is
-- restored when nothing real lies that way, so the cursor cannot park
-- in a gutter. Plain wincmd moves only: one Ghostty tab = one project,
-- so no tab or session logic here.
local M = {}

-- True for windows the cursor must never rest in: the no-neck-pain
-- centering pads, which default to the no-neck-pain filetype (see
-- plugins/ui.lua: no custom buffers filetype is set). The name match is
-- belt and suspenders in case that default ever changes upstream.
local function is_pad(win)
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.bo[buf].filetype == 'no-neck-pain' then return true end
  return vim.api.nvim_buf_get_name(buf):match('no%-neck%-pain') ~= nil
end

---@param dir string 'h' | 'l'
---@return boolean true when the window changed to a real window
local function step(dir)
  local start = vim.api.nvim_get_current_win()
  vim.cmd('wincmd ' .. dir)
  -- Bounded walk: each iteration moves one window over, and a full lap
  -- without finding a real window (or a few spare steps past it) means
  -- there is nothing real in that direction — e.g. the main buffer is
  -- closed and only tree plus pads remain. Restore the start window and
  -- report failure instead of looping or stranding the cursor in a pad.
  for _ = 1, 10 do
    local cur = vim.api.nvim_get_current_win()
    if not is_pad(cur) then return cur ~= start end
    vim.cmd('wincmd ' .. dir)
    if vim.api.nvim_get_current_win() == start then break end
  end
  if vim.api.nvim_get_current_win() ~= start then
    vim.api.nvim_set_current_win(start)
  end
  return false
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
