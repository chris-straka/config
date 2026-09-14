-- Ported from old mappings.lua. which-key descriptions live in whichkey.lua.
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Space is ONLY the leader now (it used to toggle the tree, which made every
-- Space press wait timeoutlen and feel laggy). The tree lives on Cmd+E,
-- Alt+E and <leader>e instead.
map('n', 'n', 'nzz', opts)
map('n', 'N', 'Nzz', opts)
map('v', '<', '<gv', opts)
map('v', '>', '>gv', opts)
map('n', '<TAB>', ':bnext<CR>', opts)
map('n', '<S-TAB>', ':bprevious<CR>', opts)
map('n', '<ESC>', ':nohlsearch<Bar>:echo<CR>', opts)
map('v', 'p', '"_dP', opts)
map('c', 'w!!', "execute 'write !sudo tee % >/dev/null' <bar> edit!", opts)

-- move lines up/down. [e / ]e works in every Mac terminal (no Option-as-Alt
-- needed, unlike Alt-Up/Down). Visual J/K left alone: J joins lines.
map('n', '[e', ':m .-2<CR>==', { noremap = true, silent = true, desc = 'Move line up' })
map('n', ']e', ':m .+1<CR>==', { noremap = true, silent = true, desc = 'Move line down' })
map('v', '[e', ":m '<-2<CR>gv=gv", { noremap = true, silent = true, desc = 'Move selection up' })
map('v', ']e', ":m '>+1<CR>gv=gv", { noremap = true, silent = true, desc = 'Move selection down' })

-- window navigation (old ',' prefix kept via whichkey, plus Alt-hjkl)
map('n', ',', '<C-w>', opts)
map({ 'n', 't', 'i' }, '<A-h>', '<C-w>h', opts)
map({ 'n', 't', 'i' }, '<A-j>', '<C-w>j', opts)
map({ 'n', 't', 'i' }, '<A-k>', '<C-w>k', opts)
map({ 'n', 't', 'i' }, '<A-l>', '<C-w>l', opts)

-- tree / terminal / finder (plugin commands must exist at runtime, so plain strings)
-- FindFileToggle reveals the current file in the tree, like VSCode explorer focus.
map({ 'n', 'v' }, '<A-e>', ':NvimTreeFindFileToggle<CR>', opts)
-- Cmd+E focuses the tree AND reveals the current file (VSCode explorer:
-- cursor moves in). Shift+Cmd+E peeks instead (open + reveal, cursor
-- stays in code). Terminals send CSI-u with the super modifier, decoded
-- straight to <D-e> / <D-S-e> (see their configs); Ghostty's default
-- Cmd+E (search selection) is overridden there to send it. The
-- <Esc>[925;1~ maps are the pre-0.12 fallback and stay harmless.
map({ 'n', 'v', 'i' }, '<D-e>', function() require('config.tree').focus(true) end, opts)
map({ 'n', 'v', 'i' }, '<Esc>[925;1~', function() require('config.tree').focus(true) end, opts)
map({ 'n', 'v', 'i' }, '<D-S-e>', function() require('config.tree').peek(true) end, opts)
-- Same from inside a toggleterm float (Terminal-Insert): a bare `:cmd`
-- RHS would be typed into the shell job in t mode, so drop to
-- Terminal-Normal first, then call the module like everywhere else.
map('t', '<Esc>[925;1~', '<C-\\><C-n><cmd>lua require("config.tree").focus(true)<cr>', opts)
-- Same for the live transport: CSI-u super decodes to <D-e> / <D-S-e>,
-- which have no t map above, so both need their own drop-to-Normal first.
map('t', '<D-e>', '<C-\\><C-n><cmd>lua require("config.tree").focus(true)<cr>', opts)
map('t', '<D-S-e>', '<C-\\><C-n><cmd>lua require("config.tree").peek(true)<cr>', opts)
-- Middle-click opens the tree (focused, current file revealed) instead of
-- pasting. Needs `mouse = 'a'` above, or the emulator eats the click.
map({ 'n', 'v', 'i', 't' }, '<MiddleMouse>', function() require('config.tree').focus(true) end,
  { noremap = true, silent = true, desc = 'Open file tree' })
-- (old Alt bank lived here; Alt+N now toggles the current slot's terminal — loop below)
-- Alt+Right intentionally left unmapped in terminal modes: Ghostty sends it
-- as Esc+f, which the shell reads as word-forward (VSCode behavior). It used
-- to toggle the float here, which is why Option+Right "closed" terminals.
-- In normal buffers the same keys would stall on find-char, so hop instead
-- (mirrors the free Esc+b word-back on Alt+Left).
map('n', '<A-f>', 'w', { noremap = true, silent = true, desc = 'Word forward' })
-- (Retired: Alt+V toggled terminal 2, byte-for-byte the same terminal as
-- Cmd+2/Alt+2. One binding per terminal now.)
-- Floating terminals, one Ghostty tab = one project so plain global ids are
-- enough: Alt+N toggles terminal N of THIS tab's nvim. A dev server on
-- term 2 keeps running in that tab while you work in another Ghostty tab
-- (separate nvim process, fully isolated). Digit 0 means 10. Cmd+N is
-- Ghostty's: Cmd+1..8 jump to project tabs, Cmd+9 to the last tab.
for _i = 1, 10 do
  local _n, _d = _i, (_i == 10 and '0' or tostring(_i))
  local _rhs = '<cmd>' .. _n .. 'ToggleTerm direction=float<cr>'
  -- Insert included: Alt+digits must work while typing, since the
  -- emulators deliver modifiers as Esc sequences. toggleterm's on_open
  -- startinsert lands the opened float in Terminal-Insert no matter which
  -- mode we toggled from.
  map({ 'n', 't', 'i' }, '<A-' .. _d .. '>', _rhs, opts)
  map({ 'n', 't', 'i' }, '<Esc>[' .. (899 + _i) .. ';1~', _rhs, opts)
end
-- (old 900-909 sequences covered by the loop above; 910-919 slot-select and
-- 930-939 Cmd+Ctrl sequences retired with slots. 920-925 below stay.)
-- Remaining Cmd maps arrive as CSI-u super encodings decoded to <D-...>
-- (see terminal configs); the <Esc>[92x;1~ maps are the pre-0.12 fallback.
-- Without this, Cmd never reaches terminal nvim and these silently do nothing.
map('n', '<Esc>[920;1~', '<cmd>Telescope find_files<cr>', { noremap = true, silent = true, desc = 'Find files' })
map('n', '<Esc>[921;1~', '<cmd>Telescope file_browser path=%:p:h select_buffer=true hidden=true<cr>',
  { noremap = true, silent = true, desc = 'Browse files…' })
map('n', '<Esc>[922;1~', '<cmd>Telescope live_grep<cr>', { noremap = true, silent = true, desc = 'Search in files' })
map('n', '<Esc>[923;1~', '<cmd>redo<cr>', { noremap = true, silent = true, desc = 'Redo' })
map('n', '<Esc>[924;1~', 'u', { noremap = true, silent = true, desc = 'Undo' })
-- Insert variants of the translated Cmd keys above: without these, hitting
-- Cmd+P/O/F/Z/Shift+Z while typing drops to Normal and spills literal
-- `[92…;1~` text. <C-o> runs one Normal command and resumes typing.
map('i', '<Esc>[920;1~', '<C-o>:Telescope find_files<cr>', { noremap = true, silent = true, desc = 'Find files' })
map('i', '<Esc>[921;1~', '<C-o>:Telescope file_browser path=%:p:h select_buffer=true hidden=true<cr>',
  { noremap = true, silent = true, desc = 'Browse files…' })
map('i', '<Esc>[922;1~', '<C-o>:Telescope live_grep<cr>', { noremap = true, silent = true, desc = 'Search in files' })
map('i', '<Esc>[923;1~', '<C-o>:redo<cr>', { noremap = true, silent = true, desc = 'Redo' })
map('i', '<Esc>[924;1~', '<C-o>u', { noremap = true, silent = true, desc = 'Undo' })
map('v', '<Esc>[924;1~', '<Esc>u', { noremap = true, silent = true, desc = 'Undo' })
map('n', '<C-p>', '<cmd>Telescope find_files<cr>', { noremap = true, silent = true, desc = 'Find files' })
map('n', '<D-p>', '<cmd>Telescope find_files<cr>', { noremap = true, silent = true, desc = 'Find files' })
-- Cmd+Shift+F: search text inside files (VSCode find-in-files).
-- find_files matches file NAMES; live_grep matches file CONTENTS.
map('n', '<D-S-f>', '<cmd>Telescope live_grep<cr>', { noremap = true, silent = true, desc = 'Search in files' })
-- Ctrl+R: recent projects picker (VSCode Ctrl+R).
-- This takes over Vim's built-in redo on Ctrl+R; redo lives on Cmd+Shift+Z.
map('n', '<C-r>', '<cmd>Telescope projects<cr>', { noremap = true, silent = true, desc = 'Recent projects' })
-- Cmd+O: fuzzy file/folder browser (VSCode Open Folder). Navigate anywhere,
-- open any file and the project root follows automatically. Recents on Ctrl+R.
map('n', '<D-o>', '<cmd>Telescope file_browser path=%:p:h select_buffer=true hidden=true<cr>',
  { noremap = true, silent = true, desc = 'Browse files…' })
-- VSCode-style folding: Cmd+Opt+[ folds, Cmd+Opt+] unfolds (folds come from
-- the treesitter grammar, see options.lua). `za` still toggles, `zM`/`zR`
-- close/open everything. The <Esc>[9x;11u maps are the same bytes written
-- out for pre-0.12 nvim, matching the digit-loop fallback pattern above.
map({ 'n', 'v' }, '<D-M-[>', 'zc', { noremap = true, silent = true, desc = 'Fold' })
map({ 'n', 'v' }, '<D-M-]>', 'zo', { noremap = true, silent = true, desc = 'Unfold' })
map({ 'n', 'v' }, '<Esc>[91;11u', 'zc', { noremap = true, silent = true, desc = 'Fold' })
map({ 'n', 'v' }, '<Esc>[93;11u', 'zo', { noremap = true, silent = true, desc = 'Unfold' })
-- Cmd+Shift+Z: redo (VSCode redo). u undoes, this re-applies.
map('n', '<D-S-z>', '<cmd>redo<cr>', { noremap = true, silent = true, desc = 'Redo' })
-- Cmd+Z: undo (VSCode undo). Kept out of terminal mode on purpose so it
-- still reaches the shell job (suspend). Visual uses <Esc>u because bare
-- u there means lowercase, not undo.
-- Space+h peeks the tree (open, cursor stays in code); Shift+Cmd+E
-- peeks with the current file revealed, Cmd+E focuses it.
-- See config/tree.lua for the mechanism.
map('n', '<leader>h', function() require('config.tree').peek(false) end,
  { noremap = true, silent = true, desc = 'Peek file tree' })
map('n', '<D-z>', 'u', { noremap = true, silent = true, desc = 'Undo' })
map('i', '<D-z>', '<C-o>u', { noremap = true, silent = true, desc = 'Undo' })
map('v', '<D-z>', '<Esc>u', { noremap = true, silent = true, desc = 'Undo' })
-- Cmd+C copies the visual selection (VSCode habit). Plain `y` already
-- reaches the system clipboard (clipboard=unnamedplus); this binds the
-- familiar key. Yank is not a modification, so it works in read-only
-- buffers too (terminal floats, tree, prompts) — edits there fail with
-- E21 'modifiable is off', which is the error you get when a keystroke
-- tries to change a buffer Neovim marked read-only. Needs the matching
-- Ghostty bind (super+c -> <D-c>); without it the emulator eats Cmd+C.
map('v', '<D-c>', '"+y', { noremap = true, silent = true, desc = 'Copy selection' })

-- Code runner (VSCode code-runner button): <leader>of runs the current
-- file with the right interpreter via overseer (see config/runner.lua);
-- output docks at the bottom, stop/re-run from <leader>ot.
map('n', '<leader>of', function() require('config.runner').run_file() end,
  { noremap = true, silent = true, desc = 'Run current file' })
-- Option+K from a visual selection (Claude Code @-mention habit): types
-- @file / @file#l1-l2 into the visible floating terminal. No Ghostty
-- change needed — left-Opt-as-Alt already delivers Option+K as <A-k>,
-- and <A-k> is unbound in visual mode (window nav owns it in normal).
map('v', '<A-k>', function() require('config.runner').send_at_reference() end,
  { noremap = true, silent = true, desc = 'Send @file ref to terminal' })

-- Manual session snapshots (mini.sessions): save and restore the whole
-- open layout on demand (one Ghostty tab = one project, one session each).
map('n', '<leader>Sw', function()
  vim.ui.input({ prompt = 'Save session: ' }, function(name)
    if name and name ~= '' then require('mini.sessions').write(name) end
  end)
end, { noremap = true, silent = true, desc = 'Save session snapshot' })
map('n', '<leader>Sr', function()
  vim.ui.select(vim.tbl_keys(require('mini.sessions').detected), { prompt = 'Read session:' }, function(name)
    if name then require('mini.sessions').read(name) end
  end)
end, { noremap = true, silent = true, desc = 'Read session snapshot' })

-- floating terminal: '\' plus <leader>t plus toggleterm's <C-\>.
-- Backslash works from normal and terminal mode, so it toggles both ways.
-- Tradeoff: inside a termbuff, typing a literal backslash becomes Ctrl-V then backslash.
map('n', '<leader>t', '<cmd>ToggleTerm direction=float<cr>', { noremap = true, silent = true, desc = 'Floating terminal' })
map({ 'n', 't' }, '\\', '<cmd>ToggleTerm direction=float<cr>', { noremap = true, silent = true, desc = 'Floating terminal' })
-- Terminal-mode exit ramp: `|` drops to Terminal-Normal (navigate/copy
-- mode). A single Esc passes straight to the shell job, so TUIs keep
-- their own Esc — Muse's interrupt, fzf/lazygit cancel — and double-Esc
-- is gone on purpose (too easy to fire half of it into the shell).
-- Cost of the pipe: `|` can no longer be typed inside a terminal float,
-- so shell pipelines must be composed elsewhere; revert to
-- `map('t', '<Esc><Esc>', ...)` if that ever hurts more than it helps.
-- Ctrl+C is untouched and reaches the shell too — but in Muse it quits,
-- so interrupt with Esc, not Ctrl+C.
map('t', '|', '<C-\\><C-n>', { noremap = true, silent = true, desc = 'Terminal to Normal mode' })
-- Exit the focused terminal (see config/terminal.lua): types `exit` +
-- Enter into its shell, so the shell ends and the float goes away;
-- reopen with Alt+N for a fresh shell. <leader>tR stays Normal-only on
-- purpose: a <leader> mapping in terminal mode would make every Space
-- typed into the shell wait timeoutlen for a follow-up key (from inside
-- a terminal: `|` first). Alt+X is a bare Alt key with no such timeout
-- cost, so it binds in normal, terminal, and insert modes and works
-- straight from Terminal-Insert.
map('n', '<leader>tR', function() require('config.terminal').exit_focused() end,
  { noremap = true, silent = true, desc = 'Exit focused terminal' })
map({ 'n', 't', 'i' }, '<A-x>', function() require('config.terminal').exit_focused() end,
  { noremap = true, silent = true, desc = 'Exit focused terminal' })

-- Resize the current float: Alt-, shrink width, Alt-. grow width,
-- Alt-- shrink height, Alt-= grow height. No-op on non-floats.
local function resize_float(dw, dh)
  local win = vim.api.nvim_get_current_win()
  if vim.fn.win_gettype(win) ~= 'popup' then return end
  if dw ~= 0 then
    local w = vim.api.nvim_win_get_width(win) + dw
    w = math.max(60, math.min(vim.o.columns - 4, w))
    vim.api.nvim_win_set_width(win, w)
  end
  if dh ~= 0 then
    local h = vim.api.nvim_win_get_height(win) + dh
    h = math.max(10, math.min(vim.o.lines - 4, h))
    vim.api.nvim_win_set_height(win, h)
  end
  -- keep the float parked high (same bias as the default position in
  -- plugins/editor.lua) so resizing doesn't strand it off-center
  local w, h = vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_height(win)
  vim.api.nvim_win_set_config(win, {
    relative = 'editor',
    row = math.max(0, math.floor((vim.o.lines - h) * 0.28)),
    col = math.max(0, math.floor((vim.o.columns - w) / 2)),
  })
  -- remember the zoom as the new default: toggleterm's persist_size covers
  -- splits only, so floats would otherwise reopen at 80% every time (the
  -- float_opts functions in plugins/editor.lua read this back).
  vim.g.toggleterm_float_size = { width = w, height = h }
end
map({ 'n', 't' }, '<A-,>', function() resize_float(-5, 0) end, { noremap = true, silent = true, desc = 'Float narrower' })
map({ 'n', 't' }, '<A-.>', function() resize_float(5, 0) end, { noremap = true, silent = true, desc = 'Float wider' })
-- Same width keys on the brackets: Alt+[ narrows, Alt+] widens.
map({ 'n', 't' }, '<A-[>', function() resize_float(-5, 0) end, { noremap = true, silent = true, desc = 'Float narrower' })
map({ 'n', 't' }, '<A-]>', function() resize_float(5, 0) end, { noremap = true, silent = true, desc = 'Float wider' })
map({ 'n', 't' }, '<A-->', function() resize_float(0, -2) end, { noremap = true, silent = true, desc = 'Float shorter' })
map({ 'n', 't' }, '<A-=>', function() resize_float(0, 2) end, { noremap = true, silent = true, desc = 'Float taller' })
