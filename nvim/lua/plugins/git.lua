-- Git (gitlinker fork: ruifm original is archived)
return {
  {
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      -- Hunk keys attach per buffer, so they exist only inside git repos.
      -- gp previews the hunk, gr restores it (unstage + discard), gs stages
      -- it; visual mode acts on the selection instead of the whole hunk.
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns
        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
        end
        map('n', '<leader>gp', gs.preview_hunk, 'Preview hunk')
        map({ 'n', 'v' }, '<leader>gr', function()
          if vim.fn.mode():find('^[vV]') ~= nil then
            gs.reset_hunk({ vim.fn.line('.'), vim.fn.line('v') })
          else
            gs.reset_hunk()
          end
        end, 'Reset hunk')
        map({ 'n', 'v' }, '<leader>gs', function()
          if vim.fn.mode():find('^[vV]') ~= nil then
            gs.stage_hunk({ vim.fn.line('.'), vim.fn.line('v') })
          else
            gs.stage_hunk()
          end
        end, 'Stage hunk')
      end,
    },
  },
  { 'NeogitOrg/neogit', cmd = 'Neogit', dependencies = { 'nvim-lua/plenary.nvim' }, opts = {} },
  { 'sindrets/diffview.nvim', cmd = { 'DiffviewOpen', 'DiffviewFileHistory' }, opts = {} },
  {
    'linrongbin16/gitlinker.nvim',
    event = 'VeryLazy',
    -- gy copies a permanent GitHub link for the line/selection (commit
    -- SHA + line range included). Lazy loads the plugin on first press.
    keys = { { '<leader>gy', '<cmd>GitLink<cr>', mode = { 'n', 'v' }, desc = 'Copy GitHub link' } },
    config = function() require('gitlinker').setup() end,
  },
  { 'f-person/git-blame.nvim', cmd = { 'GitBlameToggle' }, init = function() vim.g.gitblame_enabled = 0 end },
}
