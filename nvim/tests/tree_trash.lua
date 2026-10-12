-- Regression: trashing the open file from the tree keeps the layout.
-- nvim-tree's own cleanup deleted the buffer, which closed the code
-- window when it was the only file (the pads swallowed the screen) and
-- closed the tree otherwise. Needs the real plugins and the `trash` CLI.
-- Run from a scratch dir holding a.txt and b.txt (both get trashed):
--   nvim --headless --cmd "set columns=250" --cmd "set lines=60" b.txt a.txt -c "luafile ~/.config/nvim/tests/tree_trash.lua"
local failures = 0
local function check(name, ok)
  if ok then
    print('PASS: ' .. name)
  else
    failures = failures + 1
    print('FAIL: ' .. name)
  end
end

local function no() return false end
vim.wait(15000, function()
  local ok, state = pcall(require, 'no-neck-pain.state')
  return ok and state.enabled
end)
local api = require('nvim-tree.api')
local trash = require('nvim-tree.actions.fs.trash')

local function code_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype == '' and vim.bo[buf].filetype ~= 'NvimTree' and vim.bo[buf].filetype ~= 'no-neck-pain' then
      return win
    end
  end
end

-- Trash the file the code window shows, from the tree, and compare.
local function trash_current(label)
  local win = code_win()
  local path = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
  require('config.tree').focus(true)
  vim.wait(800, no)
  local width = vim.api.nvim_win_get_width(win)
  local node = api.tree.get_node_under_cursor()
  check(label .. ': tree cursor on the open file', node ~= nil and node.absolute_path == path)
  trash.remove(node)
  vim.wait(2000, function() return vim.fn.filereadable(path) == 0 end)
  vim.wait(300, no)
  check(label .. ': file trashed', vim.fn.filereadable(path) == 0)
  check(label .. ': tree still open', api.tree.is_visible())
  local after = code_win()
  check(label .. ': code window kept', after == win)
  check(label .. ': code window width kept', after ~= nil and vim.api.nvim_win_get_width(after) == width)
  return after
end

-- Two files: the window moves on to the other one.
local win = trash_current('two files')
check(
  'two files: other file shown',
  win ~= nil and vim.fn.fnamemodify(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)), ':t') == 'a.txt'
)
api.tree.close()
vim.wait(300, no)
-- Last file: the window stays, empty.
trash_current('last file')

print(failures == 0 and 'ALL PASS' or (failures .. ' FAILED'))
vim.cmd(failures == 0 and 'qa!' or 'cq!')
