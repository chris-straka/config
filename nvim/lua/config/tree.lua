-- Tree open helpers: the :NvimTree* commands hardcode focus=true, so both
-- call the api directly (verified in the plugin's toggle.lua: open, reveal,
-- then `wincmd p` restores focus when focus=false).
-- peek() opens WITHOUT leaving the code (Shift+Cmd+E, <leader>e/h);
-- second press closes (toggle). focus() jumps the cursor INTO the tree
-- (Cmd+E): it never toggles shut — when the tree is already open
-- elsewhere it just moves in (revealing the file when asked), and only
-- closes on a second press while already inside.
local M = {}

local function with_api()
  local ok_lazy, lazy = pcall(require, 'lazy')
  if ok_lazy then pcall(lazy.load, { plugins = { 'nvim-tree.lua' } }) end
  local ok, api = pcall(require, 'nvim-tree.api')
  if not ok then
    vim.notify('nvim-tree not loaded', vim.log.levels.WARN)
    return nil
  end
  return api
end

-- Nudge the statusline after a programmatic cwd change: closing the
-- picker fires no BufEnter and lualine's own timer can lag a beat, so
-- the project widget would sit on the old name. Never force-loads
-- lualine (it is VeryLazy): when it is absent there is nothing stale.
local function refresh_statusline()
  if package.loaded['lualine'] == nil then return end
  local ok, lualine = pcall(require, 'lualine')
  if ok and type(lualine) == 'table' and type(lualine.refresh) == 'function' then
    pcall(lualine.refresh)
  end
end

-- Root the tree (and the tab cwd, so terminals follow) at dir.
---@param dir string absolute directory path
function M.change_root(dir)
  vim.cmd('tcd ' .. vim.fn.fnameescape(dir))
  local api = with_api()
  if api then pcall(api.tree.change_root, dir) end
  refresh_statusline()
end

-- Prompt for a new tree root, defaulting to the tab cwd with dir
-- completion: type `..` to go up one, Tab-complete anywhere else.
function M.change_root_prompt()
  local cwd = vim.fn.getcwd()
  vim.ui.input({ prompt = 'Tree root: ', default = cwd .. '/', completion = 'dir' }, function(input)
    if input == nil or input == '' then return end
    local dir = vim.fn.fnamemodify(vim.fn.expand(input), ':p')
    dir = dir:gsub('/$', '')
    if vim.fn.isdirectory(dir) ~= 1 then
      vim.notify('Not a directory: ' .. input, vim.log.levels.WARN)
      return
    end
    M.change_root(dir)
  end)
end

-- The centerer (no-neck-pain) stays on while the tree is up: it
-- recognizes NvimTree as an integration and subtracts the tree width
-- from the padding instead of fighting it, so the file stays centered
-- in the remaining space with no off/on cycle and no recenter flash.
-- (An earlier revision held the centerer off per open and repaired the
-- focus asynchronously; probed against the installed plugin, entering
-- an open tree is a no-op for the centerer — columns unchanged, no
-- re-init — and open/close self-heals through its own WinEnter /
-- WinClosed scans, so the machinery was pure overhead.)
---@param find boolean reveal the current file in the tree
function M.peek(find)
  local api = with_api()
  if not api then return end
  -- Open or shut, cursor never leaves the code: toggle does both.
  api.tree.toggle({ find_file = find, focus = false })
end

---@param find boolean reveal the current file in the tree
function M.focus(find)
  local api = with_api()
  if not api then return end
  if api.tree.is_visible() then
    if api.tree.is_tree_buf() then
      api.tree.toggle() -- already inside: second press closes
    else
      if find then
        -- find_file only reveals by default; focus:true moves the cursor
        -- in too (without it Cmd+E silently stays in the buffer).
        api.tree.find_file({ focus = true }) -- open elsewhere: reveal file and jump in
      else
        api.tree.focus() -- open elsewhere: just jump in
      end
    end
  else
    api.tree.toggle({ find_file = find, focus = true })
  end
end

-- Post file-open centering (l, Enter, o — see on_attach in
-- plugins/editor.lua): call after api.node.open.edit returns, when the
-- tree is closed and the layout is final. Beside the tree the centerer
-- may have closed its sides for space; without this they pop back a
-- beat later through the async scans — the recenter flash. Re-init
-- synchronously instead, in the same call stack, so no redraw slips
-- between. No-op when the centerer is off or the sides already stand
-- (the wide-screen case needs nothing).
function M.file_opened()
  local ok_state, state = pcall(require, 'no-neck-pain.state')
  if not ok_state or not state.enabled then return end
  if state:is_side_enabled_and_valid('left') and state:is_side_enabled_and_valid('right') then return end
  local ok_main, main = pcall(require, 'no-neck-pain.main')
  if ok_main and type(main.init) == 'function' then pcall(main.init, 'tree:open') end
end

return M
