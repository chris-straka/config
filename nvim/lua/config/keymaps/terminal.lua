-- Terminal and float maps (one of the keymaps/* modules; load order is set
-- by init.lua in this directory). This file owns the toggleterm slots,
-- terminal cycling, the floating-terminal toggles and exit ramps, and
-- float zoom (see config/float.lua). General editing lives in
-- general.lua; workspace navigation in workspace.lua.
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- (old Alt bank lived here; Alt+N now toggles the current slot's terminal — loop below)
-- Floating terminals, one Ghostty tab = one project so plain global ids are
-- enough: Cmd+N toggles terminal N of THIS tab's nvim (terminals switch
-- most, so they own the easiest key). A dev server on term 2 keeps
-- running in that tab while you work in another Ghostty tab (separate
-- nvim process, fully isolated). Digit 0 means 10. Project tabs moved to
-- Alt+1..0 (Ghostty goto_tab, handled before nvim ever sees them).
-- Cmd+[/] steps prev/next through them with wraparound (see below) for
-- the high digits that are awkward to reach.
for _i = 1, 10 do
  local _n, _d = _i, (_i == 10 and '0' or tostring(_i))
  local _rhs = '<cmd>' .. _n .. 'ToggleTerm direction=float<cr>'
  -- Insert included on both: digits must work while typing, since the
  -- emulators deliver modifiers as Esc/CSI-u sequences. toggleterm's
  -- on_open startinsert lands the opened float in Terminal-Insert no
  -- matter which mode we toggled from.
  map({ 'n', 't', 'i' }, '<D-' .. _d .. '>', _rhs, opts)
  -- Alt+N kept as fallback: Ghostty eats Alt+digits for tabs, but other
  -- terminals (kitty leaves Alt alone) still deliver them to nvim.
  map({ 'n', 't', 'i' }, '<A-' .. _d .. '>', _rhs, opts)
end
-- Terminal cycling (Alt+N jumps direct, these step with wraparound):
-- Cmd+[ previous, Cmd+] next, from code or from inside a float. Ghostty
-- transport lives in shared-keybinds.conf (super+[/]); to rebind later,
-- change those two lines plus these two maps and nothing else.
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
-- Shift+Backspace toggles terminal Insert <-> Normal both ways (Ghostty
-- sends CSI-u 127;2u as <S-BS>, see shared-keybinds.conf; plain
-- Backspace still erases for the shell). Terminal-Normal reports
-- mode() == 'nt', the job (Insert) reports 't'.
map('t', '<S-BS>', function()
  if vim.fn.mode() == 'nt' then
    vim.cmd('startinsert')
  else
    vim.cmd('stopinsert')
  end
end, { noremap = true, silent = true, desc = 'Toggle terminal Insert/Normal' })
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
