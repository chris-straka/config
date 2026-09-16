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

-- Terminal scrollback stays put: the global scrolloff=999 keeps the cursor
-- centered, so any cursor nudge in a terminal (click back into the float
-- after Cmd-Tabbing away, a keypress on return) recenters the window and a
-- scrolled-up view is lost completely instead of shifting a line or two.
-- Terminals keep scrolloff=0 so history you scrolled to stays on screen;
-- files keep the centered cursor (pinned by the smoke test below).
autocmd('TermOpen', {
  group = vim.api.nvim_create_augroup('TerminalScrolloff', { clear = true }),
  callback = function() vim.opt_local.scrolloff = 0 end,
})

-- Terminal count in the statusline/title (`term 2 / 3`): creating or
-- exiting a terminal fires no BufEnter on the remaining floats, so the
-- tab count would sit stale without a nudge. Never force-loads
-- lualine (it is VeryLazy): when it is absent there is nothing stale.
autocmd({ 'TermOpen', 'TermClose', 'BufDelete', 'BufWipeout' }, {
  group = vim.api.nvim_create_augroup('TerminalCountRefresh', { clear = true }),
  callback = function(args)
    if args.event == 'BufDelete' or args.event == 'BufWipeout' then
      local ok, bt = pcall(function() return vim.bo[args.buf].buftype end)
      if not ok or bt ~= 'terminal' then return end
    end
    if package.loaded['lualine'] == nil then return end
    local ok, lualine = pcall(require, 'lualine')
    if ok and type(lualine) == 'table' and type(lualine.refresh) == 'function' then
      pcall(lualine.refresh)
    end
  end,
})
