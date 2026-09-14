-- Git (gitlinker fork: ruifm original is archived)
return {
  { 'lewis6991/gitsigns.nvim', event = { 'BufReadPre', 'BufNewFile' }, opts = {} },
  { 'NeogitOrg/neogit', cmd = 'Neogit', dependencies = { 'nvim-lua/plenary.nvim' }, opts = {} },
  { 'sindrets/diffview.nvim', cmd = { 'DiffviewOpen', 'DiffviewFileHistory' }, opts = {} },
  { 'linrongbin16/gitlinker.nvim', event = 'VeryLazy', config = function() require('gitlinker').setup() end },
  { 'f-person/git-blame.nvim', cmd = { 'GitBlameToggle' }, init = function() vim.g.gitblame_enabled = 0 end },
}
