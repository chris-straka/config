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

-- VSCode-style autosave: write shortly after normal-mode edits settle
-- (TextChanged honors updatetime), when leaving insert mode, when the
-- buffer is left, and when the emulator loses focus. `update` only
-- writes modified named buffers, so this is a no-op everywhere else —
-- and it runs the same conform format-on-save as a manual :w.
-- Special buffers (tree, terminals, prompts) and readonly files are
-- skipped. Deliberately not TextChangedI: that fires per keystroke,
-- which would format mid-word while typing.
autocmd({ 'InsertLeave', 'TextChanged', 'BufLeave', 'FocusLost' }, {
  group = vim.api.nvim_create_augroup('Autosave', { clear = true }),
  callback = function(args)
    local buf = args.buf
    if not vim.api.nvim_buf_is_valid(buf) then return end
    if vim.api.nvim_buf_get_name(buf) == '' then return end
    if not vim.bo[buf].modifiable or vim.bo[buf].readonly then return end
    if vim.bo[buf].buftype ~= '' then return end
    if not vim.bo[buf].modified then return end
    pcall(vim.api.nvim_buf_call, buf, function() vim.cmd('silent! update') end)
  end,
})
