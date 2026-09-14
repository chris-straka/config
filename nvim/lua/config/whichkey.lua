-- Ported from lua/which/*.lua to which-key v3 (.add API).
-- Old .register() calls no longer work.
local ok, wk = pcall(require, 'which-key')
if not ok then return end

wk.add {
  { '<leader><Tab>', '<cmd>e#<cr>', desc = 'Prev buffer' },
  { '<leader>=', '<c-w>=', desc = 'Equal sizes' },
  { '<leader>e', '<cmd>NvimTreeToggle<cr>', desc = 'Toggle tree' },
  { '<leader>q', ':q<cr>', desc = 'Quit' },
  { '<leader>w', ':w!<cr>', desc = 'Write' },
  { '<leader>b', group = 'Buffers' },
  { '<leader>bb', "<cmd>lua require'telescope.builtin'.buffers({ sort_mru = true })<cr>", desc = 'Find buffer' },
  { '<leader>bd', '<cmd>Bdelete!<CR>', desc = 'Close buffer' },
  { '<leader>bD', '<cmd>%bd<cr>', desc = 'Close all buffers' },
  { '<leader>L', '<cmd>Lazy<cr>', desc = 'Plugins (load state)' },
  { '<leader>Q', group = 'Misc' },
  { '<leader>Qs', '<cmd>Trouble symbols toggle<cr>', desc = 'Symbols' },
  { '<leader>Qd', '<cmd>Trouble diagnostics toggle<cr>', desc = 'Diagnostics' },
  { '<leader>t', '<cmd>ToggleTerm direction=float<cr>', desc = 'Terminal' },
  { '<leader>T', group = 'Test' },
  { '<leader>s', group = 'Snip' },
  { '<leader>o', group = 'Tasks' },
  { '<leader>R', group = 'REST' },
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
