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
check('scrolloff pads past EOF', vim.opt.scrolloff:get() == 999)
check('mouse captured in every mode', vim.o.mouse == 'a')

-- 3. Terminal toggles are simple global ids; slot selects are gone.
-- Terminals own Cmd+digits (most-used), tabs live on Alt+digits in
-- Ghostty; Alt+digits stay bound in nvim as fallback for terminals
-- that pass Alt through (kitty).
require('config.keymaps')
check('Cmd+2 toggles global terminal 2', vim.fn.maparg('<D-2>', 'n'):find('2ToggleTerm', 1, true) ~= nil)
check('Cmd+2 works from terminal mode', vim.fn.maparg('<D-2>', 't'):find('2ToggleTerm', 1, true) ~= nil)
check('Cmd+2 works while typing', vim.fn.maparg('<D-2>', 'i'):find('2ToggleTerm', 1, true) ~= nil)
check('Cmd+0 toggles global terminal 10', vim.fn.maparg('<D-0>', 'n'):find('10ToggleTerm', 1, true) ~= nil)
local a2 = vim.fn.maparg('<A-2>', 'n')
check('Alt+2 toggles global terminal 2', a2:find('2ToggleTerm', 1, true) ~= nil)
check('Alt+2 works from terminal mode', vim.fn.maparg('<A-2>', 't'):find('2ToggleTerm', 1, true) ~= nil)
check('Alt+2 works while typing', vim.fn.maparg('<A-2>', 'i'):find('2ToggleTerm', 1, true) ~= nil)
-- Alt+digit floats open ready to type: triple insert guarantee.
local editor_src = read(nvim .. '/lua/plugins/editor.lua')
check('terms open in Terminal-Insert', editor_src:find('start_in_insert = true', 1, true) ~= nil
  and editor_src:find('persist_mode = false', 1, true) ~= nil
  and editor_src:find('startinsert!', 1, true) ~= nil)
-- Alt+X exits the focused terminal (types `exit`) from normal, terminal,
-- and insert modes.
local terminal = require('config.terminal')
check('terminal module exposes exit_focused', type(terminal.exit_focused) == 'function')
check('Alt+X exits from normal', vim.fn.maparg('<A-x>', 'n') ~= '')
check('Alt+X exits from inside terminal', vim.fn.maparg('<A-x>', 't') ~= '')
check('Alt+X exits while typing', vim.fn.maparg('<A-x>', 'i') ~= '')
check('<leader>tR retired (Alt+X covers it)', vim.fn.maparg(' tR', 'n') == '')
-- Float width on the brackets; pipe is the Terminal-Normal hatch,
-- double-Esc is gone.
check('Alt+[ narrows float', vim.fn.maparg('<A-[>', 'n') ~= '' and vim.fn.maparg('<A-[>', 't') ~= '')
check('Alt+] widens float', vim.fn.maparg('<A-]>', 'n') ~= '' and vim.fn.maparg('<A-]>', 't') ~= '')
check('pipe drops terminal to Normal', vim.fn.maparg('|', 't') == '<C-\\><C-N>')
check('double-Esc ramp retired', vim.fn.maparg('<Esc><Esc>', 't') == '')
local term_src = read(nvim .. '/lua/config/terminal.lua')
check('exit sends exit+enter to the job', term_src:find("chansend(term.job_id, 'exit\\n')", 1, true) ~= nil)
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
check('trouble lives under x, misc Q gone', wk:find("'<leader>xx'", 1, true) ~= nil
  and wk:find("'<leader>xs'", 1, true) ~= nil
  and wk:find("'<leader>Q'", 1, true) == nil)

for _, p in ipairs({ home .. '/.config/ghostty/config', home .. '/.config/ghostty/nvim-launcher' }) do
  local tag = p:match('[^/]+$') .. '/copy'
  local c = read(p)
  check(tag .. ' Cmd+C reaches nvim', c:find('super+c=text', 1, true) ~= nil)
end

-- 11. Tree ergonomics: <leader>h focuses (cursor moves in).
check('<leader>h focuses tree', vim.fn.maparg(' h', 'n') ~= '')
local tree_src = read(nvim .. '/lua/config/tree.lua')
check('peek never focuses', tree_src:find('focus = false', 1, true) ~= nil)
check('focus helper exists', tree_src:find('function M.focus', 1, true) ~= nil
  and tree_src:find('focus = true', 1, true) ~= nil)
check('focus never toggles a visible tree shut', tree_src:find('is_visible()', 1, true) ~= nil
  and tree_src:find('api.tree.focus()', 1, true) ~= nil
  and tree_src:find('api.tree.find_file()', 1, true) ~= nil)
-- Cmd+E focuses, Shift+Cmd+E peeks (normal + terminal modes).
local keymaps_src = read(nvim .. '/lua/config/keymaps.lua')
check('Cmd+E focuses tree', keymaps_src:find("<D-e>', function() require('config.tree').focus(true)", 1, true) ~= nil)
check('Shift+Cmd+E peeks tree', keymaps_src:find("<D-S-e>', function() require('config.tree').peek(true)", 1, true) ~= nil)
check('Cmd+E focuses from float', keymaps_src:find("require(\"config.tree\").focus(true)", 1, true) ~= nil)
check('Shift+Cmd+E peeks from float', keymaps_src:find("require(\"config.tree\").peek(true)", 1, true) ~= nil)
check('middle-click opens tree', vim.fn.maparg('<MiddleMouse>', 'n') ~= ''
  and vim.fn.maparg('<MiddleMouse>', 't') ~= '')
-- Alt+E rides the same focus() path as Cmd+E now, and the pre-0.12
-- <Esc>[9xx;1~ maps are retired (both terminals speak CSI-u).
check('Alt+E focuses like Cmd+E', keymaps_src:find("<A-e>', function() require('config.tree').focus(true)", 1, true) ~= nil
  and keymaps_src:find('NvimTreeFindFileToggle', 1, true) == nil)
check('no pre-0.12 fallback maps', keymaps_src:find("'<Esc>['", 1, true) == nil)
check('<leader>h jumps in unrevealed', keymaps_src:find("h', function() require('config.tree').focus(false)", 1, true) ~= nil)
-- Short tab title: project + short label, no full terminal buffer path.
local options_src = read(nvim .. '/lua/config/options.lua')
local title_line = options_src:match('[^\n]*titlestring[^\n]*') or ''
check('titlestring is short', options_src:find('titlestring', 1, true) ~= nil
  and options_src:find("fnamemodify(getcwd(), ':t')", 1, true) ~= nil
  and options_src:find("'term'", 1, true) ~= nil
  and title_line:find('://', 1, true) == nil)
local editor_src = read(nvim .. '/lua/plugins/editor.lua')
check('tree indent guides on', editor_src:find('indent_markers = { enable = true }', 1, true) ~= nil)
check('svelte parser installed', editor_src:find("'svelte'", 1, true) ~= nil)
check('mini.icons set up and mocking devicons', editor_src:find("require('mini.icons').setup()", 1, true) ~= nil
  and editor_src:find('mock_nvim_web_devicons', 1, true) ~= nil)
-- NOTE: lazy `keys` bind at runtime (see test.lua note above); here we
-- assert the declarations, shadowing the conflict check from 2026-09-14.
check('harpoon keys declared', editor_src:find("'<leader>a'", 1, true) ~= nil
  and editor_src:find("'<C-e>'", 1, true) ~= nil
  and editor_src:find("'<leader>1'", 1, true) ~= nil
  and editor_src:find("'<leader>4'", 1, true) ~= nil)
local float = require('config.float')
check('float module exposes resize', type(float.resize) == 'function')
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

-- 6. Fresh nvim opens the file tree UNFOCUSED (launcher flow: no args).
local autocmds = read(nvim .. '/lua/config/autocmds.lua')
check('tree auto-opens on VimEnter with no args', autocmds:find('TreeOnStartup', 1, true) ~= nil
  and autocmds:find("require('config.tree').peek(false)", 1, true) ~= nil
  and autocmds:find('argc() == 0', 1, true) ~= nil)

-- 5. Ghostty: no top tab bar (lualine names the project) + H/L nav (both files).
for _, p in ipairs({ home .. '/.config/ghostty/config', home .. '/.config/ghostty/nvim-launcher' }) do
  local tag = p:match('[^/]+$')
  local c = read(p)
  check(tag .. ' titlebar keeps tabs visible', c:find('macos-titlebar-style = transparent', 1, true) ~= nil)
  check(tag .. ' top tab bar stays hidden', c:find('window-show-tab-bar = never', 1, true) ~= nil)
  check(tag .. ' opens already zoomed in', c:find('font-size = 20', 1, true) ~= nil)
  check(tag .. ' Shift+Cmd+H prev tab', c:find('super+shift+h=previous_tab', 1, true) ~= nil)
  check(tag .. ' Shift+Cmd+L next tab', c:find('super+shift+l=next_tab', 1, true) ~= nil)
  check(tag .. ' Cmd+Opt+[ fold transport', c:find('super+alt+[=text', 1, true) ~= nil)
  check(tag .. ' Cmd+Opt+] unfold transport', c:find('super+alt+]=text', 1, true) ~= nil)
  check(tag .. ' Cmd+digits reach nvim', c:find('super+digit_1=text', 1, true) ~= nil)
  check(tag .. ' bare Cmd+digits unbound (one send)', c:find('super+1=unbind', 1, true) ~= nil)
  check(tag .. ' Alt+digits jump tabs', c:find('alt+1=goto_tab:1', 1, true) ~= nil)
  check(tag .. ' Cmd+E focuses tree', c:find('super+e=text', 1, true) ~= nil)
  check(tag .. ' Shift+Cmd+E peeks tree', c:find('super+shift+e=text', 1, true) ~= nil)
end
-- The launcher block is generated from shared-keybinds.conf: both files
-- must carry the identical keybind set, or a tab silently loses keys.
local function keybinds(path)
  local out = {}
  for line in (read(path) .. '\n'):gmatch('([^\n]*)\n') do
    if line:find('^keybind', 1) == 1 then out[#out + 1] = line end
  end
  return table.concat(out, '\n')
end
check('launcher mirrors main keybinds',
  keybinds(home .. '/.config/ghostty/config') == keybinds(home .. '/.config/ghostty/nvim-launcher'))
-- Kitty lives in the repo too and install.sh links it; its Cmd+E takes
-- the same CSI-u live path (no legacy sequences anywhere).
local root = vim.fn.fnamemodify(vim.fn.resolve(nvim), ':h')
check('install.sh manages kitty conf', read(root .. '/install.sh'):find('kitty/kitty.conf', 1, true) ~= nil)
local kitty = read(home .. '/.config/kitty/kitty.conf')
check('kitty Cmd+E reaches nvim', kitty:find('cmd+e send_text all \\e[101;9u', 1, true) ~= nil)
check('kitty Shift+Cmd+E peeks', kitty:find('cmd+shift+e send_text all \\e[101;10u', 1, true) ~= nil)

-- 12. Cmd+O "land here": file_browser mappings cd the tab to the browsed
-- or highlighted folder, close the picker, and move the tree too.
local land = require('config.telescope_land')
check('land_here helper exists', type(land.land_here) == 'function')
check('land_here on Cmd+O in insert', type(land.mappings.i['<D-o>']) == 'function')
check('land_here on Cmd+O in normal', type(land.mappings.n['<D-o>']) == 'function')
check('land_here fallback on Ctrl+Y', type(land.mappings.i['<C-y>']) == 'function'
  and type(land.mappings.n['<C-y>']) == 'function')
check('telescope wires file_browser mappings',
  read(nvim .. '/lua/plugins/editor.lua'):find("require('config.telescope_land').mappings", 1, true) ~= nil)
do
  local root = vim.fn.tempname()
  vim.fn.mkdir(root .. '/SWE', 'p')
  vim.fn.writefile({}, root .. '/SWE/file.txt')
  local closed, tree_root, selected, finder_path = nil, nil, nil, nil
  package.preload['telescope.actions'] = function()
    return { close = function(bufnr) closed = bufnr end }
  end
  package.preload['nvim-tree.api'] = function()
    return { tree = { change_root = function(dir) tree_root = dir end } }
  end
  package.preload['telescope.actions.state'] = function()
    return {
      get_current_picker = function() return { finder = { path = finder_path } } end,
      get_selected_entry = function() return selected end,
    }
  end
  local back = vim.fn.getcwd()
  -- tempname() sits under /var (a symlink to /private/var), while getcwd()
  -- returns the resolved path, so compare against the resolved target.
  local swe = vim.fn.resolve(root .. '/SWE')
  -- Browsed into /SWE with a file highlighted: stay in /SWE.
  finder_path = root .. '/SWE'
  selected = { path = root .. '/SWE/file.txt' }
  land.land_here(7)
  check('land_here closes picker', closed == 7)
  check('land_here stays in browsed dir', vim.fn.getcwd() == swe)
  check('land_here moves tree too', tree_root == root .. '/SWE')
  -- Folder highlighted from its parent: jump into it.
  finder_path = root
  selected = { path = root .. '/SWE' }
  land.land_here(7)
  check('land_here jumps to highlighted dir', vim.fn.getcwd() == swe)
  -- Nothing highlighted: fall back to the browsed folder.
  finder_path = root .. '/SWE'
  selected = nil
  land.land_here(7)
  check('land_here falls back to browsed dir', vim.fn.getcwd() == swe)
  vim.cmd('tcd ' .. vim.fn.fnameescape(back))
  package.preload['telescope.actions'] = nil
  package.preload['nvim-tree.api'] = nil
  package.preload['telescope.actions.state'] = nil
  vim.fn.delete(root, 'rf')
end

-- 13. Mouse hover docs: mousemoveevent on, <MouseMove> mapped, and the
-- hover module gates, positions (utf-16), and renders without a server.
check('mousemoveevent delivers MouseMove', vim.o.mousemoveevent == true)
check('<MouseMove> shows hover docs', vim.fn.maparg('<MouseMove>', 'n') ~= '')
local hover = require('config.mouse_hover')
check('mouse hover module loads', type(hover.on_mouse_move) == 'function')
do
  local saved_pos, saved_delay, saved_req = hover._mousepos, hover.delay, hover.request
  local saved_clients = vim.lsp.get_clients
  local saved_float = vim.lsp.util.open_floating_preview
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'hello world', '   ', 'héllo' })
  vim.api.nvim_win_set_buf(0, buf)
  local win = vim.api.nvim_get_current_win()
  hover.delay = 5
  -- Nowhere useful: dismissed.
  hover._mousepos = function() return { winid = 0, line = 0, column = 0 } end
  check('mouse hover off-window dismisses', hover.on_mouse_move() == 'no-window')
  -- Blank space: dismissed, no request.
  hover._mousepos = function() return { winid = win, line = 2, column = 2 } end
  check('mouse hover on blank dismisses', hover.on_mouse_move() == 'no-symbol')
  -- Word but no language server: nothing to ask.
  hover._mousepos = function() return { winid = win, line = 1, column = 3 } end
  check('mouse hover without server idles', hover.on_mouse_move() == 'no-client')
  -- Word with a (fake) server: scheduled once, then deduped...
  vim.lsp.get_clients = function() return { { id = 7, name = 'fake', offset_encoding = 'utf-16' } } end
  local got = nil
  hover.request = function(b, params, key) got = { bufnr = b, params = params, key = key } end
  check('mouse hover on word schedules', hover.on_mouse_move() == 'scheduled')
  check('mouse hover dedupes same word', hover.on_mouse_move() == 'same-word')
  check('mouse hover asks at utf-16 position', vim.wait(500, function() return got ~= nil end)
    and got.params.position.line == 0 and got.params.position.character == 2)
  -- ...and renders the canned answer in a mouse-anchored float.
  local shown = nil
  vim.lsp.util.open_floating_preview = function(contents, syntax, opts)
    shown = { contents = contents, syntax = syntax, opts = opts }
    return 111, 222
  end
  local canned = { [7] = { result = { contents = { kind = 'markdown', value = 'hi' } } } }
  check('mouse hover renders docs', hover._on_results(canned, got.key, buf) == 'shown'
    and shown.opts.relative == 'mouse' and shown.contents[1] == 'hi')
  check('mouse hover rejects stale answers', hover._on_results({}, 'nope:\0never', buf) == 'stale')
  -- Non-ASCII: byte column 4 on 'héllo' is utf-16 character 2.
  got = nil
  hover._mousepos = function() return { winid = win, line = 3, column = 4 } end
  hover.on_mouse_move()
  check('mouse hover converts utf-16 position', vim.wait(500, function() return got ~= nil end)
    and got.params.position.character == 2)
  hover.close()
  hover._mousepos, hover.delay, hover.request = saved_pos, saved_delay, saved_req
  vim.lsp.get_clients = saved_clients
  vim.lsp.util.open_floating_preview = saved_float
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- 14. Reference highlight + inlay hints: attach wires highlight autocmds
-- and default-on hints; <leader>uh toggles per buffer.
local lsp_src = read(nvim .. '/lua/plugins/lsp.lua')
check('attach highlights references on hold',
  lsp_src:find('textDocument/documentHighlight', 1, true) ~= nil
  and lsp_src:find('vim.lsp.buf.document_highlight()', 1, true) ~= nil
  and lsp_src:find('vim.lsp.buf.clear_references()', 1, true) ~= nil)
check('attach enables inlay hints by default',
  lsp_src:find('textDocument/inlayHint', 1, true) ~= nil
  and lsp_src:find('vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })', 1, true) ~= nil)
check('<leader>uh toggles inlay hints', vim.fn.maparg(' uh', 'n') ~= '')
check('which-key lists inlay toggle',
  read(nvim .. '/lua/config/whichkey.lua'):find("<leader>uh', desc", 1, true) ~= nil)
do
  local ib = vim.api.nvim_create_buf(true, false)
  vim.lsp.inlay_hint.enable(true, { bufnr = ib })
  check('inlay hints enable per buffer', vim.lsp.inlay_hint.is_enabled({ bufnr = ib }) == true)
  vim.lsp.inlay_hint.enable(false, { bufnr = ib })
  check('inlay hints disable per buffer', vim.lsp.inlay_hint.is_enabled({ bufnr = ib }) == false)
  vim.api.nvim_buf_delete(ib, { force = true })
end

-- 15. Terminal cycling: Cmd+[/] transport in both Ghostty files, nvim
-- maps in every mode, and pure pick logic with wraparound.
for _, p in ipairs({ home .. '/.config/ghostty/config', home .. '/.config/ghostty/nvim-launcher' }) do
  local tag, c = p:match('[^/]+$'), read(p)
  check(tag .. ' Cmd+[ cycles back', c:find('super+[=text', 1, true) ~= nil)
  check(tag .. ' Cmd+] cycles forward', c:find('super+]=text', 1, true) ~= nil)
end
for _, mode in ipairs({ 'n', 'i', 't' }) do
  check('Cmd+[ cycles from ' .. mode, vim.fn.maparg('<D-[>', mode) ~= '')
  check('Cmd+] cycles from ' .. mode, vim.fn.maparg('<D-]>', mode) ~= '')
end
check('cycle with no plugin is safe', terminal.cycle(1) == 'no-plugin')
check('cycle order empty without plugin', #terminal._order() == 0)
check('cycle next wraps', terminal._pick({ 1, 2, 5 }, 5, 1) == 1)
check('cycle prev wraps', terminal._pick({ 1, 2, 5 }, 1, -1) == 5)
check('cycle next steps', terminal._pick({ 1, 2, 5 }, 2, 1) == 5)
check('cycle prev steps', terminal._pick({ 1, 2, 5 }, 2, -1) == 1)
check('cycle unfocused goes first/last', terminal._pick({ 1, 2, 5 }, nil, 1) == 1
  and terminal._pick({ 1, 2, 5 }, nil, -1) == 5)
check('cycle stale id restarts', terminal._pick({ 1, 2 }, 9, 1) == 1)
check('cycle single stays', terminal._pick({ 3 }, 3, -1) == 3)
check('cycle empty is nil', terminal._pick({}, nil, 1) == nil)

-- 16. Cmd+W closes the buffer (never the tab); Cmd+Shift+W closes window.
-- Telescope Enter roots the tree at the opened file's dir; <leader>cr
-- prompts for a new tree root (.. goes up).
check('Cmd+W closes buffer via Bdelete', keymaps_src:find("<D-w>", 1, true) ~= nil
  and keymaps_src:find('Bdelete', 1, true) ~= nil)
check('Cmd+W works from inside float', vim.fn.maparg('<D-w>', 't') ~= '')
for _, p in ipairs({ home .. '/.config/ghostty/config', home .. '/.config/ghostty/nvim-launcher' }) do
  local tag, c = p:match('[^/]+$'), read(p)
  check(tag .. ' Cmd+W reaches nvim', c:find('super+w=text', 1, true) ~= nil)
  check(tag .. ' Shift+Cmd+W closes window', c:find('super+shift+w=close_window', 1, true) ~= nil)
end
local land2 = require('config.telescope_land')
check('select_and_land helper exists', type(land2.select_and_land) == 'function')
check('select_and_land on Enter in insert', type(land2.mappings.i['<CR>']) == 'function')
check('select_and_land on Enter in normal', type(land2.mappings.n['<CR>']) == 'function')
check('land_here still on Cmd+O', type(land2.mappings.i['<D-o>']) == 'function')
local tree = require('config.tree')
check('tree exposes change_root_prompt', type(tree.change_root_prompt) == 'function')
check('<leader>cr prompts tree root', vim.fn.maparg(' cr', 'n') ~= '')
do
  -- Enter on a file: opens it, tab-cds to its dir, moves the tree too.
  local root = vim.fn.tempname()
  vim.fn.mkdir(root .. '/SUB', 'p')
  vim.fn.writefile({ 'hi' }, root .. '/SUB/file.txt')
  local opened, tree_root, selected = nil, nil, nil
  -- Section 12 cached its own mocks in package.loaded: drop them so the
  -- preloads below take effect.
  package.loaded['telescope.actions'] = nil
  package.loaded['telescope.actions.state'] = nil
  package.loaded['nvim-tree.api'] = nil
  package.preload['telescope.actions'] = function()
    return { select_default = function(bufnr) opened = bufnr end }
  end
  package.preload['nvim-tree.api'] = function()
    return { tree = { change_root = function(dir) tree_root = dir end } }
  end
  package.preload['telescope.actions.state'] = function()
    return {
      get_current_picker = function() return {} end,
      get_selected_entry = function() return selected end,
    }
  end
  local back = vim.fn.getcwd()
  local sub = vim.fn.resolve(root .. '/SUB')
  selected = { value = root .. '/SUB/file.txt', path = root .. '/SUB/file.txt' }
  land2.select_and_land(9)
  check('select_and_land opens the file', opened == 9)
  check('select_and_land cds to file dir', vim.fn.getcwd() == sub)
  check('select_and_land moves tree too', tree_root == root .. '/SUB')
  -- Enter on a directory: default open only, no re-root.
  opened, tree_root = nil, nil
  vim.cmd('tcd ' .. vim.fn.fnameescape(back))
  selected = { value = root .. '/SUB', path = root .. '/SUB' }
  land2.select_and_land(9)
  check('select_and_land opens dirs normally', opened == 9)
  check('select_and_land leaves cwd on dirs', vim.fn.getcwd() == back and tree_root == nil)
  vim.cmd('tcd ' .. vim.fn.fnameescape(back))
  package.preload['telescope.actions'] = nil
  package.preload['nvim-tree.api'] = nil
  package.preload['telescope.actions.state'] = nil
  vim.fn.delete(root, 'rf')
end

if failures > 0 then
  print(failures .. ' check(s) failed')
  os.exit(1)
end
print('all checks passed')
