-- Regression: Space+h (config.tree.focus) must leave the cursor in the
-- tree even when no-neck-pain re-initializes itself after opening: an
-- init recreates the padding and reroutes focus to the code window while
-- the tree stays open.
-- Needs the real plugins, so NOT --noplugin. Run:
--   nvim --headless --cmd "set columns=250" --cmd "set lines=60" /tmp/tree_focus_target.txt -c "luafile ~/.config/nvim/tests/tree_focus.lua"
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
vim.wait(1500, no) -- startup settles, centerer enables
require('config.tree').focus(false)
vim.wait(600, no) -- past the old single repair pass
-- Deterministic stand-in for the centerer's async self re-init: with the
-- tree open and focused, enabling it yanks focus to the code buffer.
vim.cmd('NoNeckPain')
vim.wait(2000, no) -- repair horizon (~1.5s) + debounce margins
local api = require('nvim-tree.api')
check('tree stayed open', api.tree.is_visible())
check('cursor is in the tree', api.tree.is_tree_buf())
local sides = 0
for _, w in ipairs(vim.api.nvim_list_wins()) do
  local ok, ft = pcall(function() return vim.bo[vim.api.nvim_win_get_buf(w)].filetype end)
  if ok and ft == 'no-neck-pain' then sides = sides + 1 end
end
check('centerer held off while tree open', sides == 0)
if failures > 0 then
  print(failures .. ' check(s) failed')
  os.exit(1)
end
print('tree focus checks passed')
vim.cmd('qa!')
