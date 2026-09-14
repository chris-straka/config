-- UI: colorschemes, statusline, diagnostics list
return {
  { 'EdenEast/nightfox.nvim', lazy = false, priority = 1000 },
  { 'folke/tokyonight.nvim', lazy = true },
  -- Matches the Ghostty theme (Catppuccin Mocha): purple/mauve accents
  -- instead of nightfox's flatter look. The colorscheme lives in `config`
  -- (not options.lua): options runs before lazy puts plugins on the rtp,
  -- so a colorscheme command there silently no-ops every start.
  { 'catppuccin/nvim', name = 'catppuccin', lazy = false, priority = 1000,
    -- No theme switch needed for a brighter tree: keep Catppuccin Mocha
    -- and lift just the tree window from mantle to surface0.
    opts = {
      highlight_overrides = {
        mocha = function(mocha)
          return {
            NvimTreeNormal = { bg = mocha.surface0 },
            NvimTreeNormalNC = { bg = mocha.surface0 },
            NvimTreeEndOfBuffer = { bg = mocha.surface0 },
            NvimTreeWinSeparator = { fg = mocha.surface1, bg = mocha.surface0 },
          }
        end,
      },
    },
    config = function(_, opts)
      require('catppuccin').setup(opts)
      vim.cmd.colorscheme('catppuccin-mocha')
    end },
  { 'nvim-lualine/lualine.nvim', event = 'VeryLazy', dependencies = { 'nvim-tree/nvim-web-devicons' }, opts = {
    -- Default sections restated with two additions: the project name
    -- (current directory's basename, e.g. `ccez-keeps`). One Ghostty tab
    -- runs one nvim for one project, so this is the tab's identity —
    -- nvim cannot see Ghostty's own tab index (stock Ghostty exports no
    -- tab env var or queryable socket), so numbered Ghostty tabs in the
    -- statusline are not possible. The second addition covers nvim's own
    -- tabs (`:tabnew`): `Tab n/N`, blank unless several exist, so it
    -- never prints a misleading always-1 number for Ghostty tabs.
    sections = {
      lualine_a = { 'mode' },
      lualine_b = { 'branch', 'diff', 'diagnostics' },
      lualine_c = { 'filename', { function()
        return '󰉋 ' .. vim.fn.fnamemodify(vim.fn.getcwd(), ':t')
      end }, { function()
        if vim.fn.tabpagenr('$') <= 1 then return '' end
        return 'Tab ' .. vim.fn.tabpagenr() .. '/' .. vim.fn.tabpagenr('$')
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
