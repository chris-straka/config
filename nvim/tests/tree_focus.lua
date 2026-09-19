-- Regression: Space+h (config.tree.focus) must leave the cursor in the
-- tree while no-neck-pain stays on: the centerer treats NvimTree as an
-- integration and centers around it instead of stealing focus.
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
-- Gate on the centerer itself, not the clock: a slow boot can land its
-- safe-VimEnter enable after the tree opens, which focuses `curr`
-- (the code window) and looks exactly like a focus steal.
vim.wait(15000, function()
  local ok, state = pcall(require, 'no-neck-pain.state')
  return ok and state.enabled
end)
require('config.tree').focus(false)
vim.wait(600, no) -- debounce horizons: the WinEnter scan + re-init land here
local api = require('nvim-tree.api')
check('tree stayed open', api.tree.is_visible())
check('cursor is in the tree', api.tree.is_tree_buf())
-- Deterministic re-init with the cursor in the tree: must not move focus.
require('no-neck-pain.main').init('tree-focus-test')
check('re-init keeps focus in the tree', api.tree.is_tree_buf())
-- Centerer still enabled (it never toggles for the tree; its padding
-- math beside the tree is upstream's business, not focus's).
local ok_state, nnp_state = pcall(require, 'no-neck-pain.state')
check('centerer stays enabled with the tree open', ok_state and nnp_state.enabled)
-- peek close path still toggles without error.
local pok, perr = pcall(require('config.tree').peek, false)
check('peek toggles without error', pok)
if not pok then print('peek error: ' .. tostring(perr)) end
check('peek closed the tree', not api.tree.is_visible())
if failures > 0 then
  print(failures .. ' check(s) failed')
  os.exit(1)
end
print('tree focus checks passed')
vim.cmd('qa!')
