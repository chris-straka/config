-- Terminal and float maps (one of the keymaps/* modules; load order is set
-- by init.lua in this directory). This file owns the toggleterm slots,
-- terminal cycling, the floating-terminal toggles and exit ramps, and
-- float zoom (see config/float.lua). General editing lives in
-- general.lua; workspace navigation in workspace.lua.
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- (Retired: Cmd+digits / Alt+digits used to jump to terminal slots by
-- position. Positional jumps proved confusing — a digit past the last
-- terminal landed on a different shell than the number named — so digits
-- are unbound in both emulators and no digit maps live here. Terminals
-- open on Cmd+T and step on Cmd+[/] only.)
-- New floating terminal, one Ghostty tab = one project: Cmd+T mints a
-- fresh float in THIS tab's nvim (see new() in config/terminal.lua —
-- always creates, never toggles). A dev server keeps running in that
-- tab while you work in another Ghostty tab (separate nvim process,
-- fully isolated). Ghostty's default Cmd+T (new tab) moves to
-- Shift+Cmd+T; the Cmd+T press itself reaches nvim as CSI-u super
-- (see shared-keybinds.conf). A Lua function RHS, so it runs in every
-- mode — including inside a float — with no drop-to-Normal, and
-- toggleterm's on_open startinsert lands the new float in
-- Terminal-Insert no matter which mode we created it from.
map({ 'n', 'v', 'i', 't' }, '<D-t>', function() require('config.terminal').new() end,
  { noremap = true, silent = true, desc = 'New terminal' })
-- Terminal cycling (Cmd+[ previous, Cmd+] next, with wraparound):
-- from code or from inside a float. Ghostty transport lives in
-- shared-keybinds.conf (super+[/]); to rebind later, change those two
-- lines plus these two maps and nothing else.
map({ 'n', 'v', 'i' }, '<D-[>', function() require('config.terminal').cycle(-1) end,
  { noremap = true, silent = true, desc = 'Previous terminal' })
map({ 'n', 'v', 'i' }, '<D-]>', function() require('config.terminal').cycle(1) end,
  { noremap = true, silent = true, desc = 'Next terminal' })
-- Same from inside a toggleterm float: drop to Terminal-Normal first, like
-- the <D-e> float maps (a bare command RHS would be typed into the shell).
map('t', '<D-[>', '<C-\\><C-n><cmd>lua require("config.terminal").cycle(-1)<cr>', opts)
map('t', '<D-]>', '<C-\\><C-n><cmd>lua require("config.terminal").cycle(1)<cr>', opts)

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
-- Exit with `|` (above), return with `i` — both stock Vim. (Retired: a
-- Shift+Backspace Insert<->Normal toggle lived here, but Backspace is the
-- Mac Delete key and the toggle fired on a habit keystroke. Ghostty still
-- sends CSI-u 127;2u as <S-BS>; it now passes through to the shell.)
-- Exit the focused terminal (see config/terminal.lua): types `exit` +
-- Enter into its shell, so the shell ends and the float goes away;
-- reopen with Alt+N for a fresh shell. Alt+X is a bare Alt key, so it
-- binds in normal, terminal, and insert modes with no timeout cost —
-- unlike a <leader> mapping, which would make every Space typed into
-- the shell wait timeoutlen for a follow-up key. (From Terminal-Normal,
-- `Space t R` is gone too: use Alt+X straight from Terminal-Insert.)
-- (Retired 2026-09-14: <leader>tR did the same thing from normal mode,
-- but sat one Shift away from <leader>Tr "run nearest test" — a shell
-- up for the killing with a single typo. Alt+X covers every mode.)
map({ 'n', 't', 'i' }, '<A-x>', function() require('config.terminal').exit_focused() end,
  { noremap = true, silent = true, desc = 'Exit focused terminal' })

-- Float zoom (see config/float.lua): Alt-,/. and Alt+[/ width,
-- Alt--/-= height. No-op on non-floats.
local resize = function(dw, dh) require('config.float').resize(dw, dh) end
map({ 'n', 't' }, '<A-,>', function() resize(-5, 0) end, { noremap = true, silent = true, desc = 'Float narrower' })
map({ 'n', 't' }, '<A-.>', function() resize(5, 0) end, { noremap = true, silent = true, desc = 'Float wider' })
map({ 'n', 't' }, '<A-[>', function() resize(-5, 0) end, { noremap = true, silent = true, desc = 'Float narrower' })
map({ 'n', 't' }, '<A-]>', function() resize(5, 0) end, { noremap = true, silent = true, desc = 'Float wider' })
map({ 'n', 't' }, '<A-->', function() resize(0, -2) end, { noremap = true, silent = true, desc = 'Float shorter' })
map({ 'n', 't' }, '<A-=>', function() resize(0, 2) end, { noremap = true, silent = true, desc = 'Float taller' })
