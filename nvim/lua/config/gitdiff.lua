-- Two-pane git diff of the current file (Space+g+d): opens Diffview
-- scoped to this file with the file list hidden, or closes it when open.
-- Diffview always opens its file panel, so open + DiffviewToggleFiles is
-- one synchronous step (verified headless: 3 windows -> 2). Inside, move
-- with Space+h / Space+l, cycle files with Tab / Shift-Tab, and toggle
-- the file list with Space+b (Diffview's own binding).
local M = {}

local function ensure_loaded()
  local ok_lazy, lazy = pcall(require, 'lazy')
  if ok_lazy then pcall(lazy.load, { plugins = { 'diffview.nvim' } }) end
end

function M.toggle_diff()
  ensure_loaded()
  local ok, lib = pcall(require, 'diffview.lib')
  if not ok then
    vim.notify('diffview not loaded', vim.log.levels.WARN)
    return
  end
  if lib.get_current_view() ~= nil then
    vim.cmd('DiffviewClose')
    return
  end
  local file = vim.fn.expand('%:p')
  if file == '' then
    vim.notify('no file in buffer', vim.log.levels.WARN)
    return
  end
  vim.cmd('DiffviewOpen -- ' .. vim.fn.fnameescape(file))
  vim.cmd('DiffviewToggleFiles')
end

return M
