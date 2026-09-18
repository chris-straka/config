-- Ported from lua/which/*.lua to which-key v3 (.add API).
-- Old .register() calls no longer work.
local ok, wk = pcall(require, 'which-key')
if not ok then return end

wk.add {
  { '<leader><Tab>', '<cmd>e#<cr>', desc = 'Prev buffer' },
  { '<leader>=', '<c-w>=', desc = 'Equal sizes' },
  -- Same peek as Shift+Cmd+E (open + reveal, cursor stays in code);
  -- Cmd+E focuses instead. See config/tree.lua.
  { '<leader>e', function() require('config.tree').peek(true) end, desc = 'Peek tree' },
  { '<leader>q', ':q<cr>', desc = 'Quit' },
  { '<leader>w', ':w!<cr>', desc = 'Write' },
  { '<leader>b', group = 'Buffers' },
  { '<leader>bb', "<cmd>lua require'telescope.builtin'.buffers({ sort_mru = true })<cr>", desc = 'Find buffer' },
  { '<leader>bd', '<cmd>lua MiniBufremove.delete(0, true)<CR>', desc = 'Close buffer' },
  { '<leader>bD', '<cmd>%bd<cr>', desc = 'Close all buffers' },
  { '<leader>L', '<cmd>Lazy<cr>', desc = 'Plugins (load state)' },
  { '<leader>x', group = 'Trouble' },
  { '<leader>xx', '<cmd>Trouble diagnostics toggle<cr>', desc = 'Diagnostics' },
  { '<leader>xs', '<cmd>Trouble symbols toggle<cr>', desc = 'Symbols' },
  { '<leader>t', '<cmd>ToggleTerm direction=float<cr>', desc = 'Terminal' },
  { '<leader>u', group = 'UI' },
  { '<leader>uh', desc = 'Inlay hints on/off' },
  { '<leader>cr', desc = 'Change tree root…' },
  { '<leader>T', group = 'Test' },
  { '<leader>s', group = 'Snip' },
  { '<leader>o', group = 'Tasks' },
  { '<leader>R', group = 'REST' },
  { '<leader>m', group = 'Markdown' },
  { '<leader>d', group = 'Debug' },
  { '<leader>f', group = 'Find' },
  { '<leader>ff', '<cmd>Telescope find_files<cr>', desc = 'Files' },
  { '<leader>fg', '<cmd>Telescope live_grep<cr>', desc = 'Grep' },
  { '<leader>fp', '<cmd>Telescope projects<cr>', desc = 'Projects' },
  { '<leader>g', group = 'Git' },
  { '<leader>gg', '<cmd>Neogit<cr>', desc = 'Neogit' },
  { '<leader>gd', '<cmd>DiffviewOpen<cr>', desc = 'Diffview' },
  { '<leader>gb', '<cmd>GitBlameToggle<cr>', desc = 'Blame' },
  -- LSP lives on gd/gr/gi/K/<leader>rn/<leader>ca (see lsp.lua) — the old
  -- 'm'-prefix duplicates were removed; one family only.
}
