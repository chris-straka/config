-- UI: colorschemes, statusline, diagnostics list
return {
  { 'EdenEast/nightfox.nvim', lazy = false, priority = 1000 },
  { 'folke/tokyonight.nvim', lazy = true },
  -- Matches the Ghostty theme (Catppuccin Mocha): purple/mauve accents
  -- instead of nightfox's flatter look. The colorscheme lives in `config`
  -- (not options.lua): options runs before lazy puts plugins on the rtp,
  -- so a colorscheme command there silently no-ops every start.
  { 'catppuccin/nvim', name = 'catppuccin', lazy = false, priority = 1000,
    config = function() vim.cmd.colorscheme('catppuccin-mocha') end },
  { 'nvim-lualine/lualine.nvim', event = 'VeryLazy', dependencies = { 'nvim-tree/nvim-web-devicons' }, opts = {
    -- Default sections restated with one addition: the project name
    -- (current directory's basename, e.g. `ccez-keeps`). One Ghostty tab
    -- runs one nvim for one project, so this is the tab's identity.
    sections = {
      lualine_a = { 'mode' },
      lualine_b = { 'branch', 'diff', 'diagnostics' },
      lualine_c = { 'filename', { function()
        return '󰉋 ' .. vim.fn.fnamemodify(vim.fn.getcwd(), ':t')
      end } },
      -- `fmt` shortens the filetype label only (`toggleterm` -> `term`);
      -- icon and everything else stay as the stock component renders them.
      lualine_x = { 'encoding', 'fileformat', { 'filetype', fmt = function(s)
        return s == 'toggleterm' and 'term' or s
      end } },
      lualine_y = { 'progress' },
      lualine_z = { 'location' },
    },
  } },
  { 'folke/trouble.nvim', cmd = { 'Trouble' }, opts = {} },
  -- VS Code's Error Lens: diagnostics as inline virtual text at the line.
  -- Replaces the default virtual_text (upstream recommendation).
  { 'rachartier/tiny-inline-diagnostic.nvim', event = 'LspAttach',
    config = function()
      require('tiny-inline-diagnostic').setup()
      vim.diagnostic.config({ virtual_text = false })
    end },
}
