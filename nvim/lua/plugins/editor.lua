-- Navigation / editing (lightspeed->flash, surround.nvim->nvim-surround, etc.)
return {
  { 'nvim-lua/plenary.nvim', lazy = true },
  {
    'nvim-telescope/telescope.nvim',
    cmd = 'Telescope',
    dependencies = { 'nvim-lua/plenary.nvim', 'nvim-tree/nvim-web-devicons' },
    opts = function()
      return {
        defaults = {
          file_ignore_patterns = { 'node_modules', '.terraform', '.git/' },
          -- Java packages nest so deep that full paths truncate to identical
          -- prefixes; show those filename-first, leave other languages alone.
          path_display = function(_, path)
            if path:sub(-5) ~= '.java' then return path end
            return string.format(
              '%s  %s',
              vim.fn.fnamemodify(path, ':t'),
              vim.fn.fnamemodify(path, ':h')
            )
          end,
        },
        extensions = {
          file_browser = { mappings = require('config.telescope_land').mappings },
          -- Picker thumbnails via chafa (brew install chafa): `:Telescope
          -- media_files` previews images as block art. Enter on a file
          -- copies its relative path (the extension's own behavior).
          media_files = {
            filetypes = { 'png', 'jpg', 'jpeg', 'gif', 'webp', 'avif', 'bmp', 'ico', 'svg', 'pdf' },
          },
        },
      }
    end,
    config = function(_, opts)
      require('telescope').setup(opts)
      pcall(require('telescope').load_extension, 'projects')
      pcall(require('telescope').load_extension, 'media_files')
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
  { 'nvim-telescope/telescope-media-files.nvim', -- image thumbnails in `:Telescope media_files` (needs chafa)
    dependencies = { 'nvim-telescope/telescope.nvim' },
  },
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    build = ':TSUpdate',
    event = { 'BufReadPost', 'BufNewFile' },
    config = function()
      local ts = require 'nvim-treesitter'
      ts.setup {}
      -- Parsers self-heal: install only languages with no compiled parser
      -- on the runtime path, so a healthy startup never shells out to git
      -- (an unconditional install errored in repos with no `origin`
      -- remote). New languages still arrive on their own; force an update
      -- with :TSUpdate.
      -- (markdown + markdown_inline stay installed: image.nvim finds
      -- inline images via those parsers.)
      local langs = { 'lua', 'vim', 'vimdoc', 'javascript', 'typescript', 'tsx', 'svelte', 'python', 'go', 'rust', 'bash', 'json', 'css', 'html',
        'c', 'cpp', 'cmake', 'java', 'c_sharp', 'terraform', 'yaml', 'dockerfile', 'graphql', 'proto', 'toml', 'solidity', 'typst', 'http',
        'markdown', 'markdown_inline' }
      local missing = vim.tbl_filter(function(l)
        return #vim.api.nvim_get_runtime_file('parser/' .. l .. '.so', true) == 0
      end, langs)
      if #missing > 0 then ts.install(missing) end
      -- Neovim 0.11+ starts treesitter highlight/indent per-buffer; ensure it.
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('TreesitterStart', { clear = true }),
        callback = function(ev)
          pcall(vim.treesitter.start, ev.buf)
        end,
      })
    end,
  },
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    opts = {
      -- Bare `v` enters charwise visual with no defer (upstream only defers
      -- V/<C-V>), and preset popups use delay 0, so the visual help covered
      -- the selection almost instantly. Normal and operator-pending stay
      -- snappy; visual/select wait a beat so selecting never flashes help.
      delay = function(ctx)
        if ctx.mode == 'n' or ctx.mode == 'o' then
          return ctx.plugin and 0 or 200
        end
        return 1000
      end,
    },
  },
  {
    -- replaces ggandor/lightspeed. f/t already label their matches with
    -- zero config (char mode); these two add the anywhere-jump and the
    -- syntax-node jump. Modes are n/x only on purpose: operator-pending
    -- is left alone so ys/ds/cs (surround) keep working — flash's
    -- remote-yank style `d<label>` is the price, and it is not worth it.
    -- Costs: normal/visual s (use cl/c instead), normal S (use cc).
    -- Visual S (surround-add) is untouched.
    'folke/flash.nvim',
    event = 'VeryLazy',
    keys = {
      { 's', function() require('flash').jump() end, mode = { 'n', 'x' }, desc = 'Flash jump' },
      { 'S', function() require('flash').treesitter() end, mode = 'n', desc = 'Flash treesitter' },
    },
    opts = {},
  },
  { 'windwp/nvim-ts-autotag', event = 'InsertEnter', opts = {} },

  { 'catgoose/nvim-colorizer.lua', event = 'VeryLazy', config = function() require('colorizer').setup() end },
  { 'echasnovski/mini.nvim', lazy = false, config = function() -- eager: ai/comment/surround ready immediately (no starter screen anymore)
    require('mini.ai').setup()
    require('mini.comment').setup() -- same gc/gcc keys as Comment.nvim
    require('config.surround').setup() -- ys/ds/cs, visual add on S (see module)
    require('mini.sessions').setup() -- manual snapshots: <leader>Sw / <leader>Sr
    require('mini.icons').setup()
    -- Impersonate devicons: every plugin that asks nvim-web-devicons for
    -- a glyph (nvim-tree, lualine, Telescope…) gets mini.icons' set
    -- instead, with zero changes on their side.
    require('mini.icons').mock_nvim_web_devicons()
    require('mini.pairs').setup() -- auto-closing brackets/quotes
    require('mini.bufremove').setup() -- buffer delete that keeps windows
  end },
  -- NOTE: eager on purpose (no `cmd` key, so the setup's `lazy = false`
  -- default applies): the Cmd+T / Cmd+digit Lua paths run `:NToggleTerm`
  -- with a count, and lazy's command stub declares range (not count), so
  -- the first counted toggle mis-parses the count as a line range and
  -- dies with E16.
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
    -- to type, never in Terminal-Normal — unless the float was left
    -- scrolled up, in which case scroll memory (see on_open/on_close in
    -- config/terminal.lua) restores the view in Terminal-Normal instead.
    start_in_insert = true,
    persist_mode = false,
    on_open = function(term) require('config.terminal').on_open(term) end,
    on_close = function(term) require('config.terminal').on_close(term) end,
    auto_scroll = false,
    scrollback = 20000,
    direction = 'float',
    float_opts = {
      border = 'curved',
      -- Default 80% of the screen minus two Alt+[ narrow steps (5 cols
      -- each), parked high (easier to read than bottom-anchored), or the
      -- remembered Alt-,/. zoom (see resize() in config/float.lua):
      -- toggleterm's persist_size covers splits
      -- only, so floats need this to keep their size.
      width = function()
        local s = vim.g.toggleterm_float_size
        local w = (type(s) == 'table' and s.width) or (math.floor(vim.o.columns * 0.8) - 10)
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
      renderer = {
        indent_markers = { enable = true },
        -- VSCode behavior: single-child folders (dev/straka/ledger) show as
        -- one compact row instead of deep Java-package nesting.
        group_empty = true,
      },
      -- Tree follows the working directory, so it always shows the
      -- current tab's project (one Ghostty tab = one project).
      sync_root_with_cwd = true,
      -- Opens at the default width (TreeWidthByFiletype takes Java tabs
      -- to 50 on BufEnter); opening wider first snaps narrower a beat
      -- later as the pads follow.
      view = { width = 40 },
      -- nvim-tree hides gitignored nodes by default, and the Jobs repo
      -- gitignores its applications/ folder (privacy): exempt it so the
      -- folder is always visible. Everything else ignored stays hidden.
      -- Dotfiles start hidden so the launcher view opens clean; press H
      -- in the tree to reveal them (stock toggle, see default_on_attach).
      filters = { dotfiles = true, exclude = { 'applications' } },
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
        -- File opens recenter synchronously (see file_opened in
        -- config/tree.lua): on screens where the sides stood beside the
        -- tree, the open lands final and this no-ops; where they had
        -- closed for space, it rebuilds them before any redraw.
        local function open_file_centered()
          api.node.open.edit()
          require('config.tree').file_opened()
        end
        -- PDFs open in Zathura (vim keys, TOC, search): image.nvim
        -- rasterizes a single static page, which breaks multi-page docs.
        -- Images image.nvim hijacks (png/jpg/gif/webp/…) open in a
        -- buffer and render there; svg/tif/tiff still go to the OS
        -- viewer since no buffer can render them. 3D models open in
        -- f3d (.blend in Blender): buffers cannot render meshes.
        -- Audio opens in the sfx_player popup (mpv backend) instead of
        -- a binary buffer; like the other external opens, the cursor
        -- stays in the tree (buffer opens quit_on_open instead).
        local function open_file_or_external(node)
          if node and node.type == 'file' and node.absolute_path then
            local path = node.absolute_path
            if path:lower():match('%.pdf$') then
              require('config.pdf').open(path)
              return
            end
            local image = require('config.image')
            if image.handles(path) and not image.in_buffer(path) then
              image.open(path)
              return
            end
            if require('config.model3d').handles(path) then
              require('config.model3d').open(path)
              return
            end
            if require('config.audio').handles(path) then
              require('config.audio').open(path)
              return
            end
          end
          open_file_centered()
        end
        -- l and o: folders expand (never re-root); files open and jump
        -- in, except PDFs/models/audio/unrenderable images which open
        -- externally while the cursor stays in the tree.
        local function expand_or_open()
          open_file_or_external(api.tree.get_node_under_cursor())
        end
        -- Space matches l/o, except renderable images preview instead:
        -- api.node.open.preview shows the image in the last window and
        -- refocuses the tree, so j/k + Space browses a folder of images
        -- without reopening the tree each time (Enter still fully opens).
        local function expand_preview_or_open()
          local node = api.tree.get_node_under_cursor()
          if node and node.type == 'file' and node.absolute_path then
            if require('config.image').in_buffer(node.absolute_path) then
              api.node.open.preview()
              return
            end
          end
          open_file_or_external(node)
        end
        vim.keymap.set('n', 'l', expand_or_open, opts('Expand'))
        vim.keymap.set('n', '<Space>', expand_preview_or_open, opts('Expand'))
        vim.keymap.set('n', 'o', expand_or_open, opts('Open'))
        -- Cmd+Delete (Backspace) trashes the node under the cursor,
        -- mirroring Finder (needs the `trash` CLI; prompts to confirm).
        -- Transport: Ghostty/kitty send CSI-u super (see shared-keybinds).
        vim.keymap.set({ 'n', 'x' }, '<D-BS>', api.fs.trash, opts('Trash'))
        vim.keymap.set('n', 'n', api.fs.create, opts('Create file'))
        vim.keymap.set('n', 'N', function()
          local node = api.tree.get_node_under_cursor()
          local base
          if node and node.type == 'file' then
            base = vim.fn.fnamemodify(node.absolute_path, ':h')
          elseif node and node.type == 'directory' and node.absolute_path then
            base = node.absolute_path
          else
            base = vim.fn.getcwd()
          end
          vim.ui.input({ prompt = 'Create folder: ', default = base .. '/', completion = 'dir' }, function(input)
            if input == nil or input == '' then return end
            local dir = vim.fn.expand(input):gsub('/$', '')
            if vim.fn.isdirectory(dir) == 1 then
              vim.notify('Already exists: ' .. dir, vim.log.levels.WARN)
              return
            end
            vim.fn.mkdir(dir, 'p')
            api.tree.reload()
          end)
        end, opts('Create folder'))
        local function open_or_root()
          local node = api.tree.get_node_under_cursor()
          if node and node.type == 'directory' then
            api.tree.change_root_to_node()
          else
            open_file_or_external(node)
          end
        end
        vim.keymap.set('n', '<CR>', open_or_root, opts('Open / change directory'))
        -- (Space shadows the global leader here, but it is buffer-local +
        -- nowait, so no leader delay inside the tree or anywhere else.)
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
    -- Quick file pinning: <leader>a pins the current file, <C-e> shows the
    -- pin list, <leader>1..4 jumps to pins. All four bindings were free
    -- (verified 2026-09-14: no <leader>a / <C-e> / <C-h> / <leader>[1234]
    -- anywhere in lua/). <C-e> takes over Vim's scroll-down in normal
    -- mode only; insert-mode <C-e> still inserts the char below.
    'ThePrimeagen/harpoon',
    branch = 'harpoon2',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function() require('harpoon').setup() end,
    keys = {
      { '<leader>a', function() require('harpoon'):list():add() end, desc = 'Pin file (harpoon)' },
      { '<C-e>', function() require('harpoon').ui:toggle_quick_menu(require('harpoon'):list()) end, desc = 'Pin list' },
      { '<leader>1', function() require('harpoon'):list():select(1) end, desc = 'Pin 1' },
      { '<leader>2', function() require('harpoon'):list():select(2) end, desc = 'Pin 2' },
      { '<leader>3', function() require('harpoon'):list():select(3) end, desc = 'Pin 3' },
      { '<leader>4', function() require('harpoon'):list():select(4) end, desc = 'Pin 4' },
    },
  },
}
