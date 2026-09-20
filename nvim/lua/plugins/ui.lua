-- UI: colorschemes, statusline, diagnostics list
return {
  -- Alternates to the Catppuccin default below: VeryLazy puts them on
  -- the rtp after startup (no setup runs) so :colorscheme can name
  -- them; bare `lazy = true` with no trigger left them unloadable.
  { 'EdenEast/nightfox.nvim', event = 'VeryLazy' },
  { 'folke/tokyonight.nvim', event = 'VeryLazy' },
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
      -- Yank flash (see YankStatus in config/autocmds.lua): appears briefly
      -- after each yank, hidden otherwise.
      lualine_b = { 'branch', 'diff', 'diagnostics', { function() return vim.g.yank_flash or '' end,
        cond = function() return vim.g.yank_flash ~= nil end } },
      lualine_c = { { function()
        return '󰉋 ' .. vim.fn.fnamemodify(vim.fn.getcwd(), ':t')
      end }, { 'filename', path = 1, fmt = function(s)
        -- Terminal floats name their buffers zsh;#toggleterm#N: show
        -- the slot plus how many terminals exist (`term 2 / 3`,
        -- see config.terminal.label); lone terminals stay `term N`.
        local n = s:match('#toggleterm#(%d+)')
        if n then return require('config.terminal').label(n) end
        -- Deep paths (Java packages) eat the whole bar, and the project
        -- is already shown in the preceding component, so keep parent +
        -- file only (`domain/InvalidIdempotencyKeyException.java`).
        return s:match('[^/]+/[^/]+$') or s
      end } },
      -- `fmt` shortens the filetype label only (`toggleterm` -> `term`);
      -- icon and everything else stay as the stock component renders them.
      -- C++ buffers show their standard instead (`C++23` from the file's
      -- -std= flag or CMAKE_CXX_STANDARD, plain `C++` when unset).
      lualine_x = { 'encoding', 'fileformat', { 'filetype', fmt = function(s)
        if vim.bo.filetype == 'cpp' then
          return require('config.cxx_standard').label()
        end
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
    },
    config = function(_, opts)
      require('no-neck-pain').setup(opts)
      -- Guard the WinEnter/WinClosed -> debounce -> init chain: the
      -- debounced init can land after the tab is torn down (e.g. a tree
      -- toggle from <D-e>), where upstream hard-errors
      -- ("called the internal `init` method on a `nil` tab",
      -- main.lua in the debounce frame). A stale callback should no-op.
      -- Revisit on plugin updates past 0df6659.
      local main = require('no-neck-pain.main')
      local state = require('no-neck-pain.state')
      local orig_init = main.init
      main.init = function(scope)
        if not state:is_active_tab_registered() then return end
        -- Entering the tree must still refresh the padding (the tree
        -- consumes columns, so stale sides squash the file beside it),
        -- but the rebuild must not drag focus out of the tree: snapshot
        -- the window and put it back when init lands elsewhere. Any
        -- other window keeps upstream behavior untouched.
        local ok, ft = pcall(function() return vim.bo[vim.api.nvim_get_current_buf()].filetype end)
        if not (ok and ft == 'NvimTree') then return orig_init(scope) end
        local win = vim.api.nvim_get_current_win()
        local r = orig_init(scope)
        if vim.api.nvim_get_current_win() ~= win and vim.api.nvim_win_is_valid(win) then
          pcall(vim.api.nvim_set_current_win, win)
        end
        return r
      end
    end },
  { 'folke/trouble.nvim', cmd = { 'Trouble' }, opts = {} },
  -- VS Code's Error Lens: diagnostics as inline virtual text at the line.
  -- Replaces the default virtual_text (upstream recommendation).
  { 'rachartier/tiny-inline-diagnostic.nvim', event = 'LspAttach',
    config = function()
      require('tiny-inline-diagnostic').setup()
      vim.diagnostic.config({ virtual_text = false })
    end },
  -- Rendered Markdown (tables, checkboxes, code blocks) in the buffer, so
  -- README tables read without leaving nvim. On by default; the cursor
  -- line drops to raw text while editing. <leader>md toggles.
  -- PDFs stay with image.nvim (ghostscript).
  { 'MeanderingProgrammer/render-markdown.nvim',
    ft = { 'markdown' },
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.nvim' },
    keys = {
      { '<leader>md', '<cmd>RenderMarkdown toggle<cr>', desc = 'Markdown render on/off' },
    },
    opts = {},
  },
}
