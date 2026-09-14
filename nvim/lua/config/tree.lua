-- Tree open helpers: the :NvimTree* commands hardcode focus=true, so both
-- call the api directly (verified in the plugin's toggle.lua: open, reveal,
-- then `wincmd p` restores focus when focus=false). Second press closes.
-- peek() opens WITHOUT leaving the code (Shift+Cmd+E, <leader>e/h);
-- focus() opens AND moves the cursor in (Cmd+E, Alt+E) for when you want in.
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
  api.tree.toggle({ find_file = find, focus = true })
end

return M
