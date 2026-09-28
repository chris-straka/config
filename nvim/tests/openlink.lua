-- Unit test for config/openlink.lua link extraction (no framework).
-- Run: nvim --headless --noplugin -l ~/.config/nvim/tests/openlink.lua
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

local openlink = require('config.openlink')
local base = '/tmp'

-- Cursor exactly on a bare URL still opens it.
local r = openlink.extract('see https://example.com/a/b for details', 10, base)
check('bare url under cursor', r ~= nil and r.url == 'https://example.com/a/b')

-- Cursor elsewhere on a line holding one URL falls back to it (gx no
-- longer needs pixel-perfect placement to open the line's link).
r = openlink.extract('see https://example.com/a/b for details', 2, base)
check('url line fallback off-cursor', r ~= nil and r.url == 'https://example.com/a/b')

-- The fallback is URL-only: prose with a path-like token but the
-- cursor off it stays a miss (no surprise file jumps).
r = openlink.extract('edit src/main.lua then run it', 20, base)
check('no file line fallback', r == nil)

-- Markdown links keep cursor-precise behavior on the label.
r = openlink.extract('read [guide](https://example.com/x) now', 8, base)
check('markdown label opens url', r ~= nil and r.url == 'https://example.com/x')

if failures > 0 then
  print(failures .. ' FAILURES')
  os.exit(1)
end
print('openlink: all pass')
