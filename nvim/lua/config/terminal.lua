-- Focused-terminal exit via Alt+X, numbered terminal cycling on
-- Cmd+[/], and positional jumps on Cmd+1..0 (see config/keymaps/).
-- Exit types `exit` + Enter into the focused terminal's shell job —
-- the plain-`exit` equivalent — so the shell ends and the float goes
-- away; reopen with Alt+N for a fresh shell.
local M = {}

function M.exit_focused()
  local ok, terms = pcall(require, 'toggleterm.terminal')
  if not ok then return end
  local id = terms.get_focused_id()
  if not id then
    vim.notify('no focused terminal to exit', vim.log.levels.WARN)
    return
  end
  local term = terms.get(id, true)
  if term and term.job_id then vim.fn.chansend(term.job_id, 'exit\n') end
end

-- New terminal for Cmd+T (see config/keymaps/terminal.lua): every press
-- mints a fresh float with the next free id (max live id + 1), so the
-- key always creates instead of toggling or reusing. One float stays
-- visible: other floats close first (same stacking reason as cycle
-- below). A Lua function RHS, so it runs in every mode (including
-- inside a float) with no drop-to-Normal.
---@return string status word (handy for tests)
function M.new()
  local ok, terms = pcall(require, 'toggleterm.terminal')
  if not ok then return 'no-plugin' end
  local ids = M._order()
  local target = M._next(ids)
  -- One float visible at a time (same stacking reason as cycle below).
  for _, id in ipairs(ids) do
    local other = terms.get(id, true)
    if other and other:is_open() then other:close() end
  end
  vim.cmd(target .. 'ToggleTerm direction=float')
  return 'opened'
end

-- Cycle focus across this tab's numbered terminals with wraparound
-- (Cmd+[ previous, Cmd+] next). A lone terminal refocuses itself;
-- with none open, terminal 1 opens instead of doing nothing. Closed
-- terminals in between are reopened as they come up.
---@param dir integer 1 for next, -1 for previous
---@return string status word (handy for tests)
function M.cycle(dir)
  local ok, terms = pcall(require, 'toggleterm.terminal')
  if not ok then return 'no-plugin' end
  local ids = M._order()
  if #ids == 0 then
    vim.cmd('1ToggleTerm direction=float')
    return 'opened'
  end
  local target = M._pick(ids, terms.get_focused_id(), dir)
  local term = terms.get(target, true)
  if term == nil then return 'missing' end
  -- One float visible at a time: opening the next stacks its window over
  -- the current one, leaving a "copy" of the old terminal behind it.
  for _, id in ipairs(ids) do
    if id ~= target then
      local other = terms.get(id, true)
      if other and other:is_open() then other:close() end
    end
  end
  if not term:is_open() then term:open() end
  term:focus()
  return 'focused'
end

-- Positional jump to the Nth live terminal (Cmd+1..0, 0 means 10; see
-- config/keymaps/terminal.lua). The slot is the position among the
-- sorted live ids — the same number the statusline label shows
-- (`term 2 / 3`) — never the raw toggleterm id, so gaps from closed
-- terminals can't land on the wrong shell. A digit past the last
-- terminal (or any digit with none open) warns and stays put instead
-- of landing elsewhere; digits never mint — Cmd+T does that.
---@param slot integer 1-based position
---@return string status word (handy for tests)
function M.goto_slot(slot)
  local ok, terms = pcall(require, 'toggleterm.terminal')
  if not ok then return 'no-plugin' end
  local ids = M._order()
  if #ids == 0 then
    vim.notify('no terminals yet (Cmd+T opens one)', vim.log.levels.WARN)
    return 'empty'
  end
  local target = M._at(ids, slot)
  if not target then
    vim.notify(string.format('terminal %d: only %d open', slot, #ids), vim.log.levels.WARN)
    return 'missing'
  end
  local term = terms.get(target, true)
  if term == nil then return 'missing' end
  -- One float visible at a time (same stacking reason as cycle above).
  for _, id in ipairs(ids) do
    if id ~= target then
      local other = terms.get(id, true)
      if other and other:is_open() then other:close() end
    end
  end
  if not term:is_open() then term:open() end
  term:focus()
  return 'focused'
end

-- Sorted ids of this tab's terminals; {} when toggleterm is unavailable.
function M._order()
  local ok, terms = pcall(require, 'toggleterm.terminal')
  if not ok then return {} end
  local ids = {}
  for _, t in ipairs(terms.get_all()) do ids[#ids + 1] = t.id end
  table.sort(ids)
  return ids
end

-- Ids of the toggleterm terminals displayed in the current tabpage,
-- sorted. A terminal shown in two of the tab's windows counts once.
-- Reads buffer names (the same #toggleterm#N convention the statusline
-- matches on), so it needs no plugin API. Feeds count() and the
-- headless label fallback; the live label counts plugin terminals
-- instead, since hidden floats own no window.
function M.tab_order()
  local ok, wins = pcall(vim.api.nvim_tabpage_list_wins, 0)
  if not ok or type(wins) ~= 'table' then return {} end
  local seen = {}
  for _, win in ipairs(wins) do
    local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
    local n = name:match('#toggleterm#(%d+)')
    if n then seen[tonumber(n)] = true end
  end
  local ids = {}
  for id in pairs(seen) do ids[#ids + 1] = id end
  table.sort(ids)
  return ids
end

-- How many terminals the current tab shows; 0 with none.
function M.count()
  return #M.tab_order()
end

-- Statusline label: the terminal's slot (position among the live
-- terminals) plus how many exist (`term 2 / 3`), so the bar always
-- says which terminal is shown. Counts the live terminals, not the
-- tab's windows: hidden floats own no window, so a window scan
-- collapsed every lone float to `term 1`. A lone terminal stays plain
-- `term N`; ids with no live terminal (stale renders) fall back to
-- their slot `term N`, and garbage input to `term`. Without the
-- plugin (headless test) the window scan stands in for the live list.
---@param id integer|string toggleterm id, as matched from #toggleterm#N
---@return string
function M.label(id)
  local n = tonumber(id)
  if not n then return 'term' end
  local ids = M._order()
  if #ids == 0 then ids = M.tab_order() end
  local at = nil
  for i, v in ipairs(ids) do
    if v == n then
      at = i
      break
    end
  end
  if not at then return string.format('term %d', n) end
  if #ids > 1 then return string.format('term %d / %d', at, #ids) end
  return string.format('term %d', n)
end

-- Window title label for the current buffer: files show their tail,
-- terminals show the count-aware label above, empty buffers `nvim`.
-- Lives here (not options.lua) so the titlestring stays a one-liner.
-- The pure `title_label_for` core keeps the headless smoke test honest
-- (a `terminal` buftype cannot be faked onto a scratch buffer).
---@param buftype string
---@param bufname string
---@param tail string
---@return string
function M.title_label_for(buftype, bufname, tail)
  if buftype == 'terminal' then
    local n = (bufname or ''):match('#toggleterm#(%d+)')
    if n then return M.label(n) end
    return 'term'
  end
  if (tail or '') == '' then return 'nvim' end
  return tail
end

---@return string
function M.title_label()
  local buf = vim.api.nvim_get_current_buf()
  return M.title_label_for(vim.bo[buf].buftype, vim.api.nvim_buf_get_name(buf), vim.fn.expand('%:t'))
end

-- Pure terminal-count suffix for the window title: '' with none, else
-- ` – N term` / ` – N terms`. Shown on file/empty buffers only —
-- terminal buffers already carry the count (`term 2 / 3`).
---@param count integer
---@return string
function M._count_suffix(count)
  if not count or count < 1 then return '' end
  if count == 1 then return ' – 1 term' end
  return string.format(' – %d terms', count)
end

---@return string
function M.title_count_suffix()
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].buftype == 'terminal' then return '' end
  return M._count_suffix(M.count())
end

-- Pure next-id pick for new(): one past the largest live id, or 1 with
-- none. ids must be sorted (see _order); gaps stay filled by reuse only
-- when the top id is gone (max + 1 is always free).
---@param ids integer[]
---@return integer
function M._next(ids)
  return (ids[#ids] or 0) + 1
end

-- First open terminal with a live shell, or nil: fallback for Option+K
-- senders when nothing was ever focused. Scans the live ids in order
-- instead of a fixed 1..10 range, so high ids from Cmd+T minting
-- (max id + 1, unbounded) are found too.
---@return table|nil toggleterm terminal
function M.first_open()
  local ok, terms = pcall(require, 'toggleterm.terminal')
  if not ok then return nil end
  for _, id in ipairs(M._order()) do
    local term = terms.get(id, true)
    if term and term:is_open() and term.job_id then return term end
  end
  return nil
end

-- Current terminal with a live shell, or nil: where Option+K senders
-- (see send_at_reference in config/runner.lua) type. Prefers the
-- focused terminal, then toggleterm's last-focused terminal (still
-- correct from a code buffer, where nothing is focused), and only
-- then the first open one — so @refs land in the terminal you were
-- just on, not always terminal 1.
---@return table|nil toggleterm terminal
function M.current()
  local ok, terms = pcall(require, 'toggleterm.terminal')
  if not ok then return nil end
  if terms.get_focused_id then
    local focused = terms.get_focused_id()
    if focused then
      local term = terms.get(focused, true)
      if term and term:is_open() and term.job_id then return term end
    end
  end
  if terms.get_last_focused then
    local ok_last, last = pcall(terms.get_last_focused)
    if ok_last and last and last.is_open and last:is_open() and last.job_id then return last end
  end
  return M.first_open()
end

-- Pure positional pick for goto_slot: the slot-th live id, or nil past
-- the end. ids must be sorted (see _order).
---@param ids integer[]
---@param slot integer 1-based position
---@return integer|nil
function M._at(ids, slot)
  if slot < 1 or slot > #ids then return nil end
  return ids[slot]
end

-- Pure next/previous pick with wraparound. current may be nil (nothing
-- focused) or a stale id; dir >= 0 means next, else previous.
function M._pick(ids, current, dir)
  if #ids == 0 then return nil end
  local at = nil
  for i, id in ipairs(ids) do
    if id == current then
      at = i
      break
    end
  end
  if at == nil then return dir >= 0 and ids[1] or ids[#ids] end
  if #ids == 1 then return ids[1] end
  if dir >= 0 then return ids[at % #ids + 1] end
  return ids[(at - 2) % #ids + 1]
end

return M
