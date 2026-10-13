-- Bracketed paste must survive escape sequences arriving in separate reads.
-- Run: nvim --headless --noplugin -l nvim/tests/terminal_paste.lua
local runtime = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
local failures = 0

local function check_paste(name, split)
  local socket = vim.fn.tempname()
  local child = vim.fn.jobstart({
    vim.v.progpath, '--clean', '--listen', socket,
    '-c', 'lua vim.opt.rtp:prepend(' .. string.format('%q', runtime) .. '); require("config.options")',
    '-c', 'terminal /bin/cat', '-c', 'startinsert',
  }, { pty = true, width = 100, height = 20, on_stdout = function() end })
  assert(child > 0, 'could not start test terminal')
  assert(vim.wait(5000, function() return vim.uv.fs_stat(socket) ~= nil end), 'child socket unavailable')
  local rpc = vim.fn.sockconnect('pipe', socket, { rpc = true })
  assert(rpc > 0, 'could not connect to test terminal')
  assert(vim.wait(5000, function()
    return vim.rpcrequest(rpc, 'nvim_get_mode').mode == 't'
  end), 'terminal did not enter input mode')
  local text = 'pasted note'
  if split then
    vim.fn.chansend(child, '\27')
    vim.wait(40)
    vim.fn.chansend(child, '[200~' .. text .. '\27[201~')
  else
    vim.fn.chansend(child, '\27[200~' .. text .. '\27[201~')
  end
  assert(vim.wait(3000, function()
    local lines = vim.rpcrequest(rpc, 'nvim_buf_get_lines', 0, 0, -1, false)
    return table.concat(lines, '\n'):find(text, 1, true) ~= nil
  end), 'pasted text never reached the terminal')
  local result = table.concat(vim.rpcrequest(rpc, 'nvim_buf_get_lines', 0, 0, -1, false), '\n')
  local ok = not result:find('200~', 1, true) and not result:find('201~', 1, true)
  print((ok and 'PASS: ' or 'FAIL: ') .. name)
  if not ok then
    failures = failures + 1
    print(vim.inspect(result))
  end
  vim.rpcnotify(rpc, 'nvim_command', 'qa!')
  vim.fn.jobwait({ child }, 3000)
  pcall(vim.fn.chanclose, rpc)
  vim.fn.delete(socket)
end

check_paste('complete paste markers are consumed', false)
check_paste('split paste markers are consumed', true)
if failures > 0 then vim.cmd('cquit') end
vim.cmd('qa!')
