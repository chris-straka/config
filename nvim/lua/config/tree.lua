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

---@param find boolean reveal the current file in the tree
function M.peek(find)
  local api = with_api()
  if not api then return end
  api.tree.toggle({ find_file = find, focus = false })
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

-- no-neck-pain (centered padding) removes "foreign" windows when it
-- (re)initializes on WinEnter: opening the tree while it is active used
-- to close the tree again instantly, kicking focus back to the buffer.
-- So the not-visible branch below holds it off for this tab while the
-- tree is open and restores it when the tree closes.
local nnp_held_off = {} ---@type table<integer, boolean> tab handle -> held off
local nnp_guard = {} ---@type table<integer, integer> tab handle -> open generation
local nnp_aug = vim.api.nvim_create_augroup('TreeFocusNNP', { clear = false })

local function nnp_active()
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    local ok, ft = pcall(function() return vim.bo[vim.api.nvim_win_get_buf(w)].filetype end)
    if ok and ft == 'no-neck-pain' then return true end
  end
  return false
end

local function nnp_set(enabled)
  if vim.fn.exists(':NoNeckPain') ~= 2 then return end
  if nnp_active() == enabled then return end
  pcall(vim.cmd, 'NoNeckPain')
end

local function hold_nnp_off()
  if not nnp_active() then return end
  nnp_held_off[vim.api.nvim_get_current_tabpage()] = true
  nnp_set(false)
end

local function is_tree_buf()
  local api = with_api()
  return api ~= nil and api.tree.is_tree_buf()
end

local function arm_nnp_restore()
  if not is_tree_buf() then return end
  local tab = vim.api.nvim_get_current_tabpage()
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_create_autocmd('BufWinLeave', {
    group = nnp_aug,
    buffer = buf,
    once = true,
    callback = function()
      -- The user closed the tree: cancel any pending repair pass so it
      -- cannot reopen what was just closed.
      nnp_guard[tab] = (nnp_guard[tab] or 0) + 1
      if nnp_held_off[tab] then
        nnp_held_off[tab] = nil
        -- Run after the close lands: enabling scans the layout and must
        -- not see the dying tree window. Skip if the tree is somehow
        -- back already (double toggle in one tick).
        vim.schedule(function()
          local api = with_api()
          if api and not api.tree.is_visible() then nnp_set(true) end
        end)
      end
    end,
  })
end

-- One repair pass ~a centerer debounce window after opening: if
-- no-neck-pain (re)enabled itself in the meantime — including its late
-- safe-VimEnter enable — it drops the tree, so hold it off again and
-- reopen. Runs once; a user close cancels it via arm_nnp_restore.
local function settle_tree_open(tab, find, gen)
  vim.defer_fn(function()
    if nnp_guard[tab] ~= gen then return end
    if not vim.api.nvim_tabpage_is_valid(tab) then
      nnp_held_off[tab] = nil
      return
    end
    local api = with_api()
    if api == nil then return end
    if nnp_active() then
      nnp_held_off[tab] = true
      nnp_set(false)
      if not api.tree.is_visible() then
        api.tree.toggle({ find_file = find, focus = true })
      elseif not api.tree.is_tree_buf() then
        api.tree.focus()
      end
      arm_nnp_restore()
    end
  end, 400)
end

---@param find boolean reveal the current file in the tree
function M.focus(find)
  local api = with_api()
  if not api then return end
  if api.tree.is_visible() then
    if api.tree.is_tree_buf() then
      api.tree.toggle() -- already inside: second press closes
    elseif find then
      -- find_file only reveals by default; focus:true moves the cursor
      -- in too (without it Cmd+E silently stays in the buffer).
      api.tree.find_file({ focus = true }) -- open elsewhere: reveal file and jump in
    else
      api.tree.focus() -- open elsewhere: just jump in
    end
  else
    hold_nnp_off()
    api.tree.toggle({ find_file = find, focus = true })
    arm_nnp_restore()
    local tab = vim.api.nvim_get_current_tabpage()
    local gen = (nnp_guard[tab] or 0) + 1
    nnp_guard[tab] = gen
    settle_tree_open(tab, find, gen)
  end
end

return M
