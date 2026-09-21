-- Regression: git keys are reachable, not just installed. Gitsigns hunk
-- keys attach per buffer inside repos; gy/gd are global. Needs the real
-- plugins, so NOT --noplugin. Run from the config repo:
--   cd ~/.config && nvim --headless --cmd "set columns=250" --cmd "set lines=60" nvim/init.lua -c "luafile ~/.config/nvim/tests/git_keys.lua"
local failures = 0
local function check(name, ok)
  if ok then
    print('PASS: ' .. name)
  else
    failures = failures + 1
    print('FAIL: ' .. name)
  end
end

-- Gitsigns attaches async after the buffer loads; the hunk keys exist
-- only once on_attach has run, so gate on the first one.
vim.wait(10000, function() return vim.fn.maparg(' gp', 'n') ~= '' end)
check('gitsigns attached (preview key present)', vim.fn.maparg(' gp', 'n') ~= '')
check('reset hunk key present', vim.fn.maparg(' gr', 'n') ~= '')
check('stage hunk key present', vim.fn.maparg(' gs', 'n') ~= '')
check('copy-link key present (normal)', vim.fn.maparg(' gy', 'n') ~= '')
check('copy-link key present (visual)', vim.fn.maparg(' gy', 'v') ~= '')
-- The diff toggle is bound at startup (keymaps/workspace.lua), so unlike
-- which-key's deferred labels it is visible immediately.
check('diff toggle key present', vim.fn.maparg(' gd', 'n') ~= '')
if failures > 0 then
  print(failures .. ' check(s) failed')
  os.exit(1)
end
print('git keys checks passed')
vim.cmd('qa!')
