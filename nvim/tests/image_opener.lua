-- Unit test for config/image.lua (no framework, plain asserts).
-- Run: nvim --headless --noplugin -l ~/.config/nvim/tests/image_opener.lua
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

local image = require('config.image')
check('png handled', image.handles('/tmp/shot.png'))
check('JPG handled (case-insensitive)', image.handles('/tmp/PHOTO.JPG'))
check('webp handled', image.handles('/tmp/a.webp'))
check('svg handled', image.handles('/tmp/a.svg'))
check('png renders in-buffer', image.in_buffer('/tmp/shot.png'))
check('JPG renders in-buffer', image.in_buffer('/tmp/PHOTO.JPG'))
check('avif renders in-buffer', image.in_buffer('/tmp/a.avif'))
check('svg stays external', not image.in_buffer('/tmp/a.svg'))
check('tif stays external', not image.in_buffer('/tmp/a.tif'))
check('rs never in-buffer', not image.in_buffer('/tmp/main.rs'))
check('pdf not handled', not image.handles('/tmp/doc.pdf'))
check('rs not handled', not image.handles('/tmp/main.rs'))
check('extensionless not handled', not image.handles('/tmp/Makefile'))
check('dotfile without ext not handled', not image.handles('/tmp/.gitignore'))

if failures > 0 then
  print(failures .. ' FAILURES')
  os.exit(1)
end
print('image_opener: all pass')
