-- LSP + completion + formatting/lint, tuned 2026-09-12 from actual ~/SWE usage:
-- mostly Rust + Go + Python, a little TS/Astro (bun, never deno).
-- nvim-lsp-installer is archived; mason.nvim is its maintained successor.
return {
  { 'williamboman/mason.nvim', cmd = 'Mason', opts = {} },
  {
    'williamboman/mason-lspconfig.nvim',
    dependencies = { 'williamboman/mason.nvim', 'neovim/nvim-lspconfig' },
    opts = {
      -- Full-stack set mapped from the VS Code extension list: clangd (cpptools),
      -- terraformls (hashicorp), helm_ls + yamlls (k8s), dockerls + compose,
      -- taplo (even-better-toml), tinymist (typst resumes in ~/Jobs).
      ensure_installed = {
        'lua_ls', 'ts_ls', 'jsonls', 'cssls', 'tailwindcss',
        'gopls', 'pyright', 'rust_analyzer', 'bashls', 'jdtls', 'omnisharp',
        'clangd', 'terraformls', 'helm_ls', 'yamlls',
        'dockerls', 'docker_compose_language_service', 'taplo', 'tinymist',
      },
    },
  },
  {
    'neovim/nvim-lspconfig',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = { 'saghen/blink.cmp' },
    config = function()
      local caps = require('blink.cmp').get_lsp_capabilities()

      -- Base for every server. Per-server files live in lsp/ (native 0.11+
      -- autoload): lsp/lua_ls.lua, lsp/tailwindcss.lua, lsp/omnisharp.lua.
      vim.lsp.config('*', { capabilities = caps })

      -- Java formats via jdtls itself, so it stays out of the conform
      -- table on purpose.
      vim.lsp.enable({
        'lua_ls', 'ts_ls', 'jsonls', 'cssls', 'tailwindcss',
        'gopls', 'pyright', 'rust_analyzer', 'bashls', 'jdtls', 'omnisharp',
        'clangd', 'terraformls', 'helm_ls', 'yamlls',
        'dockerls', 'docker_compose_language_service', 'taplo', 'tinymist',
      })

      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('UserLspKeys', { clear = true }),
        callback = function(ev)
          local b = { buffer = ev.buf, silent = true }
          vim.keymap.set('n', 'gd', vim.lsp.buf.definition, b)
          vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, b)
          vim.keymap.set('n', 'gr', vim.lsp.buf.references, b)
          vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, b)
          vim.keymap.set('n', 'K', vim.lsp.buf.hover, b)
          vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, b)
          vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, b)
          vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, b)
        end,
      })
    end,
  },
  -- completion (replaces hrsh7th/cmp-* sprawl)
  {
    'saghen/blink.cmp',
    version = '1.*',
    dependencies = { 'rafamadriz/friendly-snippets', 'L3MON4D3/LuaSnip' },
    opts = {
      keymap = { preset = 'super-tab' },
      snippets = { preset = 'luasnip' },
      sources = { default = { 'lsp', 'snippets', 'path', 'buffer' } },
      signature = { enabled = true },
    },
  },
  { 'L3MON4D3/LuaSnip', dependencies = { 'rafamadriz/friendly-snippets' }, config = function()
    require('luasnip.loaders.from_vscode').lazy_load()
  end },
  -- formatting (replaces null-ls). This "formatters_by_ft" table IS the
  -- conform config: filetype -> formatter list, used on save (see autocmds).
  {
    'stevearc/conform.nvim',
    event = 'BufWritePre',
    opts = {
      formatters_by_ft = {
        lua = { 'stylua' },
        python = { 'ruff_format' },
        go = { 'gofumpt', 'gofmt', stop_after_first = true },
        rust = { 'rustfmt' },
        csharp = { 'csharpier' }, -- replaces the csharpier VS Code extension
        bash = { 'shfmt' }, -- replaces foxundermoon's shell-format
        terraform = { 'terraform_fmt' }, -- ships with terraform itself
        javascript = { 'prettierd', 'prettier', stop_after_first = true },
        typescript = { 'prettierd', 'prettier', stop_after_first = true },
      },
    },
  },
  -- linting (replaces null-ls diagnostics)
  {
    'mfussenegger/nvim-lint',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      require('lint').linters_by_ft = {
        javascript = { 'eslint_d' }, typescript = { 'eslint_d' },
        python = { 'ruff' },
      }
      vim.api.nvim_create_autocmd({ 'BufWritePost', 'BufReadPost' }, {
        callback = function() require('lint').try_lint() end,
      })
    end,
  },
  { 'WhoIsSethDaniel/mason-tool-installer.nvim', dependencies = { 'williamboman/mason.nvim' },
    -- NOTE: no Go tools here. Mason drives `go` through mise's shim, which
    -- swallows GOBIN, so every `go install` lands in mise's Go dir instead
    -- of the package dir ("non-existent target" link errors). Go tools
    -- (gopls, gofumpt, delve) are installed with the real Go binary into
    -- ~/go/bin, which is on PATH (see .zshrc).
    opts = { ensure_installed = {
      'stylua', 'prettierd', 'eslint_d', 'csharpier', 'shfmt',
      -- debug adapters (see dap.lua keymaps under <leader>d)
      'codelldb', 'debugpy', 'js-debug-adapter', 'netcoredbg',
      'firefox-debug-adapter',
    } } },
  { 'j-hui/fidget.nvim', event = 'LspAttach', opts = {} },
}
