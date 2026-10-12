-- Hover preview: moving the tree cursor shows the node in the code
-- window (files as a read-only copy, folders as a listing), the window's
-- own file shows itself, and leaving the tree restores the original
-- buffer. Needs the real plugins, so NOT --noplugin. Run:
--   nvim --headless --cmd "set columns=250" --cmd "set lines=60" -c "luafile ~/.config/nvim/tests/tree_preview.lua"
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

-- Fixture: root/{a.lua, b.txt, sub/{inner.md}}; start editing b.txt.
local root = vim.fn.tempname()
vim.fn.mkdir(root, 'p')
root = vim.uv.fs_realpath(root) -- macOS: /var is a symlink to /private/var
vim.fn.mkdir(root .. '/sub', 'p')
vim.fn.writefile({ 'local x = 1', 'return x' }, root .. '/a.lua')
vim.fn.writefile({ 'bee' }, root .. '/b.txt')
vim.fn.writefile({ '# inner' }, root .. '/sub/inner.md')
vim.cmd('cd ' .. vim.fn.fnameescape(root))
vim.cmd('edit ' .. vim.fn.fnameescape(root .. '/b.txt'))
local code_win = vim.api.nvim_get_current_win()
local orig_buf = vim.api.nvim_get_current_buf()
vim.wait(15000, function()
  local ok, nnp = pcall(require, 'no-neck-pain.state')
  return ok and nnp.enabled
end)
local api = require('nvim-tree.api')
if api.tree.is_visible() then api.tree.close() end
vim.api.nvim_set_current_win(code_win)

local preview = require('config.tree_preview')
local function shown() return vim.api.nvim_win_get_buf(code_win) end
local function hover(name)
  -- Find the row whose node is `name`, move there, let the debounce fire.
  for row = 1, vim.api.nvim_buf_line_count(0) do
    vim.api.nvim_win_set_cursor(0, { row, 0 })
    local node = api.tree.get_node_under_cursor()
    if node and node.name == name then
      vim.cmd('doautocmd CursorMoved')
      vim.wait(preview.delay + 200, no)
      return true
    end
  end
  return false
end

require('config.tree').focus(true)
vim.wait(600, no)
check('cursor is in the tree', api.tree.is_tree_buf())
check('entering on the current file keeps it', shown() == orig_buf)

check('found a.lua', hover('a.lua'))
local a = shown()
check('file hover swaps the code window', a ~= orig_buf)
check('file preview is a scratch copy', vim.b[a].tree_preview == true and vim.bo[a].buftype == 'nofile')
check('file preview has the contents', vim.api.nvim_buf_get_lines(a, 0, -1, false)[1] == 'local x = 1')
check('no trailing blank line', vim.api.nvim_buf_line_count(a) == 2)
check('file preview is unlisted, not modifiable', not vim.bo[a].buflisted and not vim.bo[a].modifiable)
check('no filetype set (no LSP attach)', vim.bo[a].filetype == '')
check('cursor stayed in the tree', api.tree.is_tree_buf())

check('found sub', hover('sub'))
local d = shown()
check('previous scratch was wiped', not vim.api.nvim_buf_is_valid(a))
local dl = vim.api.nvim_buf_get_lines(d, 0, -1, false)
check('folder hover lists its entries', vim.b[d].tree_preview == true and vim.tbl_contains(dl, '  inner.md'))

check('found b.txt', hover('b.txt'))
check('hovering the original file shows the real buffer', shown() == orig_buf)
check('found a.lua again', hover('a.lua'))

vim.api.nvim_set_current_win(code_win) -- leave the tree without opening
check('leaving the tree restores the original buffer', shown() == orig_buf)

-- Opening for real still works after a hover.
require('config.tree').focus(false)
vim.wait(300, no)
hover('a.lua')
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('l', true, false, true), 'x', false)
vim.wait(600, no)
local opened = vim.api.nvim_get_current_buf()
check('l opens the real file', vim.api.nvim_buf_get_name(opened) == root .. '/a.lua' and vim.bo[opened].buftype == '')
check('opened file is listed', vim.bo[opened].buflisted)

-- l on an already-loaded file: the preview shows its real buffer, and
-- nvim-tree only focuses a window already showing it (no :edit), so the
-- open must keep it rather than restore the window's own buffer.
require('config.tree').focus(false)
vim.wait(300, no)
hover('b.txt')
check('loaded file previews as its real buffer', shown() == orig_buf)
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('l', true, false, true), 'x', false)
vim.wait(600, no)
check('l on a loaded file lands on it', vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()) == root .. '/b.txt')

if failures > 0 then
  print(failures .. ' check(s) failed')
  os.exit(1)
end
print('tree preview checks passed')
vim.cmd('qa!')
