-- Scroll memory for floating terminals (see config/terminal.lua).
-- Run: nvim --headless --noplugin -l ~/.config/nvim/tests/terminal_scroll.lua
local home = vim.env.HOME
vim.opt.rtp:prepend(home .. '/.config/nvim')

local term = require('config.terminal')

local failures = 0
local function check(name, ok)
  if ok then
    print('PASS: ' .. name)
  else
    failures = failures + 1
    print('FAIL: ' .. name)
  end
end

-- _scrolled_up: equality means the last line is visible (at bottom).
check('bottom line visible is not scrolled', term._scrolled_up(91, 100, 10) == false)
check('one hidden line is scrolled', term._scrolled_up(90, 100, 10) == true)
check('fresh buffer is not scrolled', term._scrolled_up(1, 1, 10) == false)
check('short buffer is not scrolled', term._scrolled_up(1, 5, 10) == false)

-- remember/recall round-trip on throwaway ids (no live terminals here).
local id = 9973
term.remember(id, { topline = 40 }, false)
local back = term.recall(id, 100)
check('scrolled view is recalled', type(back) == 'table' and back.topline == 40)
term.remember(id, { topline = 40 }, false)

-- Left at the bottom: nothing stored, reopen follows new output instead.
term.remember(id, { topline = 91 }, true)
check('at-bottom remember stores nothing', term.recall(id, 100) == nil)

-- Stale snapshot past the new end is dropped, not clamped.
term.remember(id, { topline = 5000 }, false)
check('stale view is dropped', term.recall(id, 100) == nil)
check('stale view does not linger', term.recall(id, 100) == nil)

-- forget_buf parses the toggleterm convention; anything else is ignored.
term.remember(id, { topline = 40 }, false)
term.forget_buf('zsh;#toggleterm#' .. id)
check('forget_buf clears the id', term.recall(id, 100) == nil)
term.remember(id, { topline = 40 }, false)
term.forget_buf('somefile.lua')
check('forget_buf ignores other buffers', term.recall(id, 100) ~= nil)
term.forget_buf(nil)
check('forget_buf tolerates nil', term.recall(id, 100) ~= nil)
term.forget_buf('zsh;#toggleterm#' .. id)

-- recall with no snapshot is nil; garbage ids never error.
check('unknown id recalls nil', term.recall(9974, 100) == nil)
check('garbage id recalls nil', term.recall('nope', 100) == nil)
term.remember('nope', { topline = 1 }, false)
check('garbage id remembers nothing', term.recall('nope', 100) == nil)

if failures > 0 then
  print('FAILURES: ' .. failures)
  vim.cmd('cquit 1')
else
  print('ALL PASS')
end
