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

-- no-neck-pain (centered padding) re-initializes asynchronously
-- (debounced WinEnter/WinClosed scans, late safe-VimEnter enable), and an
-- init landing after the tree opens recreates the padding and reroutes
-- focus to the code window: the tree stays open but the cursor is kicked
-- back out. So every open holds the centerer off for the tab while the
-- tree is up and restores it when the tree closes.
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

-- Synchronous hold-off: the :NoNeckPain command debounces, leaving a
-- window where a centerer init still lands after the tree opens. The
-- internal disable runs now (same precedent as the main.init guard in
-- ui.lua) and unregisters the tab, so WinEnter scans stay deaf; falls
-- back to the command when the internals move. Always called with the
-- cursor in the code buffer: disable parks focus on `curr`, which is a
-- no-op there.
local function nnp_hold_off_now()
  local ok_main, main = pcall(require, 'no-neck-pain.main')
  if ok_main and type(main) == 'table' and type(main.disable) == 'function' then
    pcall(main.disable, 'tree:hold')
  else
    nnp_set(false)
  end
end

local function hold_nnp_off()
  if not nnp_active() then return end
  nnp_held_off[vim.api.nvim_get_current_tabpage()] = true
  nnp_hold_off_now()
end

-- Tree buffer regardless of focus (the cursor may be in the code).
local function tree_bufnr()
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(w)
    local ok, ft = pcall(function() return vim.bo[buf].filetype end)
    if ok and ft == 'NvimTree' then return buf end
  end
  return nil
end

-- Watch the tree buffer leaving a window: a genuine close cancels any
-- pending repair and brings the centerer back (after the close lands,
-- so enabling never sees the dying tree window). When the centerer is
-- up at that moment it dropped the tree mid-cycle, so the repair loop
-- stays alive to reopen it.
local function arm_nnp_restore(tab)
  local buf = tree_bufnr()
  if buf == nil then return end
  vim.api.nvim_create_autocmd('BufWinLeave', {
    group = nnp_aug,
    buffer = buf,
    once = true,
    callback = function()
      if nnp_active() then return end
      nnp_guard[tab] = (nnp_guard[tab] or 0) + 1
      if nnp_held_off[tab] then
        nnp_held_off[tab] = nil
        vim.schedule(function()
          local api = with_api()
          if api and not api.tree.is_visible() then nnp_set(true) end
        end)
      end
    end,
  })
end

-- Bounded repair passes after opening (~1.5s, then quiet): one pass
-- cannot cover every centerer/init interleaving, so each pass
-- re-asserts the intended end state while a disturbance is visible.
-- Centerer back up -> hold off again; tree dropped -> reopen; focus
-- intent with the cursor parked elsewhere by the disturbance -> move
-- back in. A cursor the user moved themselves (nothing disturbed) is
-- left alone, and a user close cancels via the close-watch.
local settle_gaps = { 200, 250, 450, 600 }
local function settle_tree_open(tab, find, want_focus, gen, pass)
  local gap = settle_gaps[pass or 1]
  if gap == nil then return end
  vim.defer_fn(function()
    if nnp_guard[tab] ~= gen then return end
    if not vim.api.nvim_tabpage_is_valid(tab) then
      nnp_held_off[tab] = nil
      return
    end
    local api = with_api()
    if api == nil then return end
    local disturbed = false
    if nnp_active() then
      nnp_held_off[tab] = true
      nnp_hold_off_now()
      disturbed = true
    end
    if not api.tree.is_visible() then
      -- disturbed covers was-active (the hold-off above already took the
      -- sides down synchronously); still-active covers a re-init racing
      -- this pass. Either way the centerer dropped the tree: reopen.
      if disturbed or nnp_active() then
        api.tree.toggle({ find_file = find, focus = want_focus })
        arm_nnp_restore(tab)
      else
        if nnp_held_off[tab] then
          nnp_held_off[tab] = nil
          nnp_set(true)
        end
        return
      end
    elseif want_focus and disturbed and not api.tree.is_tree_buf() then
      api.tree.focus()
    end
    settle_tree_open(tab, find, want_focus, gen, (pass or 1) + 1)
  end, gap)
end

-- Entry points sit after the helpers: both bump the guard table, and a
-- function only sees locals declared above it (otherwise the name falls
-- through to a nil global and the call errors).
---@param find boolean reveal the current file in the tree
function M.peek(find)
  local api = with_api()
  if not api then return end
  local tab = vim.api.nvim_get_current_tabpage()
  -- A second press while open closes: cancel any pending repair first
  -- so it cannot reopen what was just closed.
  nnp_guard[tab] = (nnp_guard[tab] or 0) + 1
  if api.tree.is_visible() then
    api.tree.toggle({ find_file = find, focus = false })
    -- Shutting: the close-watch armed at open restores the centerer.
  else
    hold_nnp_off()
    api.tree.toggle({ find_file = find, focus = false })
    arm_nnp_restore(tab)
    settle_tree_open(tab, find, false, nnp_guard[tab], 1)
  end
end

---@param find boolean reveal the current file in the tree
function M.focus(find)
  local api = with_api()
  if not api then return end
  local tab = vim.api.nvim_get_current_tabpage()
  -- Cancel any pending repair: a second press while inside closes, and
  -- the close-watch restores the centerer.
  local gen = (nnp_guard[tab] or 0) + 1
  nnp_guard[tab] = gen
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
      -- Jumping fires WinEnter too: same steal race, same repair.
      settle_tree_open(tab, find, true, gen, 1)
    end
  else
    hold_nnp_off()
    api.tree.toggle({ find_file = find, focus = true })
    arm_nnp_restore(tab)
    settle_tree_open(tab, find, true, gen, 1)
  end
end

return M
