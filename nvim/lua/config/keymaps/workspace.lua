-- Workspace navigation maps (one of the keymaps/* modules; load order is
-- set by init.lua in this directory). This file owns the file tree, the
-- Telescope finders, buffer closing, session snapshots, and the code
-- runner. General editing lives in general.lua; terminals and floats in
-- terminal.lua.
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- tree / terminal / finder (plugin commands must exist at runtime, so plain strings)
-- Alt+E focuses the tree AND reveals the current file, same as Cmd+E
-- below (one code path instead of the stock FindFileToggle command).
map({ 'n', 'v' }, '<A-e>', function() require('config.tree').focus(true) end, opts)
-- Cmd+E focuses the tree AND reveals the current file (VSCode explorer:
-- cursor moves in). Shift+Cmd+E peeks instead (open + reveal, cursor
-- stays in code). Terminals send CSI-u with the super modifier, decoded
-- straight to <D-e> / <D-S-e> (see their configs); Ghostty's default
-- Cmd+E (search selection) is overridden there to send it.
map({ 'n', 'v', 'i' }, '<D-e>', function() require('config.tree').focus(true) end, opts)
map({ 'n', 'v', 'i' }, '<D-S-e>', function() require('config.tree').peek(true) end, opts)
-- Same from inside a toggleterm float (Terminal-Insert): a bare `:cmd`
-- RHS would be typed into the shell job in t mode, so drop to
-- Terminal-Normal first, then call the module like everywhere else.
-- CSI-u super decodes to <D-e> / <D-S-e>, which have no t map above,
-- so both need their own drop-to-Normal first.
map('t', '<D-e>', '<C-\\><C-n><cmd>lua require("config.tree").focus(true)<cr>', opts)
map('t', '<D-S-e>', '<C-\\><C-n><cmd>lua require("config.tree").peek(true)<cr>', opts)
-- Middle-click opens the tree (focused, current file revealed) instead of
-- pasting. Needs `mouse = 'a'` above, or the emulator eats the click.
map({ 'n', 'v', 'i', 't' }, '<MiddleMouse>', function() require('config.tree').focus(true) end,
  { noremap = true, silent = true, desc = 'Open file tree' })
-- Space+h / Space+l step to the window on that side (Diffview panes
-- included). At the left edge with nowhere to go, Space+h focuses the
-- file tree instead (no reveal; Shift+Cmd+E peeks revealed, Cmd+E
-- focuses revealed — see config/tree.lua). At the right edge Space+l
-- is a no-op. See config/window_nav.lua.
map('n', '<leader>h', function() require('config.window_nav').left() end,
  { noremap = true, silent = true, desc = 'Window left / file tree' })
map('n', '<leader>l', function() require('config.window_nav').right() end,
  { noremap = true, silent = true, desc = 'Window right' })
-- Space+j jumps INTO the tree, but only from an empty buffer (fresh nvim
-- with the tree peeked): in a one-line empty buffer `j` has nowhere to go,
-- so it becomes the down-and-out gesture. Elsewhere the key does nothing
-- and stays free for a future motion. Empty is the Cmd+W definition (see
-- config/buffer_close.lua): unnamed, unmodified, all-blank.
map('n', '<leader>j', function()
  if require('config.buffer_close').is_empty_buffer() then require('config.tree').focus(false) end
end, { noremap = true, silent = true, desc = 'Focus tree from empty buffer' })
-- <leader>cr prompts for a new tree root (completion=dir, so Tab
-- completes paths; `..` goes up one, `~`/absolute/relative all work).
-- The tab cwd follows, so terminals land there too.
map('n', '<leader>cr', function() require('config.tree').change_root_prompt() end,
  { noremap = true, silent = true, desc = 'Change tree root…' })
-- Space+g+d toggles a two-pane diff of the current file (see
-- config/gitdiff.lua). Bound here — not in whichkey.lua — so it exists
-- from startup instead of arriving with which-key's deferred load
-- (same split as <leader>uh: real map here, label there).
map('n', '<leader>gd', function() require('config.gitdiff').toggle_diff() end,
  { noremap = true, silent = true, desc = 'Diff (toggle)' })

map('n', '<C-p>', '<cmd>Telescope find_files<cr>', { noremap = true, silent = true, desc = 'Find files' })
map('n', '<D-p>', '<cmd>Telescope find_files<cr>', { noremap = true, silent = true, desc = 'Find files' })
-- Cmd+Shift+F: search text inside files (VSCode find-in-files).
-- find_files matches file NAMES; live_grep matches file CONTENTS.
map('n', '<D-S-f>', '<cmd>Telescope live_grep<cr>', { noremap = true, silent = true, desc = 'Search in files' })
-- <leader>fw: search the project for the word under the cursor (VSCode
-- "find all references" habit). From Markdown or any file without a
-- language server, this is the poor man's gd: pick a match to jump.
map('n', '<leader>fw', function() require('telescope.builtin').grep_string() end,
  { noremap = true, silent = true, desc = 'Search word under cursor' })
-- Ctrl+R: recent projects picker (VSCode Ctrl+R).
-- This takes over Vim's built-in redo on Ctrl+R; redo lives on Cmd+Shift+Z.
map('n', '<C-r>', '<cmd>Telescope projects<cr>', { noremap = true, silent = true, desc = 'Recent projects' })
-- Shift+Cmd+R: LSP rename for the symbol under the cursor (VSCode F2):
-- semantic, cross-file via the language server. Recent files moved to
-- <leader>fr.
map('n', '<D-S-r>', vim.lsp.buf.rename, { noremap = true, silent = true, desc = 'Rename symbol' })
-- <leader>ra: change all occurrences in THIS file only (VSCode Ctrl+F2):
-- lexical, no language server. Prefills :%s with the word under the
-- cursor; type the replacement and hit Enter.
map('n', '<leader>ra', function()
  local word = vim.fn.expand('<cword>')
  if word == '' then return end
  local pat = vim.fn.escape(word, '/\\')
  local keys = ':%s/\\V' .. pat .. '//g' .. vim.api.nvim_replace_termcodes('<Left><Left>', true, false, true)
  vim.api.nvim_feedkeys(keys, 'n', false)
end, { noremap = true, silent = true, desc = 'Change all occurrences in file' })
-- Recent files picker (was Shift+Cmd+R).
map('n', '<leader>fr', '<cmd>Telescope oldfiles<cr>', { noremap = true, silent = true, desc = 'Recent files' })
-- Cmd+O: fuzzy file/folder browser (VSCode Open Folder). Navigate anywhere,
-- open any file and the project root follows automatically. Press Cmd+O
-- again (or Ctrl+Y) once inside the folder you want to land this tab and
-- the tree on it. Recents on Ctrl+R.
map('n', '<D-o>', '<cmd>Telescope file_browser path=%:p:h select_buffer=true hidden=true<cr>',
  { noremap = true, silent = true, desc = 'Browse files…' })

-- Cmd+W closes the current buffer (VSCode editor-close); on an empty
-- buffer it tries :tabclose instead (never a window close). MiniBufremove
-- keeps the window layout, leaving an empty buffer when it was the last
-- one (same engine as <leader>bd, force like it). The Ghostty
-- tab/window survives; Shift+Cmd+W stays native and closes the tab,
-- Ctrl+Shift+Cmd+W the window. See config/buffer_close.lua.
map({ 'n', 'v', 'i', 't' }, '<D-w>', function() require('config.buffer_close').close_buffer_or_tab() end,
  { noremap = true, silent = true, desc = 'Close buffer' })

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
