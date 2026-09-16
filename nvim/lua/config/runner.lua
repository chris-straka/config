-- Code-runner-style "run this file" on top of overseer.nvim (already
-- installed as the tasks backend). <leader>of runs the current buffer with
-- the right interpreter and shows output docked at the bottom without
-- stealing focus; stop/re-run from the task list (<leader>ot).
local M = {}

-- filetype -> command builder. Only single-file-friendly runtimes are
-- listed: project-based ones (cargo, dotnet…) belong in real tasks
-- (<leader>or) or a dev-server terminal, not behind a run button.
local runners = {
  python = function(f) return { 'python3', f } end,
  javascript = function(f) return { 'node', f } end,
  -- Yes, bun is the TS runner here: it executes .ts/.tsx natively with
  -- types stripped, no ts-node/tsx install needed (bun 1.3.x verified).
  -- Plain .js stays on node (universal default); .jsx lands on bun too
  -- since node cannot run JSX at all.
  typescript = function(f) return { 'bun', f } end,
  typescriptreact = function(f) return { 'bun', f } end,
  javascriptreact = function(f) return { 'bun', f } end,
  lua = function(f) return { 'lua', f } end,
  sh = function(f) return { 'bash', f } end,
  zsh = function(f) return { 'zsh', f } end,
  go = function(f) return { 'go', 'run', f } end,
  ruby = function(f) return { 'ruby', f } end,
  java = function(f) return { 'java', f } end,
}

---Run the current file, VSCode code-runner style.
function M.run_file()
  local ft = vim.bo.filetype
  local build = runners[ft]
  if not build then
    vim.notify(
      'no runner for filetype ' .. (ft ~= '' and ft or '(none)') .. ' — use a task (<leader>or)',
      vim.log.levels.WARN
    )
    return
  end
  local file = vim.api.nvim_buf_get_name(0)
  if file == '' then
    vim.notify('save the file first — nothing to run', vim.log.levels.WARN)
    return
  end
  vim.cmd('silent! write')
  local ok, overseer = pcall(require, 'overseer')
  if not ok then
    vim.notify('overseer.nvim not loaded', vim.log.levels.ERROR)
    return
  end
  local task = overseer.new_task({
    cmd = build(file),
    name = 'run ' .. vim.fn.fnamemodify(file, ':t'),
    components = { 'default', 'open_output' },
  })
  task:start()
end

---Build an @file reference for a visual selection (pure, unit-tested).
---Whole-file selection collapses to bare @file, matching the
---"no lines highlighted = whole file" convention.
---@param file string path relative to cwd, '' when the buffer has no file
---@param s integer first selected line (1-based, '< is always first)
---@param e integer last selected line
---@param total integer buffer line count
---@return string|nil brief reference, nil when there is no file
function M.at_reference(file, s, e, total)
  if file == '' then return nil end
  if s == 1 and e == total then return '@' .. file end
  if s == e then return '@' .. file .. '#' .. s end
  return '@' .. file .. '#' .. s .. '-' .. e
end

---Line range of the visual selection (1-based, first <= last). While a
---selection is active its '< / '> marks still hold the PREVIOUS selection
---(they update on visual exit), so read the live anchor ('v') and cursor
---('.') instead; fall back to the marks once visual is over.
---@return integer s first selected line
---@return integer e last selected line
function M.visual_range()
  local m = vim.fn.mode()
  local s, e
  if m == 'v' or m == 'V' or m == '\22' then
    s, e = vim.fn.getpos('v')[2], vim.fn.getpos('.')[2]
  else
    s, e = vim.fn.line("'<"), vim.fn.line("'>")
  end
  if s > e then s, e = e, s end
  return s, e
end

---Brief @file reference for the current visual selection (pure part of
---send_at_reference, kept separate so tests can drive it headlessly).
---@return string|nil brief reference, nil when there is no file
function M.ref_for_visual()
  local file = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':.')
  local s, e = M.visual_range()
  return M.at_reference(file, s, e, vim.api.nvim_buf_line_count(0))
end

---Option+K from visual mode (Claude Code's @-mention habit): types
---`@file` / `@file#l1-l2` into the visible floating terminal — a Muse
---prompt, a shell, whatever runs there. No Enter is sent; review the text
---and hit enter yourself. Visual-only on purpose: normal-mode Option+K is
---window navigation (<A-k>), which stays. Whether the agent expands the
---reference is up to the agent; worst case it is visible pasted text.
function M.send_at_reference()
  local ref = M.ref_for_visual()
  if not ref then
    vim.notify('save the file first — nothing to reference', vim.log.levels.WARN)
    return
  end
  local terms = require('toggleterm.terminal')
  local target
  for id = 1, 10 do
    local t = terms.get(id, true)
    if t and t:is_open() and t.job_id then
      target = t
      break
    end
  end
  if not target then
    vim.cmd('1ToggleTerm direction=float')
    target = terms.get(1, true)
  end
  if not target or not target.job_id then
    vim.notify('no live terminal to send to', vim.log.levels.WARN)
    return
  end
  vim.api.nvim_chan_send(target.job_id, ref .. ' ')
end

return M
