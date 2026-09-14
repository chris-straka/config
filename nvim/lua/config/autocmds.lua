local autocmd = vim.api.nvim_create_autocmd

-- no auto-continue of comments on new line
autocmd('BufEnter', { command = 'set formatoptions-=cro' })

-- format on save via conform.nvim (replaces removed vim.lsp.buf.formatting_sync)
autocmd('BufWritePre', {
  group = vim.api.nvim_create_augroup('ConformFormat', { clear = true }),
  callback = function(args)
    require('conform').format { bufnr = args.buf, lsp_fallback = true, timeout_ms = 1000 }
  end,
})

-- highlight yanks (new since old config)
autocmd('TextYankPost', {
  group = vim.api.nvim_create_augroup('YankHighlight', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- One Ghostty tab = one project: every fresh nvim opens the file tree so
-- you can see where you are, but the cursor stays in the empty buffer
-- (peek, no focus). Only when launched without file arguments
-- (the launcher flow — `exec nvim` at home, then Ctrl+R/Cmd+O into the
-- project); `nvim somefile` leaves you in the file. Picking a file closes
-- the tree (quit_on_open), VSCode-explorer style.
autocmd('VimEnter', {
  group = vim.api.nvim_create_augroup('TreeOnStartup', { clear = true }),
  callback = function()
    if vim.fn.argc() == 0 then require('config.tree').peek(false) end
  end,
})
