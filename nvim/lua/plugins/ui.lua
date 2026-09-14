-- UI: colorschemes, statusline, diagnostics list
return {
  -- Alternates to the Catppuccin default below: lazy so neither costs
  -- startup time unless :colorscheme names it.
  { 'EdenEast/nightfox.nvim', lazy = true },
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
    -- Default sections restated with one addition: the project name
    -- (current directory's basename, e.g. `ccez-keeps`). One Ghostty tab
    -- runs one nvim for one project, so this is the tab's identity.
    sections = {
      lualine_a = { 'mode' },
      lualine_b = { 'branch', 'diff', 'diagnostics' },
      lualine_c = { { function()
        return '󰉋 ' .. vim.fn.fnamemodify(vim.fn.getcwd(), ':t')
      end }, { 'filename', path = 1, fmt = function(s)
        -- Terminal floats name their buffers zsh;#toggleterm#N: the
        -- only part worth statusline space is the terminal number.
        local n = s:match('#toggleterm#(%d+)')
        if n then return 'term ' .. n end
        return s
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
  -- Center the buffer with side padding so the file tree stops
  -- moonlighting as a spacer: on by default ('safe' waits out the
  -- startup tree), <leader>z toggles (the plugin's own suggested key),
  -- text width 120.
  { 'shortcuts/no-neck-pain.nvim',
    -- Eager: default-on centering lives in the plugin's own VimEnter
    -- autocmd, which only exists once the plugin is loaded (same
    -- reason mini.nvim over in editor.lua is eager).
    lazy = false,
    cmd = { 'NoNeckPain', 'NoNeckPainWidthUp', 'NoNeckPainWidthDown' },
    keys = {
      { '<leader>z', '<cmd>NoNeckPain<cr>', desc = 'Center buffer' },
    },
    opts = {
      width = 120,
      autocmds = { enableOnVimEnter = 'safe', enableOnTabEnter = true },
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
