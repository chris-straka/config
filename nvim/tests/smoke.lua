-- Smoke test for the Ghostty-tabs setup (no framework, plain asserts).
-- Run: nvim --headless --noplugin -l ~/.config/nvim/tests/smoke.lua
local home = vim.env.HOME
local nvim = home .. '/.config/nvim'
vim.opt.rtp:prepend(nvim)
-- Mirror init.lua: Space is the leader (keymaps.lua assumes it).
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

local function read(path)
  local f = assert(io.open(path, 'r'), 'missing file: ' .. path)
  local s = f:read('*a')
  f:close()
  return s
end

local failures = 0
local function check(name, ok)
  if ok then
    print('PASS: ' .. name)
  else
    failures = failures + 1
    print('FAIL: ' .. name)
  end
end

-- 1. Slots retired: init.lua must not load the deleted module.
local init = read(nvim .. '/init.lua')
check('init.lua does not require config.workspaces', not init:find('workspaces', 1, true))

-- 2. Options: tab bar back to default-visible, treesitter folding on.
require('config.options')
check('showtabline shows when >1 tab', vim.opt.showtabline:get() == 1)
check('foldmethod is treesitter expr', vim.opt.foldmethod:get() == 'expr')
check('folds start open', vim.opt.foldlevel:get() == 99)

-- 3. Terminal toggles are simple global ids; slot selects are gone.
require('config.keymaps')
check('Cmd+1 free for Ghostty tabs', vim.fn.maparg('<D-1>', 'n') == '')
check('Cmd+2 free for Ghostty tabs', vim.fn.maparg('<D-2>', 't') == '')
local a2 = vim.fn.maparg('<A-2>', 'n')
check('Alt+2 toggles global terminal 2', a2:find('2ToggleTerm', 1, true) ~= nil)
check('Cmd+Opt+[ folds', vim.fn.maparg('<D-M-[>', 'n') == 'zc')
check('Cmd+Opt+] unfolds', vim.fn.maparg('<D-M-]>', 'n') == 'zo')

-- 7. Code runner: module loads, <leader>of is bound.
local runner = require('config.runner')
check('runner module exposes run_file', type(runner.run_file) == 'function')
check('<leader>of runs current file', vim.fn.maparg(' of', 'n') ~= '')

-- 9. Option+K sender: reference builder + visual binding + bun TS runner.
check('ref lines 3-4', runner.at_reference('personal/README.md', 3, 4, 100) == '@personal/README.md#3-4')
check('ref whole file collapses', runner.at_reference('personal/README.md', 1, 100, 100) == '@personal/README.md')
check('ref single line', runner.at_reference('a.ts', 5, 5, 100) == '@a.ts#5')
check('ref no file is nil', runner.at_reference('', 1, 1, 10) == nil)
check('visual Option+K sends ref', vim.fn.maparg('<A-k>', 'v') ~= '')
check('visual Cmd+C copies', vim.fn.maparg('<D-c>', 'v') == '"+y')

-- 10. gd-style LSP only: the m-prefix duplicates are gone from whichkey.
local wk = read(nvim .. '/lua/config/whichkey.lua')
check('no m-prefix LSP group', wk:find("'m', group", 1, true) == nil)
check('no ma duplicate', wk:find("'ma'", 1, true) == nil)
check('leader-e peeks like Shift+Cmd+E', wk:find("require('config.tree').peek(true)", 1, true) ~= nil)

for _, p in ipairs({ home .. '/.config/ghostty/config', home .. '/.config/ghostty/nvim-launcher' }) do
  local tag = p:match('[^/]+$') .. '/copy'
  local c = read(p)
  check(tag .. ' Cmd+C reaches nvim', c:find('super+c=text', 1, true) ~= nil)
end

-- 11. Tree ergonomics: <leader>h peeks (no focus), indent guides are on.
check('<leader>h peeks tree', vim.fn.maparg(' h', 'n') ~= '')
local tree_src = read(nvim .. '/lua/config/tree.lua')
check('peek never focuses', tree_src:find('focus = false', 1, true) ~= nil)
check('focus helper exists', tree_src:find('function M.focus', 1, true) ~= nil
  and tree_src:find('focus = true', 1, true) ~= nil)
-- Cmd+E focuses, Shift+Cmd+E peeks (normal + terminal modes).
local keymaps_src = read(nvim .. '/lua/config/keymaps.lua')
check('Cmd+E focuses tree', keymaps_src:find("<D-e>', function() require('config.tree').focus(true)", 1, true) ~= nil)
check('Shift+Cmd+E peeks tree', keymaps_src:find("<D-S-e>', function() require('config.tree').peek(true)", 1, true) ~= nil)
check('Cmd+E focuses from float', keymaps_src:find("require(\"config.tree\").focus(true)", 1, true) ~= nil)
check('Shift+Cmd+E peeks from float', keymaps_src:find("require(\"config.tree\").peek(true)", 1, true) ~= nil)
-- Short tab title: project + short label, no full terminal buffer path.
local options_src = read(nvim .. '/lua/config/options.lua')
local title_line = options_src:match('[^\n]*titlestring[^\n]*') or ''
check('titlestring is short', options_src:find('titlestring', 1, true) ~= nil
  and options_src:find("fnamemodify(getcwd(), ':t')", 1, true) ~= nil
  and options_src:find("'term'", 1, true) ~= nil
  and title_line:find('://', 1, true) == nil)
local editor_src = read(nvim .. '/lua/plugins/editor.lua')
check('tree indent guides on', editor_src:find('indent_markers = { enable = true }', 1, true) ~= nil)
local runner_src = read(nvim .. '/lua/config/runner.lua')
check('bun runs typescript', runner_src:find("typescript = function(f) return { 'bun', f }", 1, true) ~= nil)

-- 8. Testing plugins: specs declare the adapters, keys are bound.
local test_src = read(nvim .. '/lua/plugins/test.lua')
for _, spec in ipairs({ 'nvim-neotest/neotest', 'neotest-python', 'neotest-rust', 'neotest-vitest', 'neotest-golang', 'michaelb/sniprun' }) do
  check('test spec declares ' .. spec, test_src:find(spec, 1, true) ~= nil)
end
-- NOTE: lazy `keys` specs only bind when lazy.nvim runs, which the
-- --noplugin smoke harness skips — so here we assert the declarations;
-- runtime binding is proven by the full boot check below.
for _, key in ipairs({ '<leader>Tr', '<leader>Tf', '<leader>Ta', '<leader>Td', '<leader>To', '<leader>Ts', '<leader>Tx', '<Plug>SnipRun' }) do
  check('test spec binds ' .. key, test_src:find(key, 1, true) ~= nil)
end

-- 4. Lualine shows the project name, not a slot.
local ui = read(nvim .. '/lua/plugins/ui.lua')
check('lualine shows cwd basename', ui:find("fnamemodify(vim.fn.getcwd(), ':t')", 1, true) ~= nil)
check('lualine shortens toggleterm to term', ui:find("s == 'toggleterm' and 'term'", 1, true) ~= nil)
check('tree bg brightened, theme kept', ui:find('catppuccin-mocha', 1, true) ~= nil
  and ui:find('NvimTreeNormal', 1, true) ~= nil
  and ui:find('surface0', 1, true) ~= nil)

-- 6. Fresh nvim opens the file tree (launcher flow: no file arguments).
local autocmds = read(nvim .. '/lua/config/autocmds.lua')
check('tree auto-opens on VimEnter with no args', autocmds:find('TreeOnStartup', 1, true) ~= nil
  and autocmds:find('NvimTreeToggle', 1, true) ~= nil
  and autocmds:find('argc() == 0', 1, true) ~= nil)

-- 5. Ghostty: visible tab bar + H/L nav, slot banks gone (both files).
for _, p in ipairs({ home .. '/.config/ghostty/config', home .. '/.config/ghostty/nvim-launcher' }) do
  local tag = p:match('[^/]+$')
  local c = read(p)
  check(tag .. ' titlebar keeps tabs visible', c:find('macos-titlebar-style = transparent', 1, true) ~= nil)
  check(tag .. ' tab bar appears with 2+ tabs', c:find('window-show-tab-bar = auto', 1, true) ~= nil)
  check(tag .. ' Shift+Cmd+H prev tab', c:find('super+shift+h=previous_tab', 1, true) ~= nil)
  check(tag .. ' Shift+Cmd+L next tab', c:find('super+shift+l=next_tab', 1, true) ~= nil)
  check(tag .. ' Cmd+Opt+[ fold transport', c:find('super+alt+[=text', 1, true) ~= nil)
  check(tag .. ' Cmd+Opt+] unfold transport', c:find('super+alt+]=text', 1, true) ~= nil)
  check(tag .. ' Cmd+digits left native (tabs)', not c:find('super+digit_1=text', 1, true))
  check(tag .. ' no digit unbinds', not c:find('super+1=unbind', 1, true))
  check(tag .. ' Cmd+E focuses tree', c:find('super+e=text', 1, true) ~= nil)
  check(tag .. ' Shift+Cmd+E peeks tree', c:find('super+shift+e=text', 1, true) ~= nil)
end

if failures > 0 then
  print(failures .. ' check(s) failed')
  os.exit(1)
end
print('all checks passed')
