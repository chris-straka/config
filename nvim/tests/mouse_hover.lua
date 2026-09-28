-- Unit test for config/mouse_hover.lua right-click hold (no framework).
-- Run: nvim --headless --noplugin -l ~/.config/nvim/tests/mouse_hover.lua
local nvim = vim.env.HOME .. '/.config/nvim'
vim.opt.rtp:prepend(nvim)

local failures = 0
local function check(name, ok)
  if ok then
    print('PASS: ' .. name)
  else
    failures = failures + 1
    print('FAIL: ' .. name)
  end
end

local hover = require('config.mouse_hover')

-- Listed buffer with a word under the stubbed mouse; no LSP attaches
-- headless, so the live path ends at no-client.
local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'hello world' })
local win = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_buf(win, buf)
hover._mousepos = function() return { winid = win, line = 1, column = 1, row = 1, col = 1 } end

-- A right-click hold suppresses hover entirely (the LSP float must
-- not open over the popup menu while it is up).
hover.hold_until = 0
check('live path reaches no-client', hover.on_mouse_move() == 'no-client')
hover.hold(60 * 1000)
check('held during right-click window', hover.on_mouse_move() == 'held')
hover.hold_until = 0
check('hold expiry restores hover', hover.on_mouse_move() == 'no-client')

if failures > 0 then
  print(failures .. ' FAILURES')
  os.exit(1)
end
print('mouse_hover: all pass')
