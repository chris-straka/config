-- Regression: the cursor stays centered through the end-of-file tail
-- on every step, including across closed folds (buffer-line topline math
-- once yanked the view 31 rows crossing a 10-line fold; the native
-- fold-aware `zz` keeps the cursor glued while the topline follows).
-- Headless scripts never deliver CursorMoved on their own, so every step
-- forces one per move exactly as live input would; this tests the
-- callback logic, not event delivery. Run:
--   nvim --headless --cmd "set columns=120" --cmd "set lines=40" /tmp/center_tail_target.txt -c "luafile ~/.config/nvim/tests/center_tail.lua"
local failures = 0
local function check(name, ok)
  if ok then
    print('PASS: ' .. name)
  else
    failures = failures + 1
    print('FAIL: ' .. name)
  end
end

local function no() return false end
vim.wait(1200, no) -- startup settles
vim.cmd('edit /tmp/center_tail_target.txt')
vim.cmd('silent! 1,$d')
local lines = {}
for i = 1, 200 do lines[#lines + 1] = 'line ' .. i end
vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
vim.cmd('set foldmethod=manual foldlevel=99')
for _, r in ipairs({ { 150, 160 }, { 172, 185 } }) do
  vim.cmd(r[1] .. ',' .. r[2] .. 'fold')
end
for _, l in ipairs({ 150, 172 }) do
  vim.api.nvim_win_set_cursor(0, { l, 0 })
  vim.cmd('normal! zc')
end

local height = vim.fn.winheight(0)
local half = math.floor(height / 2)
local function centered()
  return math.abs(vim.fn.winline() - (half + 1)) <= 2
end

local function step(keys)
  vim.cmd('normal! ' .. keys)
  vim.cmd('doautocmd CursorMoved')
end

-- Tail: G centers and holds the local scrolloff off (no auto-scroll
-- fighting the recenter, which was the visible stumble).
step('G')
check('G centers at EOF', centered())
check('tail holds local scrolloff off', vim.opt_local.scrolloff:get() == 0)

-- Walk up through the tail, across closed folds, and out the top: the
-- cursor never leaves center on any step.
local bad = 0
for _ = 1, 30 do
  step('k')
  if not centered() then bad = bad + 1 end
end
check('every walk step stays centered', bad == 0)

-- Above the tail the local scrolloff follows the global again.
check('leaving tail restores scrolloff',
  vim.opt_local.scrolloff:get() == vim.api.nvim_get_option_value('scrolloff', { scope = 'global' }))

if failures > 0 then
  print(failures .. ' check(s) failed')
  os.exit(1)
end
print('center tail checks passed')
vim.cmd('qa!')
