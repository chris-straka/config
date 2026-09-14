-- Navigation / editing (lightspeed->flash, surround.nvim->nvim-surround, etc.)
return {
  { 'nvim-lua/plenary.nvim', lazy = true },
  {
    'nvim-telescope/telescope.nvim',
    cmd = 'Telescope',
    dependencies = { 'nvim-lua/plenary.nvim', 'nvim-tree/nvim-web-devicons' },
    opts = { defaults = { file_ignore_patterns = { 'node_modules', '.terraform', '.git/' } } },
    config = function(_, opts)
      require('telescope').setup(opts)
      pcall(require('telescope').load_extension, 'projects')
    end,
  },
  {
    'nvim-telescope/telescope-fzf-native.nvim',
    build = 'make',
    cond = function() return vim.fn.executable 'make' == 1 end,
    config = function()
      pcall(require('telescope').load_extension, 'fzf')
    end,
  },
  { 'nvim-telescope/telescope-file-browser.nvim', -- fuzzy file/folder browser (Cmd+O)
    dependencies = { 'nvim-telescope/telescope.nvim', 'nvim-lua/plenary.nvim' },
    config = function()
      pcall(require('telescope').load_extension, 'file_browser')
    end,
  },
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    build = ':TSUpdate',
    event = { 'BufReadPost', 'BufNewFile' },
    config = function()
      local ts = require 'nvim-treesitter'
      ts.setup {}
      ts.install { 'lua', 'vim', 'vimdoc', 'javascript', 'typescript', 'tsx', 'python', 'go', 'rust', 'bash', 'json', 'css', 'html',
        'c', 'cpp', 'cmake', 'java', 'c_sharp', 'terraform', 'yaml', 'dockerfile', 'graphql', 'proto', 'toml', 'solidity', 'typst', 'http' }
      -- Neovim 0.11+ starts treesitter highlight/indent per-buffer; ensure it.
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('TreesitterStart', { clear = true }),
        callback = function(ev)
          pcall(vim.treesitter.start, ev.buf)
        end,
      })
    end,
  },
  { 'folke/which-key.nvim', event = 'VeryLazy', opts = {} },
  { 'folke/flash.nvim', event = 'VeryLazy', opts = {} }, -- replaces ggandor/lightspeed
  { 'windwp/nvim-autopairs', event = 'InsertEnter', opts = {} },
  { 'windwp/nvim-ts-autotag', event = 'InsertEnter', opts = {} },

  { 'JoosepAlviste/nvim-ts-context-commentstring', lazy = true, opts = {} },
  { 'catgoose/nvim-colorizer.lua', event = 'VeryLazy', config = function() require('colorizer').setup() end },
  { 'echasnovski/mini.nvim', lazy = false, config = function() -- eager: ai/comment/surround ready immediately (no starter screen anymore)
    require('mini.ai').setup()
    require('mini.comment').setup() -- same gc/gcc keys as Comment.nvim
    require('mini.surround').setup { -- same ys/ds/cs keys as nvim-surround
      mappings = { add = 'ys', delete = 'ds', replace = 'cs' },
    }
    require('mini.sessions').setup() -- manual snapshots: <leader>Sw / <leader>Sr
  end },
  { 'famiu/bufdelete.nvim', cmd = { 'Bdelete', 'Bwipeout' } },
  -- NOTE: eager on purpose (no `cmd` key, so the setup's `lazy = false`
  -- default applies): the Alt+digit keymaps call `:NToggleTerm` with a
  -- count, and lazy's command stub declares range (not count), so the first
  -- counted toggle mis-parses the count as a line range and dies with E16.
  { 'akinsho/toggleterm.nvim', opts = {
    open_mapping = [[<c-\>]],
    -- Follow mode: every terminal (re)opens in the current directory, so
    -- Ctrl+R to a project first and the numbered terms land there too.
    -- Tradeoff: reopening a shell cds its job; nothing stays pinned.
    autochdir = true,
    -- Always land in Terminal-Insert on open: persist_mode=false stops
    -- toggleterm restoring the last mode, start_in_insert states the intent,
    -- and on_open startinsert! is the belt-and-suspenders guarantee (the
    -- plugin's own documented pattern) so Alt/Cmd+N always lands ready
    -- to type, never in Terminal-Normal.
    start_in_insert = true,
    persist_mode = false,
    on_open = function() vim.cmd('startinsert!') end,
    auto_scroll = false,
    scrollback = 20000,
    direction = 'float',
    float_opts = {
      border = 'curved',
      -- Default 80% of the screen, parked high (easier to read than
      -- bottom-anchored), or the remembered Alt-,/. zoom (see
      -- resize_float in config/keymaps.lua): toggleterm's persist_size
      -- covers splits only, so floats need this to keep their size.
      width = function()
        local s = vim.g.toggleterm_float_size
        local w = (type(s) == 'table' and s.width) or math.floor(vim.o.columns * 0.8)
        return math.max(60, math.min(vim.o.columns - 4, w))
      end,
      height = function()
        local s = vim.g.toggleterm_float_size
        local h = (type(s) == 'table' and s.height) or math.floor(vim.o.lines * 0.8)
        return math.max(10, math.min(vim.o.lines - 4, h))
      end,
      row = function()
        local s = vim.g.toggleterm_float_size
        local h = (type(s) == 'table' and s.height) or math.floor(vim.o.lines * 0.8)
        h = math.max(10, math.min(vim.o.lines - 4, h))
        return math.max(0, math.floor((vim.o.lines - h) * 0.28))
      end,
    },
  } },
  {
    'nvim-tree/nvim-tree.lua',
    cmd = { 'NvimTreeToggle', 'NvimTreeFocus', 'NvimTreeFindFileToggle' },
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {
      update_focused_file = { enable = true },
      -- Indent guides: the tree's structure cue, which matters more here
      -- because every folder shares one glyph (see below).
      renderer = { indent_markers = { enable = true } },
      -- Tree follows the working directory, so it always shows the
      -- current tab's project (one Ghostty tab = one project).
      sync_root_with_cwd = true,
      view = { width = 30 },
      -- VSCode behavior: Enter on a file opens it and closes the tree.
      actions = { open_file = { quit_on_open = true } },
      -- VSCode-explorer keys: h collapses the directory (or jumps to the
      -- parent), l expands it (or opens the file), Enter on a folder
      -- re-roots the tree there (its tab cwd follows) instead of merely
      -- expanding it. j/k still move the cursor.
      on_attach = function(bufnr)
        local api = require('nvim-tree.api')
        api.config.mappings.default_on_attach(bufnr)
        local function opts(desc)
          return { desc = 'nvim-tree: ' .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
        end
        vim.keymap.set('n', 'h', api.node.navigate.parent_close, opts('Collapse'))
        vim.keymap.set('n', 'l', api.node.open.edit, opts('Expand'))
        vim.keymap.set('n', '<CR>', function()
          local node = api.tree.get_node_under_cursor()
          if node and node.type == 'directory' then
            api.tree.change_root_to_node()
          else
            api.node.open.edit()
          end
        end, opts('Open / change directory'))
      end,
    },
  },
  {
    -- Maintained fork of the archived ahmedkhalf/project.nvim. The original
    -- calls deprecated vim.lsp.buf_get_clients() on every file open.
    -- Same 'projects' Telescope extension; setup module is now `project`.
    'DrKJeff16/project.nvim',
    event = 'VeryLazy',
    -- This fork's default markers miss JS/TS projects (no package.json, and
    -- ccez-keeps has no .git), so opening a project file never chdir'd and
    -- terminals kept spawning in $HOME. tbl_deep_extend merges by index, so
    -- the full list is repeated here with JS/TS extras appended.
    opts = {
      patterns = {
        '.git', '.github', '_darcs', '.hg', '.bzr', '.svn',
        'Pipfile', 'pyproject.toml', '.pre-commit-config.yaml',
        '.pre-commit-config.yml', '.csproj', '.sln',
        '.nvim.lua', '.neoconf.json', 'neoconf.json',
        '.stylua.toml', 'stylua.toml',
        'package.json', 'tsconfig.json', 'bun.lock', 'bunfig.toml',
        'go.mod', 'Cargo.toml', 'Makefile',
      },
      -- Per-tab cwd: each tab follows what you open in it, global cwd
      -- stays out of the way (toggleterm reads the tab cwd).
      scope_chdir = 'tab',
    },
    config = function(_, opts)
      require('project').setup(opts)
      pcall(require('telescope').load_extension, 'projects')
    end,
  },
  { 'folke/todo-comments.nvim', event = 'VeryLazy', dependencies = { 'nvim-lua/plenary.nvim' }, opts = {} },
  -- VS Code extension equivalents, loaded only when needed:
  { 'RaafatTurki/hex.nvim', cmd = { 'HexToggle', 'HexDump', 'HexAssemble' }, -- ms-vscode.hexeditor
    config = function() require('hex').setup() end },
  { 'mechatroner/rainbow_csv', ft = 'csv' }, -- mechatroner.rainbow-csv
  -- humao.rest-client. API is Lua + <leader>R keys (no :Kulala command exists).
  { 'mistweaverco/kulala.nvim', ft = { 'http', 'rest' }, opts = { global_keymaps = true } },
  { 'stevearc/overseer.nvim', cmd = { 'OverseerRun', 'OverseerToggle' }, -- formulahendry.code-runner + tasks
    keys = {
      { '<leader>or', '<cmd>OverseerRun<cr>', desc = 'Run task' },
      { '<leader>ot', '<cmd>OverseerToggle<cr>', desc = 'Task list' },
    },
    config = function() require('overseer').setup() end },
  { 'habamax/vim-godot', ft = { 'gd', 'gdshader', 'tscn', 'tres' } }, -- Godot scenes/scripts (hll uses C#, covered by omnisharp)
  -- fluxhouse notebooks: edit .ipynb as Markdown, syncs back on save.
  -- Backend is the `jupytext` CLI (uv tool); keep both or neither works.
  { 'GCBallesteros/jupytext.nvim', ft = 'ipynb', opts = { style = 'markdown' } },
  {
    'ThePrimeagen/harpoon',
    branch = 'harpoon2',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function() require('harpoon').setup() end,
  },
}
