-- Telescope file_browser "land here": pressing Cmd+O again (or Ctrl+Y)
-- lands this tab on the highlighted folder when it sits inside the
-- browsed one (pick-and-land without entering first), else on the
-- browsed folder itself — right after descending, selection rests on
-- the `..` parent row, and trusting it would escape the folder being
-- searched. Closes the picker; the tree follows the tab cwd. Ctrl+Y is
-- the same action for terminals where Cmd never arrives. Enter
-- (select_and_land) opens the file AND lands tab + tree on its parent
-- dir; on directories Enter just descends (land explicitly once you're
-- where you want).
local M = {}

-- Trailing-slash-insensitive strict containment: true when dir sits
-- inside base (both absolute), false for ties, parents, and siblings.
---@param dir string|nil candidate landing target
---@param base string|nil browsed folder
---@return boolean
local function strictly_inside(dir, base)
  if dir == nil or base == nil or dir == base then return false end
  local function slash(p) return p:sub(-1) == '/' and p or (p .. '/') end
  local b, d = slash(base), slash(dir)
  return #d > #b and d:sub(1, #b) == b
end

-- Resolve a highlighted entry to a path plus whether it is a
-- directory: plenary Path objects (method calls, pcall-guarded) or
-- plain string paths (`value`/`path` keys). One place owns the dual
-- shape so land_here and select_and_land cannot drift apart. Returns
-- path, is_dir; nil path when nothing is highlighted or the entry
-- carries no usable path.
---@param entry table|nil telescope entry
---@return string?, boolean
local function entry_info(entry)
  if entry == nil then return nil, false end
  if entry.Path ~= nil then
    local ok_abs, abs = pcall(function() return entry.Path:absolute() end)
    if not ok_abs or type(abs) ~= 'string' then return nil, false end
    local ok_dir, is_dir = pcall(function() return entry.Path:is_dir() end)
    if ok_dir and is_dir then return abs, true end
    if vim.fn.isdirectory(abs) == 1 then return abs, true end
    return abs, false
  end
  local path = entry.value or entry.path
  if type(path) ~= 'string' then return nil, false end
  if vim.fn.isdirectory(path) == 1 then return path, true end
  return path, false
end

-- Resolve a highlighted entry to the directory landing should consider:
-- a directory itself, or a file's parent. Returns nil when nothing is
-- highlighted or the entry carries no usable path.
---@param entry table|nil telescope entry
---@return string|nil
function M.entry_dir(entry)
  local path, is_dir = entry_info(entry)
  if path == nil then return nil end
  if is_dir then return path end
  return vim.fn.fnamemodify(path, ':h')
end

---@param prompt_bufnr number telescope prompt buffer
function M.land_here(prompt_bufnr)
  local action_state = require 'telescope.actions.state'
  local actions = require 'telescope.actions'
  local picker = action_state.get_current_picker(prompt_bufnr)
  local finder = picker.finder or {}
  local browsed = finder.path or picker.cwd or vim.fn.getcwd()
  if finder.files == false then browsed = finder.cwd or browsed end
  local dir = browsed
  local target = M.entry_dir(action_state.get_selected_entry())
  if strictly_inside(target, browsed) then dir = target end
  actions.close(prompt_bufnr)
  -- Tab cwd matches project.nvim scope_chdir='tab'. One place owns the
  -- move (tree.change_root also nudges the tree and the statusline).
  require('config.tree').change_root(dir)
end

-- Enter on a file: default-open it, then land this tab AND the tree on
-- the file's parent dir (same tab-cwd + tree move as land_here). Enter on
-- a directory keeps the stock behavior (descend inside the picker, no
-- re-root — land with Cmd+O / Ctrl+Y once you're where you want).
---@param prompt_bufnr number telescope prompt buffer
function M.select_and_land(prompt_bufnr)
  local action_state = require 'telescope.actions.state'
  local actions = require 'telescope.actions'
  local path, is_dir = entry_info(action_state.get_selected_entry())
  local dir = nil
  if path ~= nil and not is_dir then dir = vim.fn.fnamemodify(path, ':h') end
  actions.select_default(prompt_bufnr)
  if dir ~= nil then require('config.tree').change_root(dir) end
end

M.mappings = {
  i = { ['<CR>'] = M.select_and_land, ['<D-o>'] = M.land_here, ['<C-y>'] = M.land_here },
  n = { ['<CR>'] = M.select_and_land, ['<D-o>'] = M.land_here, ['<C-y>'] = M.land_here },
}

return M
