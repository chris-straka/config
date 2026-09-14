-- Smoke test for the Ghostty-tabs setup (no framework, plain asserts).
-- Run: nvim --headless --noplugin -l ~/.config/nvim/tests/smoke.lua
local home = vim.env.HOME
local nvim = home .. '/.config/nvim'
vim.opt.rtp:prepend(nvim)

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
local d1 = vim.fn.maparg('<D-1>', 'n')
check('Cmd+1 toggles global terminal 1', d1:find('1ToggleTerm', 1, true) ~= nil)
local a2 = vim.fn.maparg('<A-2>', 'n')
check('Alt+2 toggles global terminal 2', a2:find('2ToggleTerm', 1, true) ~= nil)
check('Cmd+Opt+[ folds', vim.fn.maparg('<D-M-[>', 'n') == 'zc')
check('Cmd+Opt+] unfolds', vim.fn.maparg('<D-M-]>', 'n') == 'zo')

-- 4. Lualine shows the project name, not a slot.
local ui = read(nvim .. '/lua/plugins/ui.lua')
check('lualine shows cwd basename', ui:find("fnamemodify(vim.fn.getcwd(), ':t')", 1, true) ~= nil)
check('lualine shortens toggleterm to term', ui:find("s == 'toggleterm' and 'term'", 1, true) ~= nil)

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
  check(tag .. ' Cmd+digits still toggle terms', c:find('super+digit_1=text', 1, true) ~= nil)
end

if failures > 0 then
  print(failures .. ' check(s) failed')
  os.exit(1)
end
print('all checks passed')
