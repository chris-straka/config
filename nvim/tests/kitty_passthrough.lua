-- Test for config/kitty_passthrough.lua (no framework, plain asserts): a
-- :terminal job's Kitty graphics transmit reaches the outer terminal.
-- Run: nvim --headless --noplugin -l ~/.config/nvim/tests/kitty_passthrough.lua
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

-- Headless has no UI to send to: record what would have been sent.
local sent = {}
vim.api.nvim_ui_send = function(data) table.insert(sent, data) end

local passthrough = require('config.kitty_passthrough')
check('ignores OSC', not passthrough.forward('\27]11;?', '\7'))
check('ignores non-graphics APC', not passthrough.forward('\27_Xfoo', '\27\\'))
check('ignores nil', not passthrough.forward(nil, nil))
check('nothing sent for ignored sequences', #sent == 0)

passthrough.setup()
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(buf)
local transmit = '\27_Ga=T,U=1,i=7,f=100,q=2,c=2,r=1;iVBORw0KGgo=\27\\'
vim.fn.jobstart({ 'printf', '%s', transmit }, { term = true })
vim.wait(2000, function() return #sent > 0 end, 20)
check('terminal transmit forwarded once', #sent == 1)
check('forwarded bytes intact', sent[1] == transmit)

if failures > 0 then
  print(failures .. ' FAILURES')
  os.exit(1)
end
print('kitty_passthrough: all pass')
