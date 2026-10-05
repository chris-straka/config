-- Every Cmd key Ghostty sends must be mapped in normal, insert and
-- terminal mode. An unmapped one is not silent: insert mode types its
-- name (`<D-p>`) into the buffer, which autosave then writes, and
-- terminal mode drops the Cmd and sends the bare letter to the job.
-- Reads the sequences straight from ghostty/shared-keybinds.conf.
-- Needs the full config (keymaps load with it), so NOT --noplugin. Run:
--   nvim --headless -c "luafile ~/.config/nvim/tests/cmd_keys.lua"
local conf = vim.fn.expand('~/config/ghostty/shared-keybinds.conf')

-- Deliberate gaps: key -> mode -> reason.
local exempt = {
  -- Trash lives buffer-locally in the tree (normal mode only); in a
  -- code buffer's normal mode the stray key is harmless.
  ['<D-BS>'] = { n = 'tree-local trash map' },
}

local names = { [127] = 'BS', [60] = 'lt', [92] = 'Bslash', [124] = 'Bar' }

-- ESC[<code>;<mods>u -> key notation, or nil when super is not held.
local function decode(code, mods)
  local m = mods - 1
  if bit.band(m, 8) == 0 then return nil end
  local prefix = 'D-'
  if bit.band(m, 4) ~= 0 then prefix = prefix .. 'C-' end
  if bit.band(m, 2) ~= 0 then prefix = prefix .. 'M-' end
  if bit.band(m, 1) ~= 0 then prefix = prefix .. 'S-' end
  local key = names[code] or string.char(code):lower()
  return '<' .. prefix .. key .. '>'
end

local failures, checked = 0, 0
for line in io.lines(conf) do
  local code, mods = line:match('^keybind%s*=.-=text:\\x1b%[(%d+);(%d+)u')
  local lhs = code and decode(tonumber(code), tonumber(mods))
  if lhs then
    for _, mode in ipairs({ 'n', 'i', 't' }) do
      checked = checked + 1
      local ok = vim.fn.maparg(lhs, mode) ~= '' or (exempt[lhs] and exempt[lhs][mode])
      if not ok then
        failures = failures + 1
        print('FAIL: ' .. lhs .. ' has no ' .. mode .. ' map')
      end
    end
  end
end

if checked == 0 then
  print('FAIL: no Cmd sequences parsed from ' .. conf)
  failures = 1
end
if failures > 0 then
  print(failures .. ' check(s) failed')
  vim.cmd('cq')
else
  print('cmd keys: all ' .. checked .. ' pass')
  vim.cmd('qa!')
end
