-- Regression: Space+h / Space+l step between windows; at the left edge
-- Space+h focuses the file tree, Space+l is a no-op. Needs the real
-- plugins (tree fallback), so NOT --noplugin. Run:
--   nvim --headless --cmd "set columns=250" --cmd "set lines=60" /tmp/window_nav_target.txt -c "luafile ~/.config/nvim/tests/window_nav.lua"
local failures = 0
local function check(name, ok)
  if ok then
    print('PASS: ' .. name)
  else
    failures = failures + 1
    print('FAIL: ' .. name)
  end
end

local nav = require('config.window_nav')
check('window_nav exposes left', type(nav.left) == 'function')
check('window_nav exposes right', type(nav.right) == 'function')
check('<leader>h mapped', vim.fn.maparg(' h', 'n') ~= '')
check('<leader>l mapped', vim.fn.maparg(' l', 'n') ~= '')

-- Two windows: left/right step between them, never touching the tree.
vim.cmd('only')
vim.cmd('vsplit')
local left_win = vim.fn.win_getid(vim.fn.winnr('h'))
local right_win = vim.fn.win_getid(vim.fn.winnr('l'))
check('vsplit made two windows', left_win ~= right_win)
vim.api.nvim_set_current_win(right_win)
nav.left()
check('left() moves to the left window', vim.api.nvim_get_current_win() == left_win)
local api = require('nvim-tree.api')
check('left() did not open the tree', not api.tree.is_visible())
nav.right()
check('right() moves to the right window', vim.api.nvim_get_current_win() == right_win)

-- Single window: left edge falls back to the tree, right edge no-ops.
vim.cmd('only')
local single = vim.api.nvim_get_current_win()
nav.right()
check('right() at right edge stays put', vim.api.nvim_get_current_win() == single)
nav.left()
vim.wait(600, function() return false end)
check('left() at left edge opened the tree', api.tree.is_visible())
check('left() at left edge focused the tree', api.tree.is_tree_buf())
pcall(api.tree.close)
if failures > 0 then
  print(failures .. ' check(s) failed')
  os.exit(1)
end
print('window nav checks passed')
vim.cmd('qa!')
