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
-- Space+h jumps INTO the tree (no reveal, so it lands wherever the tree
-- already is); Shift+Cmd+E peeks with the current file revealed,
-- Cmd+E focuses it revealed. See config/tree.lua for the mechanism.
map('n', '<leader>h', function() require('config.tree').focus(false) end,
  { noremap = true, silent = true, desc = 'Focus file tree' })
-- <leader>cr prompts for a new tree root (completion=dir, so Tab
-- completes paths; `..` goes up one, `~`/absolute/relative all work).
-- The tab cwd follows, so terminals land there too.
map('n', '<leader>cr', function() require('config.tree').change_root_prompt() end,
  { noremap = true, silent = true, desc = 'Change tree root…' })

map('n', '<C-p>', '<cmd>Telescope find_files<cr>', { noremap = true, silent = true, desc = 'Find files' })
map('n', '<D-p>', '<cmd>Telescope find_files<cr>', { noremap = true, silent = true, desc = 'Find files' })
-- Cmd+Shift+F: search text inside files (VSCode find-in-files).
-- find_files matches file NAMES; live_grep matches file CONTENTS.
map('n', '<D-S-f>', '<cmd>Telescope live_grep<cr>', { noremap = true, silent = true, desc = 'Search in files' })
-- Ctrl+R: recent projects picker (VSCode Ctrl+R).
-- This takes over Vim's built-in redo on Ctrl+R; redo lives on Cmd+Shift+Z.
map('n', '<C-r>', '<cmd>Telescope projects<cr>', { noremap = true, silent = true, desc = 'Recent projects' })
-- Cmd+O: fuzzy file/folder browser (VSCode Open Folder). Navigate anywhere,
-- open any file and the project root follows automatically. Press Cmd+O
-- again (or Ctrl+Y) once inside the folder you want to land this tab and
-- the tree on it. Recents on Ctrl+R.
map('n', '<D-o>', '<cmd>Telescope file_browser path=%:p:h select_buffer=true hidden=true<cr>',
  { noremap = true, silent = true, desc = 'Browse files…' })

-- Cmd+W closes the current buffer (VSCode editor-close), never the tab:
-- MiniBufremove keeps the window layout, leaving an empty buffer when it
-- was the last one (same engine as <leader>bd, force like it). The
-- Ghostty tab/window survives; Shift+Cmd+W stays native and closes
-- the tab, Ctrl+Shift+Cmd+W the window.
map({ 'n', 'v', 'i' }, '<D-w>', '<cmd>lua MiniBufremove.delete(0, true)<cr>', { noremap = true, silent = true, desc = 'Close buffer' })
-- Same from inside a toggleterm float: drop to Terminal-Normal first, like
-- the <D-e> float maps (a bare command RHS would be typed into the shell).
map('t', '<D-w>', '<C-\\><C-n><cmd>lua MiniBufremove.delete(0, true)<cr>', opts)

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
