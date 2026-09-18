-- Smoke test for the Ghostty-tabs setup (no framework, plain asserts).
-- Run: nvim --headless --noplugin -l ~/.config/nvim/tests/smoke.lua
local home = vim.env.HOME
local nvim = home .. '/.config/nvim'
vim.opt.rtp:prepend(nvim)
-- Mirror init.lua: Space is the leader (config/keymaps/ assumes it).
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

local function read(path)
  local f = assert(io.open(path, 'r'), 'missing file: ' .. path)
  local s = f:read('*a')
  f:close()
  return s
end

-- Keymaps live split across lua/config/keymaps/*.lua (see that dir's
-- init.lua): read all four as one combined source for the text checks.
local function read_keymaps()
  local parts = {}
  for _, f in ipairs({ 'init.lua', 'general.lua', 'workspace.lua', 'terminal.lua' }) do
    parts[#parts + 1] = read(nvim .. '/lua/config/keymaps/' .. f)
  end
  return table.concat(parts, '\n')
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
check('foldtext is the compact label', vim.opt.foldtext:get():find("require('config.fold').foldtext", 1, true) ~= nil)
do
  local fold = require('config.fold')
  check('fold module exposes foldtext', type(fold.foldtext) == 'function')
  check('fold label keeps facts, drops fill',
    fold.text(22, 27, 'function blankSettings() {', 80) == '+ 6 lines · function blankSettings() {')
  check('fold label has no dot run', fold.text(1, 6, 'local x = 1', 80):find('...', 1, true) == nil)
  check('fold label trims indent', fold.text(1, 3, '    const s = 1;', 80) == '+ 3 lines · const s = 1;')
  check('fold label names the singular', fold.text(5, 5, 'x', 80) == '+ 1 line · x')
  check('fold label covers blank first lines', fold.text(1, 2, '   ', 80) == '+ 2 lines · (blank)')
  local long = fold.text(1, 4, 'const ' .. string.rep('ab', 60) .. ' = 1;', 40)
  check('fold label truncates to the window', vim.fn.strwidth(long) <= 40 and long:sub(-3) == '…')
end
-- scrolloff=999 centers the cursor mid-file; at end-of-file Neovim still
-- docks the last line at the window bottom (nothing pads past EOF —
-- verified: winline == winheight on `G`). The old name claimed padding.
check('scrolloff centers the cursor', vim.opt.scrolloff:get() == 999)
check('closed folds pad with blank, not dots', vim.opt.fillchars:get().fold == ' ')
do
  local ac_src = read(nvim .. '/lua/config/autocmds.lua')
  check('EOF tail recenters the cursor',
    ac_src:find('CenterCursorTail', 1, true) ~= nil
    and ac_src:find('normal! zz', 1, true) ~= nil
    and ac_src:find('setlocal scrolloff<', 1, true) ~= nil
    and ac_src:find('InsertLeave', 1, true) ~= nil)
end
check('mouse captured in every mode', vim.o.mouse == 'a')

-- Terminal scrollback keeps its view: TermOpen scopes scrolloff to 0 (a
-- scrolled-up view survives cursor nudges on return) while files keep the
-- centered 999.
do
  local ac_src = read(nvim .. '/lua/config/autocmds.lua')
  check('terminals scope scrolloff to zero',
    ac_src:find('TerminalScrolloff', 1, true) ~= nil
    and ac_src:find('TermOpen', 1, true) ~= nil
    and ac_src:find('scrolloff = 0', 1, true) ~= nil)
  require('config.autocmds')
  vim.cmd('enew')
  local job = vim.fn.termopen({ 'echo', 'scrollback probe' })
  check('terminal window drops scrolloff', job > 0
    and vim.api.nvim_get_option_value('scrolloff', { win = 0 }) == 0)
  check('global scrolloff still centers files',
    vim.api.nvim_get_option_value('scrolloff', { scope = 'global' }) == 999)
  vim.api.nvim_buf_delete(vim.api.nvim_get_current_buf(), { force = true })
end

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
-- Shift+Backspace toggles Insert <-> Normal (Ghostty sends it as <S-BS>).
check('Shift+BS bound in terminal mode', vim.fn.maparg('<S-BS>', 't') ~= '')
do
  local km_src = read_keymaps()
  check('Shift+BS toggles both ways',
    km_src:find("'<S-BS>'", 1, true) ~= nil
    and km_src:find('stopinsert', 1, true) ~= nil
    and km_src:find('startinsert', 1, true) ~= nil)
end
local term_src = read(nvim .. '/lua/config/terminal.lua')
check('exit sends exit+enter to the job', term_src:find("chansend(term.job_id, 'exit\\n')", 1, true) ~= nil)
check('Cmd+Opt+[ folds', vim.fn.maparg('<D-M-[>', 'n') == 'zc')
check('Cmd+Opt+] unfolds', vim.fn.maparg('<D-M-]>', 'n') == 'zo')

-- 8. Manual format: Shift+Alt+F formats the buffer, or just the visual
-- selection (conform reads the range itself). Cmd+Shift+F stays search.
check('Shift+Alt+F formats from normal', vim.fn.maparg('<A-S-f>', 'n') ~= '')
check('Shift+Alt+F formats a visual selection', vim.fn.maparg('<A-S-f>', 'v') ~= '')
check('Cmd+Shift+F still searches files', vim.fn.maparg('<D-S-f>', 'n'):find('live_grep', 1, true) ~= nil)
do
  local keymaps_src = read_keymaps()
  check('format uses the conform table with LSP fallback',
    keymaps_src:find("require('conform').format", 1, true) ~= nil
    and keymaps_src:find('lsp_fallback', 1, true) ~= nil)
end
for _, p in ipairs({ home .. '/.config/ghostty/config', home .. '/.config/ghostty/nvim-launcher' }) do
  local tag, c = p:match('[^/]+$'), read(p)
  check(tag .. ' Shift+Alt+F formats', c:find('alt+shift+f=text', 1, true) ~= nil)
  check(tag .. ' Cmd+Shift+F still searches', c:find('super+shift+f=text', 1, true) ~= nil)
end
check('kitty Shift+Alt+F formats',
  read(home .. '/.config/kitty/kitty.conf'):find('alt+shift+f send_text', 1, true) ~= nil)

-- Autosave: settled edits hit disk without :w, unnamed buffers are left
-- alone, and no swap files exist to warn about.
check('no swap files, ever', vim.opt.swapfile:get() == false)
do
  local ac_src = read(nvim .. '/lua/config/autocmds.lua')
  check('autosave covers settle/leave/focus',
    ac_src:find('InsertLeave', 1, true) ~= nil and ac_src:find('TextChanged', 1, true) ~= nil
      and ac_src:find('BufLeave', 1, true) ~= nil and ac_src:find('FocusLost', 1, true) ~= nil)
  check('autosave only touches plain modified files',
    ac_src:find('modifiable', 1, true) ~= nil and ac_src:find('readonly', 1, true) ~= nil
      and ac_src:find("buftype ~= ''", 1, true) ~= nil and ac_src:find('silent! update', 1, true) ~= nil)
end
do
  -- ConformFormat would try to load the real plugin headless: require
  -- the autocmds (harmless headless), then drop it so this stays about
  -- the autosave write itself (live, saving runs the same format-on-save
  -- as a manual :w).
  require('config.autocmds')
  vim.api.nvim_clear_autocmds({ group = 'ConformFormat' })
  local f = vim.fn.tempname()
  vim.cmd('edit ' .. vim.fn.fnameescape(f))
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'autosaved' })
  vim.cmd('doautocmd InsertLeave')
  check('autosave writes settled edits',
    vim.fn.readfile(f)[1] == 'autosaved' and not vim.bo[buf].modified)
  vim.api.nvim_buf_delete(buf, { force = true })
  local scratch = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(scratch)
  vim.api.nvim_buf_set_lines(scratch, 0, -1, false, { 'no name, no write' })
  local ok = pcall(vim.cmd, 'doautocmd InsertLeave')
  check('autosave skips unnamed buffers', ok and vim.bo[scratch].modified)
  vim.api.nvim_buf_delete(scratch, { force = true })
  vim.fn.delete(f)
end

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
-- Option+K reads the LIVE selection: '< / '> still hold the previous
-- selection while visual is active (the one-step-behind bug), so the
-- sender reads the anchor/cursor instead, falling back to marks after.
do
  local runner_src = read(nvim .. '/lua/config/runner.lua')
  check('sender uses the live visual range',
    runner_src:find('M.ref_for_visual', 1, true) ~= nil
    and runner_src:find("getpos('v')", 1, true) ~= nil)
  local esc = vim.api.nvim_replace_termcodes('<Esc>', true, false, true)
  local function keys(s) vim.api.nvim_feedkeys(s, 'x!', false) end
  vim.cmd('enew')
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b', 'c', 'd', 'e', 'f' })
  keys('ggVj')
  local s1, e1 = runner.visual_range()
  check('active selection reads live, not previous marks', s1 == 1 and e1 == 2)
  keys(esc)
  keys('4GV2j')
  local s2, e2 = runner.visual_range()
  check('second selection is not one step behind', s2 == 4 and e2 == 6)
  keys(esc)
  local s3, e3 = runner.visual_range()
  check('exited selection still reads from marks', s3 == 4 and e3 == 6)
  vim.api.nvim_buf_delete(0, { force = true })
end
check('visual Cmd+C copies', vim.fn.maparg('<D-c>', 'v') == '"+y')
do
  -- Bare visual `y` must yank without a timeoutlen stall: no visual mapping
  -- may start with `y` (surround-add lives on `S` instead). Runs the real
  -- surround module headless, then inspects the live mappings.
  vim.opt.rtp:append(vim.fn.stdpath('data') .. '/lazy/mini.nvim')
  local ok, surround = pcall(require, 'config.surround')
  check('surround module loads', ok and type(surround.setup) == 'function')
  local ok_cfg = ok and pcall(surround.setup) or false
  check('surround setup runs headless', ok_cfg)
  if ok_cfg then
    check('visual ys freed for instant yank', vim.fn.maparg('ys', 'x') == '')
    check('visual S surrounds selection', vim.fn.maparg('S', 'x') ~= '')
    check('normal ys still surrounds', vim.fn.maparg('ys', 'n') ~= '')
  end
end

-- 10. gd-style LSP only: the m-prefix duplicates are gone from whichkey.
local wk = read(nvim .. '/lua/config/whichkey.lua')
check('no m-prefix LSP group', wk:find("'m', group", 1, true) == nil)
check('no ma duplicate', wk:find("'ma'", 1, true) == nil)
check('leader-e peeks like Shift+Cmd+E', wk:find("require('config.tree').peek(true)", 1, true) ~= nil)
check('trouble lives under x, misc Q gone', wk:find("'<leader>xx'", 1, true) ~= nil
  and wk:find("'<leader>xs'", 1, true) ~= nil
  and wk:find("'<leader>Q'", 1, true) == nil)
do
  -- Bare `v` must not flash the visual help instantly: which-key waits
  -- in visual/select but stays snappy in normal/operator-pending.
  local ok, specs = pcall(require, 'plugins.editor')
  check('editor specs load headless', ok and type(specs) == 'table')
  local wk_spec = nil
  if ok then
    for _, s in ipairs(specs) do
      if type(s) == 'table' and s[1] == 'folke/which-key.nvim' then
        wk_spec = s
        break
      end
    end
  end
  check('which-key spec found', wk_spec ~= nil)
  local delay = wk_spec and wk_spec.opts and wk_spec.opts.delay
  check('which-key delay is a function', type(delay) == 'function')
  if type(delay) == 'function' then
    check('normal stays snappy', delay { mode = 'n', keys = '' } == 200)
    check(
      'operator-pending stays snappy',
      delay { mode = 'o', keys = '' } == 200
    )
    check('charwise visual waits', delay { mode = 'v', keys = '' } == 1000)
    check('visual waits', delay { mode = 'x', keys = '' } == 1000)
    check('select waits', delay { mode = 's', keys = '' } == 1000)
  end
end

for _, p in ipairs({ home .. '/.config/ghostty/config', home .. '/.config/ghostty/nvim-launcher' }) do
  local tag = p:match('[^/]+$') .. '/copy'
  local c = read(p)
  check(tag .. ' Cmd+C reaches nvim', c:find('super+c=text', 1, true) ~= nil)
end

-- 11. Tree ergonomics: <leader>h focuses (cursor moves in).
check('<leader>h focuses tree', vim.fn.maparg(' h', 'n') ~= '')
-- <leader>j focuses the tree, but only from an empty buffer (the Cmd+W
-- definition in buffer_close.lua, covered further below).
check('<leader>j is bound', vim.fn.maparg(' j', 'n') ~= '')
do
  -- keymaps_src for the later sections is defined further below; read our
  -- own copy here so this block stays position-independent.
  local keymaps_src = read_keymaps()
  check('<leader>j jumps in from empty buffers only', keymaps_src:find(
    "if require('config.buffer_close').is_empty_buffer() then require('config.tree').focus(false) end",
    1, true) ~= nil)
end
local tree_src = read(nvim .. '/lua/config/tree.lua')
check('peek never focuses', tree_src:find('focus = false', 1, true) ~= nil)
check('focus helper exists', tree_src:find('function M.focus', 1, true) ~= nil
  and tree_src:find('focus = true', 1, true) ~= nil)
check('focus never toggles a visible tree shut', tree_src:find('is_visible()', 1, true) ~= nil
  and tree_src:find('api.tree.focus()', 1, true) ~= nil
  and tree_src:find('api.tree.find_file({ focus = true })', 1, true) ~= nil)
-- Cmd+E focuses, Shift+Cmd+E peeks (normal + terminal modes).
local keymaps_src = read_keymaps()
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
-- Focusing the tree holds no-neck-pain off for the tab (it otherwise
-- closes the tree and kicks focus back) and restores it on tree close.
check('tree focus holds centering off', tree_src:find('hold_nnp_off', 1, true) ~= nil
  and tree_src:find('nnp_guard', 1, true) ~= nil)
-- Short tab title: project + short label, no full terminal buffer path.
local options_src = read(nvim .. '/lua/config/options.lua')
local title_line = options_src:match('[^\n]*titlestring[^\n]*') or ''
check('titlestring is short', options_src:find('titlestring', 1, true) ~= nil
  and options_src:find("fnamemodify(getcwd(), ':t')", 1, true) ~= nil
  and options_src:find("require('config.terminal').title_label", 1, true) ~= nil
  and title_line:find('://', 1, true) == nil)
local editor_src = read(nvim .. '/lua/plugins/editor.lua')
check('tree indent guides on', editor_src:find('indent_markers = { enable = true }', 1, true) ~= nil)
check('svelte parser installed', editor_src:find("'svelte'", 1, true) ~= nil)
check('mini.icons set up and mocking devicons', editor_src:find("require('mini.icons').setup()", 1, true) ~= nil
  and editor_src:find('mock_nvim_web_devicons', 1, true) ~= nil)
check('mini.pairs replaces autopairs', editor_src:find("require('mini.pairs').setup()", 1, true) ~= nil
  and editor_src:find('nvim-autopairs', 1, true) == nil)
check('mini.bufremove replaces bufdelete', editor_src:find("require('mini.bufremove').setup()", 1, true) ~= nil
  and editor_src:find('bufdelete', 1, true) == nil
  and keymaps_src:find('Bdelete', 1, true) == nil)
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
check('spare themes never cost startup',
  ui:find("nightfox.nvim', event = 'VeryLazy'", 1, true) ~= nil
  and ui:find("tokyonight.nvim', event = 'VeryLazy'", 1, true) ~= nil)
check('lualine shortens toggleterm to term', ui:find("s == 'toggleterm' and 'term'", 1, true) ~= nil)
check('lualine shows relative filepath', ui:find("'filename', path = 1", 1, true) ~= nil)
check('lualine collapses term buffers to term N', ui:find("#toggleterm#(%d+)", 1, true) ~= nil)
check('lualine labels terms with the tab count', ui:find("require('config.terminal').label", 1, true) ~= nil)
-- C++ buffers show their standard: the file's own -std= flag wins,
-- CMAKE_CXX_STANDARD covers files the db skips (headers), and unknown
-- files stay plain C++.
check('lualine shows the C++ standard',
  ui:find("config.cxx_standard').label()", 1, true) ~= nil)
do
  local cxx = require('config.cxx_standard')
  local root = vim.fn.resolve(vim.fn.tempname())
  vim.fn.mkdir(root .. '/src', 'p')
  vim.fn.mkdir(root .. '/build', 'p')
  local cc = '[{"directory":"%s/build",'
    .. '"command":"c++ -std=c++20 -c ../src/a.cpp",'
    .. '"file":"%s/src/a.cpp"},'
    .. '{"directory":"%s/build",'
    .. '"arguments":["c++","-std=gnu++23","-c","../src/b.cpp"],'
    .. '"file":"../src/b.cpp"},'
    .. '{"directory":"%s/build",'
    .. '"command":"c++ -std=c++2b -c ../src/c.cpp",'
    .. '"file":"%s/src/c.cpp"}]'
  vim.fn.writefile(
    { string.format(cc, root, root, root, root, root) },
    root .. '/build/compile_commands.json')
  check('cc command flag resolves',
    cxx.std_for_file(root .. '/src/a.cpp') == '20')
  check('cc arguments and relative file resolve',
    cxx.std_for_file(root .. '/src/b.cpp') == '23')
  check('cc future flag names map back',
    cxx.std_for_file(root .. '/src/c.cpp') == '23')
  vim.fn.writefile(
    { 'cmake_minimum_required(VERSION 3.28)', 'set(CMAKE_CXX_STANDARD 17)' },
    root .. '/CMakeLists.txt')
  check('cmake covers headers missing from db',
    cxx.std_for_file(root .. '/src/h.hpp') == '17')
  local bare = vim.fn.resolve(vim.fn.tempname())
  vim.fn.mkdir(bare, 'p')
  check('unknown stays nil for a plain label',
    cxx.std_for_file(bare .. '/x.cpp') == nil)
  vim.fn.writefile({ 'int main() {}' }, root .. '/src/a.cpp')
  vim.cmd('edit ' .. vim.fn.fnameescape(root .. '/src/a.cpp'))
  vim.bo.filetype = 'cpp'
  check('label renders C++NN', cxx.label() == 'C++20')
  vim.api.nvim_buf_delete(0, { force = true })
  vim.fn.delete(root, 'rf')
  vim.fn.delete(bare, 'rf')
end
check('center toggle installed on leader-z', ui:find('shortcuts/no-neck-pain.nvim', 1, true) ~= nil
  and ui:find("'<leader>z', '<cmd>NoNeckPain<cr>'", 1, true) ~= nil
  and ui:find('width = 120', 1, true) ~= nil)
check('centering is on by default', ui:find("enableOnVimEnter = 'safe'", 1, true) ~= nil
  and ui:find('enableOnTabEnter = true', 1, true) ~= nil)
local openlink_src = read(nvim .. '/lua/config/openlink.lua')
check('pdfs hand off to the OS viewer', openlink_src:find('vim.ui.open(target.file)', 1, true) ~= nil)
check('tree l opens pdfs in Preview', editor_src:find('vim.ui.open(node.absolute_path)', 1, true) ~= nil
  and editor_src:find("match('%.pdf$')", 1, true) ~= nil)
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

-- 12b. One cwd owner + instant statusline: the land helpers route through
-- tree.change_root (no second tcd site), which refreshes lualine when it
-- is already loaded and stays quiet when it is not. Default floats open
-- two Alt+[ narrow steps slimmer.
do
  local land_src = read(nvim .. '/lua/config/telescope_land.lua')
  check('tab-cwd changes live in one place', land_src:find('tcd', 1, true) == nil
    and land_src:find('change_root', 1, true) ~= nil)
  check('default float opens two narrow-steps slimmer',
    read(nvim .. '/lua/plugins/editor.lua'):find('columns * 0.8) - 10', 1, true) ~= nil)
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, 'p')
  dir = vim.fn.resolve(dir)
  local back = vim.fn.getcwd()
  local refreshed = 0
  package.loaded['lualine'] = { refresh = function() refreshed = refreshed + 1 end }
  package.preload['nvim-tree.api'] = function()
    return { tree = { change_root = function() end } }
  end
  require('config.tree').change_root(dir)
  check('change_root cds the tab', vim.fn.getcwd() == dir)
  check('change_root refreshes a loaded statusline', refreshed == 1)
  package.loaded['lualine'] = nil
  require('config.tree').change_root(dir)
  check('change_root stays quiet without lualine', vim.fn.getcwd() == dir)
  vim.cmd('tcd ' .. vim.fn.fnameescape(back))
  package.loaded['lualine'] = nil
  package.loaded['nvim-tree.api'] = nil
  package.preload['nvim-tree.api'] = nil
  vim.fn.delete(dir, 'rf')
end

-- 12c. Descend-then-land: after Enter drops into a folder, selection sits
-- on the `..` parent row, so Cmd+O must land the browsed folder itself —
-- while a folder highlighted inside the browsed one still wins.
do
  local root = vim.fn.tempname()
  vim.fn.mkdir(root .. '/SWE/SUB', 'p')
  vim.fn.writefile({}, root .. '/SWE/file.txt')
  local closed, tree_root, selected = nil, nil, nil
  local finder_path, finder_files, finder_cwd = nil, nil, nil
  -- Earlier sections cached mocks in package.loaded: drop them so the
  -- preloads below take effect.
  package.loaded['telescope.actions'] = nil
  package.loaded['telescope.actions.state'] = nil
  package.loaded['nvim-tree.api'] = nil
  package.loaded['lualine'] = nil
  package.preload['telescope.actions'] = function()
    return { close = function(bufnr) closed = bufnr end }
  end
  package.preload['nvim-tree.api'] = function()
    return { tree = { change_root = function(dir) tree_root = dir end } }
  end
  package.preload['telescope.actions.state'] = function()
    return {
      get_current_picker = function()
        return { finder = { path = finder_path, files = finder_files, cwd = finder_cwd } }
      end,
      get_selected_entry = function() return selected end,
    }
  end
  local back = vim.fn.getcwd()
  -- tempname() sits under /var (a symlink to /private/var): resolve once
  -- so browsed, highlighted, and asserted paths compare identically.
  local rroot = vim.fn.resolve(root)
  local swe = rroot .. '/SWE'
  local sub = rroot .. '/SWE/SUB'
  local land = require('config.telescope_land')
  -- Browsing SWE with the `..` parent row highlighted: stay in SWE.
  finder_path, finder_files, finder_cwd = swe, nil, nil
  selected = { path = rroot, Path = { is_dir = function() return true end, absolute = function() return rroot end } }
  closed, tree_root = nil, nil
  land.land_here(7)
  check('land after descend stays in browsed dir', closed == 7 and vim.fn.getcwd() == swe and tree_root == swe)
  -- Browsing SWE with a file highlighted: same.
  selected = { path = swe .. '/file.txt' }
  closed, tree_root = nil, nil
  land.land_here(7)
  check('land on highlighted file stays browsed', vim.fn.getcwd() == swe and tree_root == swe)
  -- Browsing SWE with a subfolder highlighted: the subfolder wins.
  selected = { path = sub }
  closed, tree_root = nil, nil
  land.land_here(7)
  check('land on inner folder follows highlight', vim.fn.getcwd() == sub and tree_root == sub)
  -- Browsing the parent with SWE highlighted: original pick-and-land.
  finder_path = rroot
  selected = { path = swe }
  closed, tree_root = nil, nil
  land.land_here(7)
  check('land on outer folder follows highlight', vim.fn.getcwd() == swe and tree_root == swe)
  vim.cmd('tcd ' .. vim.fn.fnameescape(back))
  package.preload['telescope.actions'] = nil
  package.preload['nvim-tree.api'] = nil
  package.preload['telescope.actions.state'] = nil
  package.loaded['telescope.actions'] = nil
  package.loaded['telescope.actions.state'] = nil
  package.loaded['nvim-tree.api'] = nil
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
  -- One server list drives both install and enable: adding a server
  -- means one entry, and the two sites can never drift apart.
  check('one server table drives install+enable',
    lsp_src:find('local servers = {', 1, true) ~= nil
    and lsp_src:find('ensure_installed = servers', 1, true) ~= nil
    and lsp_src:find('vim.lsp.enable(servers)', 1, true) ~= nil)
  local _, entries = lsp_src:gsub("'rust_analyzer'", '')
  check('server list written exactly once', entries == 1)
end
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

-- 16. Escalating close: Cmd+W closes the buffer, or the tab when the
-- buffer is empty (never the window); Shift+Cmd+W the tab,
-- Ctrl+Shift+Cmd+W the window. Telescope Enter roots the tree at the
-- opened file's dir; <leader>cr prompts for a new tree root (.. goes up).
check('Cmd+W routes through buffer_close', keymaps_src:find("<D-w>", 1, true) ~= nil
  and keymaps_src:find('config.buffer_close', 1, true) ~= nil
  and keymaps_src:find('close_buffer_or_tab', 1, true) ~= nil)
do
  local bc_src = read(nvim .. '/lua/config/buffer_close.lua')
  check('empty buffer tries tabclose, never window close',
    bc_src:find('tabclose', 1, true) ~= nil
    and bc_src:find('MiniBufremove', 1, true) ~= nil
    and bc_src:find("'quit", 1, true) == nil
    and bc_src:find("'close", 1, true) == nil
    and bc_src:find("'qa", 1, true) == nil
    and bc_src:find("close_window", 1, true) == nil)
end
for _, mode in ipairs({ 'n', 'v', 'i', 't' }) do
  check('Cmd+W works from ' .. mode, vim.fn.maparg('<D-w>', mode) ~= '')
end
do
  local bc = require('config.buffer_close')
  check('buffer_close module exposes close_buffer_or_tab', type(bc.close_buffer_or_tab) == 'function')
  local empty = vim.api.nvim_create_buf(true, false)
  check('fresh buffer counts as empty', bc.is_empty_buffer(empty))
  vim.api.nvim_buf_set_lines(empty, 0, -1, false, { 'hello' })
  check('buffer with text is not empty', not bc.is_empty_buffer(empty))
  vim.api.nvim_buf_delete(empty, { force = true })
  local named = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(named, vim.fn.tempname())
  check('named buffer is not empty', not bc.is_empty_buffer(named))
  vim.api.nvim_buf_delete(named, { force = true })
  -- Empty buffer closes the tab: open a second tab, close from its
  -- empty buffer, land back on one tab.
  vim.cmd('tabnew')
  vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true, false))
  check('empty Cmd+W closes the tab', bc.close_buffer_or_tab() == 'tabclose'
    and vim.fn.tabpagenr('$') == 1)
  -- Last tab is a no-op (tabclose fails), never an error.
  vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true, false))
  local ok = pcall(bc.close_buffer_or_tab)
  check('empty Cmd+W on last tab is safe', ok and vim.fn.tabpagenr('$') == 1)
  -- Non-empty buffer goes to MiniBufremove, tabs untouched.
  local tabs = vim.fn.tabpagenr('$')
  local full = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(full)
  vim.api.nvim_buf_set_lines(full, 0, -1, false, { 'keep me' })
  local deleted = nil
  _G.MiniBufremove = { delete = function(...) deleted = { ... } end }
  check('full Cmd+W closes the buffer', bc.close_buffer_or_tab() == 'buffer'
    and deleted ~= nil and vim.fn.tabpagenr('$') == tabs)
  _G.MiniBufremove = nil
  vim.api.nvim_buf_delete(full, { force = true })
end
for _, p in ipairs({ home .. '/.config/ghostty/config', home .. '/.config/ghostty/nvim-launcher' }) do
  local tag, c = p:match('[^/]+$'), read(p)
  check(tag .. ' Cmd+W reaches nvim', c:find('super+w=text', 1, true) ~= nil)
  check(tag .. ' Shift+Cmd+W closes tab', c:find('super+shift+w=close_tab', 1, true) ~= nil)
  check(tag .. ' Ctrl+Shift+Cmd+W closes window', c:find('super+ctrl+shift+w=close_window', 1, true) ~= nil)
  check(tag .. ' Cmd+Opt+Shift+W disarmed', c:find('super+alt+shift+w=unbind', 1, true) ~= nil)
end
check('kitty Shift+Cmd+W closes tab',
  read(home .. '/.config/kitty/kitty.conf'):find('shift+cmd+w close_tab', 1, true) ~= nil)
check('kitty Ctrl+Shift+Cmd+W closes window',
  read(home .. '/.config/kitty/kitty.conf'):find('ctrl+shift+cmd+w close_window', 1, true) ~= nil)
do
  -- Slots are retired: no digit family may send sequences nvim ignores.
  local kitty_conf = read(home .. '/.config/kitty/kitty.conf')
  check('kitty slot digits stay retired',
    kitty_conf:find('cmd+shift+1 send_text', 1, true) == nil
    and kitty_conf:find('cmd+ctrl+1 send_text', 1, true) == nil)
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

-- 17. Cmd+Delete trashes the nvim-tree node under the cursor (Finder
-- parity): buffer-local <D-BS> on api.fs.trash, CSI-u super transport
-- in both Ghostty files (from shared-keybinds.conf) and kitty.
check('tree Cmd+Delete trashes node', editor_src:find("<D-BS>', api.fs.trash", 1, true) ~= nil)
for _, p in ipairs({ home .. '/.config/ghostty/config', home .. '/.config/ghostty/nvim-launcher' }) do
  local tag, c = p:match('[^/]+$'), read(p)
  check(tag .. ' Cmd+Delete reaches nvim', c:find('super+backspace=text', 1, true) ~= nil)
end
check('kitty Cmd+Delete reaches nvim', kitty:find('cmd+backspace send_text all \\e[127;9u', 1, true) ~= nil)

-- 18. gx opens Markdown file links in a new buffer at the line.
local openlink = require('config.openlink')
local md = '[resume](/Users/c/Jobs/applications/x/resume.typ:12)'
local t1 = openlink.extract(md, 5, '/tmp')
check('md link extracts file+line', t1 and t1.file == '/Users/c/Jobs/applications/x/resume.typ' and t1.lnum == 12)
local t2 = openlink.extract(md, 1, '/tmp')
check('md link works from the label', t2 and t2.file == '/Users/c/Jobs/applications/x/resume.typ')
local t3 = openlink.extract('see [a](/x/a.lua) and [b](/y/b.lua:3)', 26, '/tmp')
check('cursor picks the link it is on', t3 and t3.file == '/y/b.lua' and t3.lnum == 3)
local t4 = openlink.extract('open /Users/c/Jobs/content/skills.yml please', 10, '/tmp')
check('bare path extracts', t4 and t4.file == '/Users/c/Jobs/content/skills.yml' and t4.lnum == nil)
local t5 = openlink.extract('nothing to open here', 5, '/tmp')
check('plain words are nil', t5 == nil)
local t6 = openlink.extract('[site](https://example.com)', 5, '/tmp')
check('urls stay urls', t6 and t6.url == 'https://example.com')
local t7 = openlink.extract('[rel](docs/notes.md)', 5, '/base')
check('relative links resolve at the file dir', t7 and t7.file == '/base/docs/notes.md')
check('gx opens link under cursor', vim.fn.maparg('gx', 'n') ~= '')
check('tree exempts applications from ignore filter',
  editor_src:find("exclude = { 'applications' }", 1, true) ~= nil)

-- 19. Right-click popup: the "How to disable mouse" item (and its
-- trailing separator) is gone; the useful PopUp items stay. options.lua
-- removes them at startup (Neovim's defaults define them), and section 2
-- above already required config.options, so assert the live menu state.
do
  local popup = vim.fn.getcompletion('PopUp.', 'menu')
  check('right-click menu drops How-to-disable-mouse',
    not vim.tbl_contains(popup, 'How-to\\ disable\\ mouse'))
  check('right-click menu drops trailing separator',
    not vim.tbl_contains(popup, '-2-'))
  check('right-click menu keeps useful items',
    vim.tbl_contains(popup, 'Inspect') and vim.tbl_contains(popup, 'Copy'))
end

-- 20. Terminal tab label: floats read this tab's position over its
-- terminal count (`term 2 / 3`), plain `term 1` when alone — so two tabs
-- with one terminal each both read `term 1`. The count refreshes
-- without forcing lualine to load.
do
  local term_label_src = read(nvim .. '/lua/config/terminal.lua')
  check('terminal label counts this tab',
    term_label_src:find('term %d / %d', 1, true) ~= nil
    and term_label_src:find('function M.tab_order', 1, true) ~= nil
    and term_label_src:find('function M.title_label_for', 1, true) ~= nil)
  local ac_src20 = read(nvim .. '/lua/config/autocmds.lua')
  check('tab count refreshes without forcing lualine',
    ac_src20:find('TerminalCountRefresh', 1, true) ~= nil
    and ac_src20:find('TermClose', 1, true) ~= nil
    and ac_src20:find("package.loaded['lualine']", 1, true) ~= nil)
  check('garbage term input stays plain', terminal.label(nil) == 'term')
  -- Fake the terminals with named scratch buffers (a `terminal` buftype
  -- cannot be faked onto a scratch buffer headless (E474), but the tab
  -- order only reads the #toggleterm#N buffer names).
  vim.cmd('tabnew')
  local function term_buf(n)
    local b = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(b, 'zsh;#toggleterm#' .. n)
    return b
  end
  local b1, b2, b5 = term_buf(1), term_buf(2), term_buf(5)
  vim.api.nvim_set_current_buf(b1)
  vim.cmd('vsplit')
  vim.api.nvim_set_current_buf(b2)
  check('tab with two terms counts two', terminal.count() == 2)
  check('label shows tab position over size', terminal.label(2) == 'term 2 / 2')
  check('title counts the tab too',
    terminal.title_label_for('terminal', 'zsh;#toggleterm#2', '') == 'term 2 / 2')
  -- Swap in the gappy slot: positions, not slot ids.
  vim.api.nvim_set_current_buf(b5)
  check('label numbers positions, not slots', terminal.label(5) == 'term 2 / 2')
  check('stale slots fall back plain', terminal.label(9) == 'term 9')
  -- Lone terminal reads `term 1` even on a high slot.
  vim.api.nvim_buf_delete(b1, { force = true })
  vim.api.nvim_buf_delete(b2, { force = true })
  check('lone term stays plain', terminal.label(5) == 'term 1')
  check('title on plain terminals stays term',
    terminal.title_label_for('terminal', 'term://x', '') == 'term')
  check('title on files stays the tail',
    terminal.title_label_for('', '/x/foo.lua', 'foo.lua') == 'foo.lua')
  vim.cmd('enew')
  check('title on empty buffers stays nvim', terminal.title_label() == 'nvim')
  vim.api.nvim_buf_delete(b5, { force = true })
  vim.cmd('tabclose')
  check('empty tab counts zero', terminal.count() == 0)
end

-- 21. Tailwind LS only where Tailwind lives: a tailwind config, a
-- package.json depending on tailwindcss (v4 needs no config file), or a
-- mix/Gemfile lock mentioning tailwind. A plain git checkout resolves
-- to nil, so with workspace_required no server spawns there.
do
  local tw = dofile(nvim .. '/lsp/tailwindcss.lua')
  check('tailwind config gates on root_dir', type(tw.root_dir) == 'function')
  local base = vim.fn.resolve(vim.fn.tempname())
  local function mk(rel, content)
    local p = base .. '/' .. rel
    vim.fn.mkdir(vim.fn.fnamemodify(p, ':h'), 'p')
    vim.fn.writefile({ content or '' }, p)
  end
  mk('v3/tailwind.config.js', 'module.exports = {}')
  mk('v3/src/a.css', '@tailwind base;')
  mk('v4/package.json', '{"dependencies":{"@tailwindcss/vite":"4.0.0"}}')
  mk('v4/src/a.css', '@import "tailwindcss";')
  mk('plain/.git/HEAD', 'ref: refs/heads/main')
  mk('plain/src/a.css', 'a {}')
  mk('bare/src/a.css', 'a {}')
  local function root_of(rel)
    vim.cmd('edit ' .. vim.fn.fnameescape(base .. '/' .. rel))
    local buf = vim.api.nvim_get_current_buf()
    local called, dir = false, nil
    tw.root_dir(buf, function(d) called, dir = true, d end)
    vim.api.nvim_buf_delete(buf, { force = true })
    return called, dir
  end
  local c, d = root_of('v3/src/a.css')
  check('tailwind config file roots the project', c and d == base .. '/v3')
  c, d = root_of('v4/src/a.css')
  check('v4 package dep roots without a config', c and d == base .. '/v4')
  c, d = root_of('plain/src/a.css')
  check('plain git repo gets no tailwind root', c and d == nil)
  c, d = root_of('bare/src/a.css')
  check('bare dir gets no tailwind root', c and d == nil)
  vim.fn.delete(base, 'rf')
end

-- Image preview: image.nvim renders open images via Kitty graphics
-- (Ghostty speaks the protocol), Telescope media_files thumbnails ride
-- on chafa, and Markdown inline images need the markdown parsers.
do
  local image_src = read(nvim .. '/lua/plugins/image.lua')
  check('image preview uses the kitty backend',
    image_src:find("backend = 'kitty'", 1, true) ~= nil)
  check('image preview shells out to magick',
    image_src:find("processor = 'magick_cli'", 1, true) ~= nil)
  check('image preview hijacks image files on open',
    image_src:find('hijack_file_patterns', 1, true) ~= nil
    and image_src:find("'*.png'", 1, true) ~= nil)
  check('image preview stays off without the magick CLI',
    image_src:find("vim.fn.executable('magick')", 1, true) ~= nil)
  check('markdown parsers installed for inline images',
    editor_src:find("'markdown'", 1, true) ~= nil
    and editor_src:find("'markdown_inline'", 1, true) ~= nil)
  check('telescope media extension wired with chafa filetypes',
    editor_src:find('telescope-media-files.nvim', 1, true) ~= nil
    and editor_src:find('media_files', 1, true) ~= nil
    and editor_src:find("'webp'", 1, true) ~= nil
    and editor_src:find("'pdf'", 1, true) ~= nil)
  check('PDFs hijack to an in-buffer render',
    image_src:find("'*.pdf'", 1, true) ~= nil)
  check('SVG stays editable text, never hijacked',
    image_src:find("'*.svg'", 1, true) == nil)
  check('raw-bytes hatch bound on rendered buffers',
    image_src:find('ImageRawView', 1, true) ~= nil
    and image_src:find("'<leader>ir'", 1, true) ~= nil
    and image_src:find('is_enabled()', 1, true) ~= nil)
end

-- Tree focus vs the centerer: the hold-off is synchronous (no debounce
-- window for a re-init to land in) and the settle converges over bounded
-- passes instead of a single shot.
do
  local tree_src = read(nvim .. '/lua/config/tree.lua')
  check('tree hold-off is synchronous',
    tree_src:find('nnp_hold_off_now', 1, true) ~= nil
    and tree_src:find("main.disable, 'tree:hold'", 1, true) ~= nil)
  check('tree settle converges over passes',
    tree_src:find('settle_gaps', 1, true) ~= nil
    and tree_src:find('want_focus', 1, true) ~= nil)
end

if failures > 0 then
  print(failures .. ' check(s) failed')
  os.exit(1)
end
print('all checks passed')
