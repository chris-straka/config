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
  pcall(require('lazy').load, { plugins = { 'nvim-tree.lua' } })
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

---@param find boolean reveal the current file in the tree
function M.focus(find)
  local api = with_api()
  if not api then return end
  if api.tree.is_visible() then
    if api.tree.is_tree_buf() then
      api.tree.toggle() -- already inside: second press closes
    elseif find then
      api.tree.find_file() -- open elsewhere: reveal file and jump in
    else
      api.tree.focus() -- open elsewhere: just jump in
    end
  else
    api.tree.toggle({ find_file = find, focus = true })
  end
end

return M
