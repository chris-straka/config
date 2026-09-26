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
  pcall(require, 'config.tree_git_guard')
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
  -- pcall: a slow git backend must not surface as a startup error.
  pcall(api.tree.toggle, { find_file = find, focus = false })
  -- Settle whichever way the toggle went (the TreeClose event fires
  -- mid-teardown, too early to compute from — verified by trace).
  if api.tree.is_visible() then M.tree_opened() else M.tree_closed() end
end

-- Center width follows the tree: full width for plain editing, narrower
-- while the tree is open so both pads survive on a 250-column screen
-- (at full width the plugin's own math closes the right pad). Applied on
-- every transition, enabled or not, so a later <leader>z re-enable picks
-- up the width that matches the visible layout.
local CENTER_FULL = 120
local CENTER_TREE = 100

local function set_center_width(w)
  pcall(function()
    if _G.NoNeckPain ~= nil and _G.NoNeckPain.config ~= nil then
      _G.NoNeckPain.config.width = w
    end
  end)
end

-- Shared settle: refresh the scan (a rebuild on a stale scan paints wrong
-- sizes, and a lone scan consumes the change signal so the async pass
-- never fixes it), rebuild, then put the cursor back in the file when it
-- stranded in a pad. Skips the rebuild unless the scan sees the layout
-- the transition just produced (tree registered on open, gone on close)
-- so a mid-churn snapshot never paints. Skips the focus move when
-- starting in the tree (the init wrapper in plugins/ui.lua owns that
-- case). Only ever leaves a side — never the tree, a float, or a
-- terminal — and only lands on a real file window. No-op when the
-- centerer is off. Everything guarded.
---@param scope string 'tree:open' | 'tree:close'
local function settle(scope)
  set_center_width(scope == 'tree:open' and CENTER_TREE or CENTER_FULL)
  local ok_state, state = pcall(require, 'no-neck-pain.state')
  if not ok_state or not state.enabled then return end
  pcall(function()
    local ok_ft, ft = pcall(function() return vim.bo[vim.api.nvim_get_current_buf()].filetype end)
    local in_tree = ok_ft and ft == 'NvimTree'
    state:scan_layout(scope)
    local ok_int, integrations = pcall(function() return state:get_integrations() end)
    local tree = ok_int and integrations ~= nil and integrations.NvimTree or nil
    local tree_id = tree ~= nil and tree.id or nil
    local tree_seen = tree_id ~= nil and vim.api.nvim_win_is_valid(tree_id)
    -- Open expects the tree registered, close expects it gone; anything
    -- else is mid-churn — leave it to the async scans.
    if (scope == 'tree:open') ~= tree_seen then return end
    local ok_main, main = pcall(require, 'no-neck-pain.main')
    if ok_main and type(main.init) == 'function' then pcall(main.init, scope) end
    if in_tree then return end
    if not (state:is_side_the_active_win('left') or state:is_side_the_active_win('right')) then return end
    local curr = state:get_side_id('curr')
    if curr == nil or not vim.api.nvim_win_is_valid(curr) then return end
    local cbuf = vim.api.nvim_win_get_buf(curr)
    if vim.bo[cbuf].buftype ~= '' or vim.bo[cbuf].filetype == 'NvimTree' then return end
    vim.api.nvim_set_current_win(curr)
  end)
end

---@param find boolean reveal the current file in the tree
function M.focus(find)
  local api = with_api()
  if not api then return end
  if api.tree.is_visible() then
    if api.tree.is_tree_buf() then
      api.tree.toggle() -- already inside: second press closes
      -- Teardown is complete here (unlike the TreeClose event, which
      -- fires mid-teardown): settle synchronously.
      M.tree_closed()
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
  if api.tree.is_visible() then M.tree_opened() end
end

-- Settle the centerer after the tree opens, once the window stands.
function M.tree_opened()
  settle('tree:open')
end

-- Settle the centerer after the tree closes, while the layout is final.
-- Called directly after teardown completes (toggle-shut, peek-shut, post
-- file-open).
function M.tree_closed()
  settle('tree:close')
end

-- Post file-open (l, Enter, o, and Space on non-images — see
-- on_attach in plugins/editor.lua): the tree closes inside
-- api.node.open.edit, so settle once it returns and the layout is
-- final. Space on an image previews instead (tree stays open, no
-- settle needed).
function M.file_opened()
  M.tree_closed()
end

return M
