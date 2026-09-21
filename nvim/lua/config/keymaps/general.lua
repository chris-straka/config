-- General editing, motion, and UI maps (one of the keymaps/* modules; load
-- order is set by init.lua in this directory). This file owns everyday code
-- editing, window navigation, undo/clipboard, folding, formatting, link
-- opening, and the mouse-hover docs. Workspace navigation (tree, finders,
-- sessions, runner) lives in workspace.lua; terminals and floats in
-- terminal.lua.
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

-- Alt+Right intentionally left unmapped in terminal modes: Ghostty sends it
-- as Esc+f, which the shell reads as word-forward (VSCode behavior). It used
-- to toggle the float here, which is why Option+Right "closed" terminals.
-- In normal buffers the same keys would stall on find-char, so hop instead
-- (mirrors the free Esc+b word-back on Alt+Left).
map('n', '<A-f>', 'w', { noremap = true, silent = true, desc = 'Word forward' })

-- Mouse hover docs (VSCode tooltip): rest the mouse on a word in normal
-- mode and its LSP docs pop up anchored at the mouse. Needs mousemoveevent
-- (see options.lua). K is the keyboard equivalent.
map('n', '<MouseMove>', function() require('config.mouse_hover').on_mouse_move() end,
  { noremap = true, silent = true, desc = 'Hover docs under mouse' })

-- gx opens the thing under the cursor: a Markdown file link like
-- [label](/abs/path:12) (or a bare path) opens in a new buffer at that
-- line; a URL opens in the browser. Replaces netrw's gx, which only
-- handled URLs.
map('n', 'gx', function() require('config.openlink').open() end,
  { noremap = true, silent = true, desc = 'Open link under cursor' })

-- VSCode-style folding: Cmd+Opt+[ folds, Cmd+Opt+] unfolds (folds come from
-- the treesitter grammar, see options.lua). `za` still toggles, `zM`/`zR`
-- close/open everything.
map({ 'n', 'v' }, '<D-M-[>', 'zc', { noremap = true, silent = true, desc = 'Fold' })
map({ 'n', 'v' }, '<D-M-]>', 'zo', { noremap = true, silent = true, desc = 'Unfold' })

-- Shift+Alt+F: format the buffer (VSCode format-document). From a visual
-- selection it formats just that — conform reads the range itself. Same
-- engine as format-on-save (conform table, LSP fallback, 1s timeout).
map({ 'n', 'v' }, '<A-S-f>', function()
  local ok_lazy, lazy = pcall(require, 'lazy')
  if ok_lazy then pcall(lazy.load, { plugins = { 'conform.nvim' } }) end
  require('conform').format { lsp_fallback = true, timeout_ms = 1000 }
end, { noremap = true, silent = true, desc = 'Format code' })

-- <leader>ym: copy the last message (warning, error, LSP notice) to the
-- system clipboard. The :messages history can't be yanked with visual
-- mode, so this skips the scratch-buffer dance entirely.
map('n', '<leader>ym', function()
  local out = vim.api.nvim_exec2('messages', { output = true }).output or ''
  local lines = vim.tbl_filter(function(l) return l ~= '' end, vim.split(out, '\n'))
  local last = lines[#lines] or ''
  vim.fn.setreg('+', last)
  vim.notify('Copied: ' .. last)
end, { noremap = true, silent = true, desc = 'Copy last message' })

-- <leader>yp: show the current file's full path and copy it to the
-- system clipboard. For moments like K-hover showing a definition's
-- absolute path while the statusline only shows parent + file.
map('n', '<leader>yp', function()
  local path = vim.api.nvim_buf_get_name(0)
  if path == '' then
    vim.notify('no file path — buffer is unnamed', vim.log.levels.WARN)
    return
  end
  vim.fn.setreg('+', path)
  vim.notify('Copied: ' .. path)
end, { noremap = true, silent = true, desc = 'Copy full file path' })

-- Cmd+Shift+Z: redo (VSCode redo). u undoes, this re-applies.
map('n', '<D-S-z>', '<cmd>redo<cr>', { noremap = true, silent = true, desc = 'Redo' })

-- Ctrl+Z: disabled. Vim's default suspends Neovim (SIGTSTP), but the
-- Spotlight/Ghostty launcher runs `exec nvim` with no shell underneath,
-- so suspend strands the window with nothing to `fg` back to. Terminal
-- mode is left alone on purpose so Ctrl+Z still reaches shell jobs
-- inside :terminal floats.
map({ 'n', 'v', 'i' }, '<C-z>', '<Nop>', { noremap = true, silent = true, desc = 'Disable suspend' })
-- Cmd+Z: undo (VSCode undo). Kept out of terminal mode on purpose so it
-- still reaches the shell job. Visual uses <Esc>u because bare
-- u there means lowercase, not undo.
map('n', '<D-z>', 'u', { noremap = true, silent = true, desc = 'Undo' })
map('i', '<D-z>', '<C-o>u', { noremap = true, silent = true, desc = 'Undo' })
map('v', '<D-z>', '<Esc>u', { noremap = true, silent = true, desc = 'Undo' })

-- Inlay hints (VSCode inferred types / parameter names): on by default
-- wherever the server supports them (see lsp.lua), this toggles them for
-- the current buffer.
map('n', '<leader>uh', function()
  local buf = vim.api.nvim_get_current_buf()
  vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = buf }), { bufnr = buf })
end, { noremap = true, silent = true, desc = 'Inlay hints on/off' })

-- Cmd+C copies the visual selection (VSCode habit). Plain `y` already
-- reaches the system clipboard (clipboard=unnamedplus); this binds the
-- familiar key. Yank is not a modification, so it works in read-only
-- buffers too (terminal floats, tree, prompts) — edits there fail with
-- E21 'modifiable is off', which is the error you get when a keystroke
-- tries to change a buffer Neovim marked read-only. Needs the matching
-- Ghostty bind (super+c -> <D-c>); without it the emulator eats Cmd+C.
map('v', '<D-c>', '"+y', { noremap = true, silent = true, desc = 'Copy selection' })
