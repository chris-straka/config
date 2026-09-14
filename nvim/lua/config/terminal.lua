-- Focused-terminal exit, shared by <leader>tR and Alt+X, plus numbered
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
