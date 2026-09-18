-- Focused-terminal exit via Alt+X, plus numbered
-- terminal cycling on Cmd+[/] (see config/keymaps/). Exit types `exit`
-- + Enter into the focused terminal's shell job — the plain-`exit`
-- equivalent — so the shell ends and the float goes away; reopen with
-- Alt+N for a fresh shell.
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

-- Cycle focus across this tab's numbered terminals with wraparound
-- (Alt+N jumps direct, this steps). A lone terminal refocuses itself;
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

-- Statusline label: the terminal's own slot plus how many terminals
-- exist (`term 2 / 3`), so the bar always says which terminal is
-- shown. Counts the live terminals, not the tab's windows: hidden
-- floats own no window, so a window scan collapsed every lone float
-- to `term 1`. A lone terminal stays plain `term N`; ids with no live
-- terminal (stale renders) fall back to their slot `term N`, and
-- garbage input to `term`. Without the plugin (headless test) the
-- window scan stands in for the live list.
---@param id integer|string toggleterm id, as matched from #toggleterm#N
---@return string
function M.label(id)
  local n = tonumber(id)
  if not n then return 'term' end
  local ids = M._order()
  if #ids == 0 then ids = M.tab_order() end
  local known = false
  for _, v in ipairs(ids) do
    if v == n then
      known = true
      break
    end
  end
  if not known then return string.format('term %d', n) end
  if #ids > 1 then return string.format('term %d / %d', n, #ids) end
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
