-- Terminals never live in splits (see enforce_float in config/terminal.lua).
-- toggleterm adopts bare :terminal buffers with a guessed split direction,
-- and any bare open re-materializes them as a bottom split — every terminal
-- buffer shown in a normal window is floated instead. File splits are
-- untouched (see the no-single-window-wiring smoke check).
-- Run: nvim --headless --noplugin -l ~/.config/nvim/tests/terminal_float.lua
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

local function read(path)
  local f = assert(io.open(path, 'r'))
  local s = f:read('*a')
  f:close()
  return s
end

check('enforce_float exists', type(term.enforce_float) == 'function')
check('float-win helper exists', type(term._is_float_win) == 'function')

if type(term.enforce_float) == 'function' then
  -- Garbage and file buffers are left alone.
  check('garbage buffer is invalid', term.enforce_float(99999) == 'invalid')
  check('nil buffer is invalid', term.enforce_float(nil) == 'invalid')
  vim.cmd('enew')
  local file_buf = vim.api.nvim_get_current_buf()
  local wins_before = vim.fn.winnr('$')
  check('file buffer is not-terminal', term.enforce_float(file_buf) == 'not-terminal')
  check('file windows untouched', vim.fn.winnr('$') == wins_before)

  -- A terminal shown in splits is floated; the shell survives.
  vim.cmd('enew')
  vim.cmd('terminal')
  local tbuf = vim.api.nvim_get_current_buf()
  vim.cmd('split')
  check('setup shows terminal in two splits', vim.fn.winnr('$') == wins_before + 1)
  local status = term.enforce_float(tbuf)
  check('split terminal is floated', status == 'floated')
  local shown_in_split = false
  local shown_in_float = false
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(w) == tbuf then
      if term._is_float_win(w) then
        shown_in_float = true
      else
        shown_in_split = true
      end
    end
  end
  check('terminal leaves every split', not shown_in_split)
  check('terminal lands in a float', shown_in_float)
  local normal_left = 0
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if not term._is_float_win(w) then normal_left = normal_left + 1 end
  end
  check('normal windows survive', normal_left >= 1)
  local job = vim.b[tbuf].terminal_job_id
  check('shell still runs', vim.fn.jobwait({ job }, 0)[1] == -1)
  vim.fn.jobstop(job)
  pcall(vim.api.nvim_buf_delete, tbuf, { force = true })

  -- A terminal already floating is a no-op.
  vim.cmd('enew')
  vim.cmd('terminal')
  local fbuf = vim.api.nvim_get_current_buf()
  local only_win = vim.api.nvim_get_current_win()
  local scratch = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(only_win, scratch)
  vim.api.nvim_open_win(
    fbuf,
    true,
    { relative = 'editor', width = 60, height = 10, row = 2, col = 2, border = 'single' }
  )
  local floats_before = 0
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if term._is_float_win(w) then floats_before = floats_before + 1 end
  end
  check('floating terminal is already-float', term.enforce_float(fbuf) == 'already-float')
  local floats_after = 0
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if term._is_float_win(w) then floats_after = floats_after + 1 end
  end
  check('no duplicate float opens', floats_after == floats_before)
  vim.fn.jobstop(vim.b[fbuf].terminal_job_id)

  -- Sole window showing a terminal: the tab keeps a normal window.
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if term._is_float_win(w) then vim.api.nvim_win_close(w, true) end
  end
  vim.cmd('only')
  vim.cmd('enew')
  vim.cmd('terminal')
  local sbuf = vim.api.nvim_get_current_buf()
  check('setup is a lone terminal window', vim.fn.winnr('$') == 1)
  check('lone terminal is floated', term.enforce_float(sbuf) == 'floated')
  local lone_normal, lone_float = 0, 0
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(w) == sbuf and term._is_float_win(w) then
      lone_float = lone_float + 1
    end
    if not term._is_float_win(w) then lone_normal = lone_normal + 1 end
  end
  check('lone tab keeps a normal window', lone_normal >= 1)
  check('lone terminal lands in a float', lone_float == 1)
  vim.fn.jobstop(vim.b[sbuf].terminal_job_id)

  -- Toggleterm-owned terminals heal through the plugin API (stubbed; the
  -- plugin is absent headless): direction forced to float, split closed,
  -- reopened as a float. The buffer is floating from the lone case, so
  -- put it back in a normal window first.
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if term._is_float_win(w) then vim.api.nvim_win_close(w, true) end
  end
  pcall(vim.cmd, 'only')
  vim.cmd('buffer ' .. sbuf)
  local calls = {}
  local stub_open = true
  local stub = {
    bufnr = sbuf,
    window = vim.api.nvim_get_current_win(),
    change_direction = function(_, dir) calls[#calls + 1] = 'direction=' .. tostring(dir) end,
    close = function(_)
      stub_open = false
      calls[#calls + 1] = 'close'
    end,
    open = function(_, size, dir)
      stub_open = true
      calls[#calls + 1] = 'open=' .. tostring(size) .. ',' .. tostring(dir)
    end,
    focus = function(_) calls[#calls + 1] = 'focus' end,
    is_open = function(_) return stub_open end,
  }
  package.loaded['toggleterm.terminal'] = { get_all = function() return { stub } end }
  check('owned terminal floats via plugin', term.enforce_float(sbuf) == 'floated-toggleterm')
  check('owned direction forced to float', calls[1] == 'direction=float')
  check('owned split closed', calls[2] == 'close')
  check('owned reopened as float', calls[3] == 'open=nil,float')
  package.loaded['toggleterm.terminal'] = nil
end

-- Wiring pins (headless has no plugin/autocmds, so assert on source like
-- the smoke test does): creation and display both route to enforce_float,
-- and the digit/cycle jumpers open floats explicitly.
local term_src = read(home .. '/.config/nvim/lua/config/terminal.lua')
local auto_src = read(home .. '/.config/nvim/lua/config/autocmds.lua')
check('TermOpen routes to enforce_float', auto_src:find('enforce_float', 1, true) ~= nil)
local group_at = auto_src:find('TerminalFloatOnly', 1, true)
check('float-only group exists', group_at ~= nil)
if group_at then
  local near = auto_src:sub(math.max(1, group_at - 400), group_at + 400)
  check('group watches TermOpen', near:find('TermOpen', 1, true) ~= nil)
  check('group watches BufWinEnter', near:find('BufWinEnter', 1, true) ~= nil)
end
local float_routes, from = 0, 1
while true do
  local s, e = term_src:find('M._float_open(term)', from, true)
  if not s then break end
  float_routes = float_routes + 1
  from = e + 1
end
check('float_open defined once, used twice', float_routes == 3)
check('float_open opens floats explicitly', term_src:find("term:open(nil, 'float')", 1, true) ~= nil)
check('jumpers heal direction', term_src:find("change_direction, term, 'float'", 1, true) ~= nil)

if failures > 0 then
  print('FAILURES: ' .. failures)
  vim.cmd('cquit 1')
else
  print('ALL PASS')
end
