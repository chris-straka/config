-- LSP + completion + formatting/lint, tuned 2026-09-12 from actual ~/SWE usage:
-- mostly Rust + Go + Python, a little TS/Astro (bun, never deno).
-- nvim-lsp-installer is archived; mason.nvim is its maintained successor.
--
-- One list owns every server (mason-lspconfig accepts lspconfig names in
-- ensure_installed, so both sites below take these strings): add a server
-- here once instead of in two places.
local servers = {
  'lua_ls', 'ts_ls', 'jsonls', 'cssls', 'tailwindcss',
  'gopls', 'pyright', 'rust_analyzer', 'bashls', 'jdtls', 'omnisharp',
  'clangd', 'terraformls', 'helm_ls', 'yamlls',
  'dockerls', 'docker_compose_language_service', 'taplo', 'tinymist',
}
return {
  { 'williamboman/mason.nvim', cmd = 'Mason', opts = {} },
  {
    'williamboman/mason-lspconfig.nvim',
    dependencies = { 'williamboman/mason.nvim', 'neovim/nvim-lspconfig' },
    opts = {
      -- Full-stack set mapped from the VS Code extension list: clangd (cpptools),
      -- terraformls (hashicorp), helm_ls + yamlls (k8s), dockerls + compose,
      -- taplo (even-better-toml), tinymist (typst resumes in ~/Jobs).
      ensure_installed = servers,
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

      vim.lsp.enable(servers)

      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('UserLspKeys', { clear = true }),
        callback = function(ev)
          local b = { buffer = ev.buf, silent = true }
          vim.keymap.set('n', 'gd', vim.lsp.buf.definition, b)
          vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, b)
          vim.keymap.set('n', 'gr', vim.lsp.buf.references, b)
          vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, b)
          -- Cap the hover/signature floats (without max_width,
          -- open_floating_preview() wraps at the current window width,
          -- so docs span the whole screen on a wide monitor). The cap
          -- lives on M.max_width in lua/config/mouse_hover.lua — same
          -- tooltip via mouse, one value for both.
          vim.keymap.set('n', 'K', function()
            vim.lsp.buf.hover({ max_width = require('config.mouse_hover').max_width })
          end, b)
          vim.keymap.set('n', '<C-k>', function()
            vim.lsp.buf.signature_help({ max_width = require('config.mouse_hover').max_width })
          end, b)
          vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, b)
          vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, b)

          local client = vim.lsp.get_client_by_id(ev.data.client_id)
          -- VSCode reference highlighting: resting the cursor highlights
          -- every use of the symbol under it; moving clears it again.
          if client and client:supports_method('textDocument/documentHighlight', ev.buf) then
            local g = vim.api.nvim_create_augroup('UserLspHighlight', { clear = false })
            vim.api.nvim_clear_autocmds({ group = g, buffer = ev.buf })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              group = g,
              buffer = ev.buf,
              callback = function() vim.lsp.buf.document_highlight() end,
            })
            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              group = g,
              buffer = ev.buf,
              callback = function() vim.lsp.buf.clear_references() end,
            })
          end
          -- VSCode shows inlay hints (inferred types, parameter names) by
          -- default; <leader>uh toggles them per buffer.
          if client and client:supports_method('textDocument/inlayHint', ev.buf) then
            vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
          end
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
        -- Java: google-java-format to match the Ledger repo's Spotless pin
        -- (googleJavaFormat 1.28.0). Name uses hyphens: that is conform's
        -- canonical formatter name, and underscores do NOT resolve (conform
        -- then silently runs zero formatters and lsp_fallback hands Java to
        -- jdtls instead). With this set, conform handles Java and the
        -- lsp_fallback in the Shift+Alt+F map / format-on-save stays as
        -- backup only. jdtls formatting is NOT used when this resolves.
        java = { 'google-java-format' },
        csharp = { 'csharpier' }, -- replaces the csharpier VS Code extension
        bash = { 'shfmt' }, -- replaces foxundermoon's shell-format
        terraform = { 'terraform_fmt' }, -- ships with terraform itself
        javascript = { 'prettierd', 'prettier', stop_after_first = true },
        typescript = { 'prettierd', 'prettier', stop_after_first = true },
        svelte = { 'prettierd', 'prettier', stop_after_first = true },
        markdown = { 'prettierd', 'prettier', stop_after_first = true },
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
        group = vim.api.nvim_create_augroup('NvimLint', { clear = true }),
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
      'google-java-format',
      -- debug adapters (see dap.lua keymaps under <leader>d)
      'codelldb', 'debugpy', 'js-debug-adapter', 'netcoredbg',
      'firefox-debug-adapter',
    } } },
  { 'j-hui/fidget.nvim', event = 'LspAttach', opts = {} },
}
