-- Compact fold indicator (wired as `foldtext` in options.lua): the stock
-- foldtext pads `+-- N lines: ...` with dots across the whole window;
-- this shows just the first line with no fill. Fold size is visible on
-- demand by opening the fold, so no count prefix is kept.
local M = {}

---@param _start integer first folded line (unused; size shown on demand)
---@param _finish integer last folded line (unused; size shown on demand)
---@param first string raw first line of the fold
---@param width integer window width to trim the label to
---@return string compact single-line fold label
function M.text(_start, _finish, first, width)
  local trimmed = first:gsub('^%s*', ''):gsub('%s*$', '')
  if trimmed == '' then trimmed = '(blank)' end
  if vim.fn.strwidth(trimmed) > width then
    trimmed = vim.fn.strcharpart(trimmed, 0, math.max(width - 1, 0)) .. '…'
  end
  return trimmed
end

-- Foldtext entry point: Neovim sets vim.v.foldstart/foldend around this.
function M.foldtext()
  return M.text(vim.v.foldstart, vim.v.foldend, vim.fn.getline(vim.v.foldstart), vim.fn.winwidth(0))
end

return M
