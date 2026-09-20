local autocmd = vim.api.nvim_create_autocmd

-- Comments never auto-wrap (c) and o/O never continues them, but Enter keeps writing the
-- comment: `r` inserts the ` * ` leader on <CR> in insert mode (the javadoc habit).
autocmd('BufEnter', { command = 'set formatoptions-=c formatoptions-=o formatoptions+=r' })

-- Markdown reads soft-wrapped: long prose/table rows wrap on screen
-- instead of trailing off past the right edge.
autocmd('FileType', {
  group = vim.api.nvim_create_augroup('MarkdownWrap', { clear = true }),
  pattern = 'markdown',
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
  end,
})

-- Pick up files changed on disk (e.g. agent edits): VSCode-style auto-reload.
autocmd({ 'FocusGained', 'BufEnter', 'CursorHold' }, {
  group = vim.api.nvim_create_augroup('AutoReload', { clear = true }),
  command = 'checktime',
})

-- format on save via conform.nvim (replaces removed vim.lsp.buf.formatting_sync)
autocmd('BufWritePre', {
  group = vim.api.nvim_create_augroup('ConformFormat', { clear = true }),
  callback = function(args)
    require('conform').format { bufnr = args.buf, lsp_fallback = true, timeout_ms = 1000 }
  end,
})

-- Yank indicator in the statusline instead of a text highlight: record what
-- was yanked; the lualine component in plugins/ui.lua shows it briefly.
local yank_seq = 0
autocmd('TextYankPost', {
  group = vim.api.nvim_create_augroup('YankStatus', { clear = true }),
  callback = function()
    yank_seq = yank_seq + 1
    local cur = yank_seq
    local n = #vim.v.event.regcontents
    vim.g.yank_flash = '󰆏 ' .. n .. (n == 1 and ' line' or ' lines')
    -- Never force-loads lualine (it is VeryLazy): when it is absent there
    -- is nothing to refresh (same guard as TerminalCountRefresh below).
    if package.loaded['lualine'] ~= nil then pcall(require('lualine').refresh) end
    vim.defer_fn(function()
      if cur ~= yank_seq then return end
      vim.g.yank_flash = nil
      if package.loaded['lualine'] ~= nil then pcall(require('lualine').refresh) end
    end, 1200)
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
    if vim.fn.argc() == 0 then
      -- Deferred past startup: the tree opens on the next main-loop tick,
      -- so a slow git backend (or any tree error) can never abort VimEnter.
      vim.schedule(function()
        local ok, err = pcall(function() require('config.tree').peek(false) end)
        if not ok then vim.notify('tree on startup: ' .. tostring(err), vim.log.levels.WARN) end
      end)
    end
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

-- The cursor stays centered through the end-of-file tail too. scrolloff
-- centers everywhere it can, but the docs are explicit that it gives up
-- at the start/end of the file (`:h scrolloff`), docking the last lines
-- at the window bottom — while a one-shot `zz` is allowed past EOF,
-- showing blank rows below. Correcting after the dock stumbles (scroll
-- then jump back every press), so inside the tail the window-local
-- scrolloff goes to 0 — motions stop auto-scrolling entirely — and every
-- move recenter once with the native fold-aware `zz`. Typing keeps
-- native follow instead: entering insert restores the scrolloff so new
-- lines scroll into view, leaving insert hands the tail back over (a
-- `:normal` recenter would yank insert mode out from under typing).
-- Outside the tail the local value follows the global again. Plain file
-- buffers only: terminals (scrollback above), floats, the tree, and
-- image renders keep their own views. `zz` never moves the cursor, so
-- the move handlers cannot retrigger.
local function center_tail_skip()
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].buftype ~= '' then return true end
  local ft = vim.bo[buf].filetype
  if ft == 'NvimTree' or ft == 'toggleterm' or ft == 'image_nvim' then return true end
  if vim.fn.win_gettype(vim.api.nvim_get_current_win()) ~= '' then return true end
  return false
end

local function center_tail_update()
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  local height = vim.api.nvim_win_get_height(win)
  local half = math.floor(height / 2)
  local cur = vim.api.nvim_win_get_cursor(win)[1]
  -- Window is driven only from normal/visual: recenter commands would
  -- yank insert/replace mode out from under typing.
  local normalish = vim.fn.mode():find('^[iR]') == nil
  if vim.api.nvim_buf_line_count(buf) - cur < half then
    if normalish then
      if vim.opt_local.scrolloff:get() ~= 0 then vim.opt_local.scrolloff = 0 end
      -- Even heights have no single middle row (`zz` picks one side),
      -- so only correct real drift, not a 1-row straddle.
      if math.abs(vim.fn.winline() - (half + 1)) > 1 then vim.cmd('normal! zz') end
    end
  else
    -- vim.opt.scrolloff:get() reads the *effective* value (local wins),
    -- so compare against the true global and drop the local with the
    -- documented `setlocal scrolloff<` form (`:h scrolloff`). Recenter on
    -- the transition press itself: restoring alone leaves one lag frame
    -- for the next motion to jump.
    local global = vim.api.nvim_get_option_value('scrolloff', { scope = 'global' })
    if vim.opt_local.scrolloff:get() ~= global then
      vim.cmd('setlocal scrolloff<')
      if normalish then vim.cmd('normal! zz') end
    end
  end
end

autocmd({ 'CursorMoved', 'BufEnter' }, {
  group = vim.api.nvim_create_augroup('CenterCursorTail', { clear = true }),
  callback = function()
    if center_tail_skip() then return end
    center_tail_update()
  end,
})
autocmd({ 'InsertEnter', 'InsertLeave' }, {
  group = 'CenterCursorTail',
  callback = function(args)
    if center_tail_skip() then return end
    if args.event == 'InsertLeave' then
      center_tail_update()
    else
      local global = vim.api.nvim_get_option_value('scrolloff', { scope = 'global' })
      if vim.opt_local.scrolloff:get() ~= global then vim.cmd('setlocal scrolloff<') end
    end
  end,
})

-- Doc floats (LSP hover, diagnostics, signature help): a second K focuses
-- the hover float on purpose so long docs scroll and yank. That float is
-- markdown with no LSP attached, so a further K falls back to
-- keywordprg=man — on the ```java fence tag it opens man://java(1) in a
-- split. Inside markdown floats K/q/Esc dismiss instead. Only floating
-- markdown: real markdown files, terminals, and pickers keep their keys.
-- Both events: the float opens before its filetype is set (hover) or the
-- filetype is set before it opens, depending on the caller.
local function pin_float_keys(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  if vim.bo[buf].filetype ~= 'markdown' then return end
  local floating = false
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    local ok, cfg = pcall(vim.api.nvim_win_get_config, win)
    if ok and cfg.relative ~= '' then floating = true break end
  end
  if not floating then return end
  local b = { buffer = buf, noremap = true, silent = true, desc = 'Dismiss docs' }
  vim.keymap.set('n', 'K', '<cmd>close<cr>', b)
  vim.keymap.set('n', 'q', '<cmd>close<cr>', b)
  vim.keymap.set('n', '<Esc>', '<cmd>close<cr>', b)
end
local float_keys = vim.api.nvim_create_augroup('FloatKeys', { clear = true })
autocmd('FileType', {
  group = float_keys,
  pattern = 'markdown',
  callback = function(args) pin_float_keys(args.buf) end,
})
autocmd('BufWinEnter', {
  group = float_keys,
  callback = function(args) pin_float_keys(args.buf) end,
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
    -- Re-evaluate the titlestring (folder – file – N terms) even when
    -- focus never leaves the file buffer. Self-assignment forces the
    -- update without toggling 'title' (no titlebar flicker).
    pcall(vim.cmd, 'let &titlestring = &titlestring')
    if package.loaded['lualine'] == nil then return end
    local ok, lualine = pcall(require, 'lualine')
    if ok and type(lualine) == 'table' and type(lualine.refresh) == 'function' then
      pcall(lualine.refresh)
    end
  end,
})

-- Tree width follows the tab: Java packages nest deep, so a tab showing Java
-- gets a 60-column tree, everything else keeps 40. Scans the tab's windows
-- (one tab = one project), so entering the tree itself keeps the width too.
autocmd('BufEnter', {
  group = vim.api.nvim_create_augroup('TreeWidthByFiletype', { clear = true }),
  callback = function()
    local ok, api = pcall(require, 'nvim-tree.api')
    if not ok or not api.tree.is_visible() then return end
    local width = 40
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].filetype == 'java' then
        width = 60
        break
      end
    end
    vim.cmd('NvimTreeResize ' .. width)
  end,
})
