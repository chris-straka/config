-- Open the file link under the cursor in a new buffer.
-- Chat/terminal pastes arrive as Markdown links ([label](/abs/path:12))
-- or bare paths; gx jumps straight to them instead of making you
-- retype the path. Relative links first try the current file's dir, then
-- the repo root (for repo-relative references like {@code docs/DESIGN.md}
-- inside a nested source file). URLs keep their old gx behavior (browser).
local M = {}

-- Split a trailing :line off a link destination. Returns path, lnum.
---@param dest string
---@return string, integer?
local function split_line(dest)
  local path, lnum = dest:match('^(.-):(%d+)$')
  if path then return path, tonumber(lnum) end
  return dest, nil
end

-- Expand ~ and bare relative paths against base (the current file's dir).
---@param path string
---@param base string
---@return string
local function expand_path(path, base)
  if path:sub(1, 1) == '~' then return vim.fn.expand(path) end
  if path:sub(1, 1) == '/' then return path end
  return base .. '/' .. path
end

-- The destination as written, for the repo-root fallback (nil when the
-- destination was already absolute). Pure.
---@param dest string
---@return string?
local function relative_dest(dest)
  if dest:sub(1, 1) == '/' or dest:sub(1, 1) == '~' then return nil end
  return dest
end

-- Pure: pull the link target out of a line, preferring the Markdown link
-- whose span holds the cursor, else a bare path token under it.
-- Returns { file = ..., rel = ..., lnum = ... } or { url = ... } or nil.
---@param line string
---@param col integer 1-based cursor column
---@param base string directory for relative paths
---@return table?
function M.extract(line, col, base)
  -- Markdown links: [label](dest), dest may carry :line.
  local pos = 1
  while true do
    local ls, le = line:find('%b[]', pos)
    if not ls then break end
    local ps, pe = line:find('%b()', le + 1)
    if not ps or ps ~= le + 1 then
      pos = le + 1
    else
      if ls <= col and col <= pe then
        local dest = line:sub(ps + 1, pe - 1)
        dest = dest:match('^<(.*)>$') or dest
        if dest:match('^https?://') then return { url = dest } end
        local path, lnum = split_line(dest)
        return { file = expand_path(path, base), rel = relative_dest(path), lnum = lnum }
      end
      pos = pe + 1
    end
  end
  -- Bare path token under the cursor (no spaces, brackets, or quotes).
  local s, e = col, col
  while s > 1 and line:sub(s - 1, s - 1):match('[^%s%[%]()\'"<>]') do s = s - 1 end
  while e < #line and line:sub(e + 1, e + 1):match('[^%s%[%]()\'"<>]') do e = e + 1 end
  local tok = line:sub(s, e):gsub('[%.,;:!?%)}]+$', '')
  if tok == '' then return nil end
  if tok:match('^https?://') then return { url = tok } end
  if not (tok:find('/', 1, true) or tok:match('%.[%w]+')) then return nil end
  local path, lnum = split_line(tok)
  return { file = expand_path(path, base), rel = relative_dest(path), lnum = lnum }
end

-- Repo root for the fallback (nil outside a repo). Impure: shells to git.
---@param dir string
---@return string?
function M.git_root(dir)
  local out = vim.fn.systemlist('git -C ' .. vim.fn.shellescape(dir) .. ' rev-parse --show-toplevel')
  if vim.v.shell_error ~= 0 or out[1] == nil or out[1] == '' then return nil end
  return out[1]
end

-- Impure: open whatever extract found (new buffer, cursor on the line).
function M.open()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  local base = vim.fn.expand('%:p:h')
  if base == '' then base = vim.fn.getcwd() end
  local target = M.extract(line, col, base)
  if target == nil then
    vim.notify('No file link under cursor', vim.log.levels.WARN)
    return
  end
  if target.url then
    vim.ui.open(target.url)
    return
  end
  if vim.fn.filereadable(target.file) ~= 1 and vim.fn.isdirectory(target.file) ~= 1 then
    -- Repo-relative reference (e.g. {@code docs/DESIGN.md} from a nested
    -- file): retry at the repo root before giving up.
    if target.rel ~= nil then
      local root = M.git_root(base)
      if root ~= nil then
        local alt = root .. '/' .. target.rel
        if vim.fn.filereadable(alt) == 1 or vim.fn.isdirectory(alt) == 1 then
          target.file = alt
        end
      end
    end
  end
  if vim.fn.filereadable(target.file) ~= 1 and vim.fn.isdirectory(target.file) ~= 1 then
    vim.notify('Not found: ' .. target.file, vim.log.levels.WARN)
    return
  end
  -- PDFs open in Zathura (see config/pdf.lua), not as binary in a buffer.
  if target.file:lower():match('%.pdf$') then
    require('config.pdf').open(target.file)
    return
  end
  vim.cmd('edit ' .. vim.fn.fnameescape(target.file))
  if target.lnum then pcall(vim.api.nvim_win_set_cursor, 0, { target.lnum, 0 }) end
end

return M
