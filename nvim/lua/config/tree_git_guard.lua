-- Runtime guard for nvim-tree's git timeout crash.
-- Upstream git/utils.lua runs `vim.system(cmd):wait(timeout)` and indexes
-- the result directly. On timeout :wait() returns nil, so a single slow
-- `git rev-parse` (easy on a cold start, when git.timeout defaults to
-- 400ms) aborts the whole tree open with "attempt to index local 'obj'".
-- The plugin copy under lazy/ is managed and overwritten on update, so
-- patch the loaded module here instead of editing it. Both exported
-- entry points that reach the unguarded local system() are wrapped:
-- a timeout then degrades to "not a repo" instead of an error.
local ok_utils, git_utils = pcall(require, 'nvim-tree.git.utils')
if not ok_utils or type(git_utils) ~= 'table' then return end

if type(git_utils.get_toplevel) == 'function' and not git_utils._tree_guard_wrapped_toplevel then
  local orig = git_utils.get_toplevel
  function git_utils.get_toplevel(...)
    local ok_call, top, dir = pcall(orig, ...)
    if ok_call then return top, dir end
    return nil, nil
  end
  git_utils._tree_guard_wrapped_toplevel = true
end

if type(git_utils.should_show_untracked) == 'function' and not git_utils._tree_guard_wrapped_untracked then
  local orig = git_utils.should_show_untracked
  function git_utils.should_show_untracked(...)
    local ok_call, val = pcall(orig, ...)
    if ok_call then return val end
    return true
  end
  git_utils._tree_guard_wrapped_untracked = true
end
