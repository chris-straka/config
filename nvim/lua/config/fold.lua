-- Compact fold indicator (wired as `foldtext` in options.lua): the stock
-- foldtext pads `+-- N lines: ...` with dots across the whole window;
-- this shows the same facts (`+ 6 lines · first line`) with no fill.
local M = {}

---@param start integer first folded line
---@param finish integer last folded line
---@param first string raw first line of the fold
---@param width integer window width to trim the label to
---@return string compact single-line fold label
function M.text(start, finish, first, width)
  local trimmed = first:gsub('^%s*', ''):gsub('%s*$', '')
  if trimmed == '' then trimmed = '(blank)' end
  local n = finish - start + 1
  local head = string.format(n == 1 and '+ 1 line · ' or '+ %d lines · ', n)
  local room = width - vim.fn.strwidth(head) - 1
  if room < 1 then return head:gsub('%s+$', '') end
  if vim.fn.strwidth(trimmed) > room then
    trimmed = vim.fn.strcharpart(trimmed, 0, math.max(room - 1, 0)) .. '…'
  end
  return head .. trimmed
end

-- Foldtext entry point: Neovim sets vim.v.foldstart/foldend around this.
function M.foldtext()
  return M.text(vim.v.foldstart, vim.v.foldend, vim.fn.getline(vim.v.foldstart), vim.fn.winwidth(0))
end

return M
