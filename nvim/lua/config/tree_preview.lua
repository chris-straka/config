-- Hover preview: while the cursor is in the tree, the code window follows
-- it. A file under the cursor shows in that window (its live buffer when
-- already loaded, else a read-only scratch copy with treesitter colors:
-- no :edit, so no LSP attach, swap file or buffer-list entry per hover);
-- a folder shows its entries. Leaving the tree without opening restores
-- the window's own buffer and view; l/Enter/o open for real as before
-- (the open replaces the preview, which wipes itself).
local M = {}

-- Debounce (ms): holding j sweeps many rows; only the one it rests on
-- is read.
M.delay = 60
-- Scratch copies stop here so a huge log or lockfile never stalls j/k.
M.max_bytes = 512 * 1024
M.max_entries = 500

local ns = vim.api.nvim_create_namespace('tree_preview')
local timer = nil
-- Per hover session: the window being borrowed, what it showed before,
-- and the scratch buffer currently in it (nil while showing a real one).
local state = nil

local function is_scratch(buf) return vim.b[buf].tree_preview == true end

-- A window the preview may borrow: a plain file window (or one already
-- showing a preview), never the tree, a float, a terminal, or a
-- no-neck-pain pad.
local function usable(win)
  if win == nil or win == 0 or not vim.api.nvim_win_is_valid(win) then return false end
  if vim.api.nvim_win_get_config(win).relative ~= '' then return false end
  local buf = vim.api.nvim_win_get_buf(win)
  if is_scratch(buf) then return true end
  local ft = vim.bo[buf].filetype
  return vim.bo[buf].buftype == '' and ft ~= 'NvimTree' and ft ~= 'no-neck-pain'
end

-- The window the tree opens files into (nvim-tree's own target), so the
-- preview lands exactly where l/Enter would; falls back to the previous
-- window, then any usable window in the tab.
local function target_win()
  local ok, lib = pcall(require, 'nvim-tree.lib')
  if ok and usable(lib.target_winid) then return lib.target_winid end
  local prev = vim.fn.win_getid(vim.fn.winnr('#'))
  if usable(prev) then return prev end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if usable(win) then return win end
  end
  return nil
end

local function new_scratch(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.b[buf].tree_preview = true
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  return buf
end

-- Colors without setting 'filetype' (which would run FileType autocmds:
-- LSP, linters): treesitter when a parser exists, else legacy syntax.
local function highlight(buf, path)
  local ft = vim.filetype.match({ filename = path, buf = buf })
  if not ft then return end
  local lang = vim.treesitter.language.get_lang(ft) or ft
  if not pcall(vim.treesitter.start, buf, lang) then vim.bo[buf].syntax = ft end
end

local function file_buffer(path)
  local stat = vim.uv.fs_stat(path)
  if not stat then return nil end
  local f = io.open(path, 'rb')
  if not f then return nil end
  local data = f:read(math.min(stat.size, M.max_bytes)) or ''
  f:close()
  local name = vim.fn.fnamemodify(path, ':t')
  if data:sub(1, 8192):find('\0', 1, true) then
    return new_scratch({ '', '  ' .. name, '', '  binary file, ' .. stat.size .. ' bytes' })
  end
  local lines = vim.split(data, '\r?\n')
  if stat.size > M.max_bytes or lines[#lines] == '' then
    lines[#lines] = nil -- the final newline, or a partial cut line
  end
  if stat.size > M.max_bytes then
    table.insert(lines, '')
    table.insert(lines, '… preview stops at ' .. M.max_bytes .. ' of ' .. stat.size .. ' bytes')
  end
  local buf = new_scratch(lines)
  highlight(buf, path)
  return buf
end

-- Folder listing: folders first (trailing /), then files, both by name.
local function dir_buffer(path)
  local dirs, files = {}, {}
  for name, kind in vim.fs.dir(path) do
    if kind == 'directory' then
      table.insert(dirs, name .. '/')
    else
      table.insert(files, name)
    end
  end
  table.sort(dirs)
  table.sort(files)
  local lines = { vim.fn.fnamemodify(path, ':~:.') .. '/', '' }
  local shown = 0
  for _, list in ipairs({ dirs, files }) do
    for _, name in ipairs(list) do
      if shown == M.max_entries then break end
      table.insert(lines, '  ' .. name)
      shown = shown + 1
    end
  end
  local total = #dirs + #files
  if total == 0 then table.insert(lines, '  (empty)') end
  if total > shown then table.insert(lines, '  … ' .. (total - shown) .. ' more') end
  local buf = new_scratch(lines)
  vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, { end_col = #lines[1], hl_group = 'Title' })
  for i = 1, math.min(#dirs, shown) do
    vim.api.nvim_buf_set_extmark(buf, ns, i + 1, 2, { end_col = #lines[i + 2], hl_group = 'Directory' })
  end
  return buf
end

local function show(win, buf)
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_win_set_cursor(win, { 1, 0 })
end

-- Put the borrowed window back the way it was. Runs on leaving the tree
-- (including the moment l/Enter switch to the target, just before their
-- :edit replaces it), so it must stay cheap and never error.
function M.restore()
  if timer then timer:stop() end
  local s = state
  state = nil
  if not s or not vim.api.nvim_win_is_valid(s.win) then return end
  local cur = vim.api.nvim_win_get_buf(s.win)
  if cur == s.buf then return end
  -- Someone else changed the window (not us): leave it alone.
  if not is_scratch(cur) and cur ~= s.shown then return end
  if not vim.api.nvim_buf_is_valid(s.buf) then return end
  pcall(vim.api.nvim_win_set_buf, s.win, s.buf)
  pcall(vim.api.nvim_win_call, s.win, function() vim.fn.winrestview(s.view) end)
end

function M.update()
  if vim.bo.filetype ~= 'NvimTree' then return end
  local ok, api = pcall(require, 'nvim-tree.api')
  if not ok then return end
  local node = api.tree.get_node_under_cursor()
  local path = node and node.name ~= '..' and node.absolute_path or nil
  if state and state.path == path then return end
  local win = state and state.win or target_win()
  if not win or not vim.api.nvim_win_is_valid(win) then return end
  if not state then
    state = {
      win = win,
      buf = vim.api.nvim_win_get_buf(win),
      view = vim.api.nvim_win_call(win, vim.fn.winsaveview),
    }
  end
  state.path = path
  if not path then
    M.restore()
    return
  end
  -- The window's own file, or any loaded buffer: show the real thing
  -- (unsaved edits included); the window's own one with its old view.
  local real = vim.fn.bufnr(path)
  if real == state.buf then
    vim.api.nvim_win_set_buf(win, real)
    vim.api.nvim_win_call(win, function() vim.fn.winrestview(state.view) end)
    state.shown = real
    return
  end
  local buf
  if real ~= -1 and vim.api.nvim_buf_is_loaded(real) and vim.bo[real].buftype == '' then
    buf = real
  elseif node.type == 'directory' then
    buf = dir_buffer(path)
  elseif node.type == 'file' or node.type == 'link' then
    buf = file_buffer(path)
  end
  if not buf then return end
  state.shown = not is_scratch(buf) and buf or nil
  show(win, buf)
end

local function schedule()
  if timer then timer:stop() end
  timer = timer or vim.uv.new_timer()
  timer:start(M.delay, 0, vim.schedule_wrap(function() pcall(M.update) end))
end

-- Wire one tree buffer (called from on_attach in plugins/editor.lua).
---@param bufnr integer the NvimTree buffer
function M.attach(bufnr)
  local group = vim.api.nvim_create_augroup('TreePreview' .. bufnr, { clear = true })
  vim.api.nvim_create_autocmd('CursorMoved', { group = group, buffer = bufnr, callback = schedule })
  vim.api.nvim_create_autocmd('WinLeave', { group = group, buffer = bufnr, callback = function() M.restore() end })
end

return M
