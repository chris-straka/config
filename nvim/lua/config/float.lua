-- Floating-terminal zoom (Alt-,/./-/= and Alt+[/]): resize the current
-- float and park it high. No-op on non-floats. Remembers the zoom as the
-- new default: toggleterm's persist_size covers splits only, so floats
-- would otherwise reopen at 80% every time (the float_opts functions in
-- plugins/editor.lua read this back).
local M = {}

---@param dw integer width delta (columns, negative shrinks)
---@param dh integer height delta (rows, negative shrinks)
function M.resize(dw, dh)
  local win = vim.api.nvim_get_current_win()
  if vim.fn.win_gettype(win) ~= 'popup' then return end
  if dw ~= 0 then
    local w = vim.api.nvim_win_get_width(win) + dw
    w = math.max(60, math.min(vim.o.columns - 4, w))
    vim.api.nvim_win_set_width(win, w)
  end
  if dh ~= 0 then
    local h = vim.api.nvim_win_get_height(win) + dh
    h = math.max(10, math.min(vim.o.lines - 4, h))
    vim.api.nvim_win_set_height(win, h)
  end
  -- keep the float parked high (same bias as the default position in
  -- plugins/editor.lua) so resizing doesn't strand it off-center
  local w, h = vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_height(win)
  vim.api.nvim_win_set_config(win, {
    relative = 'editor',
    row = math.max(0, math.floor((vim.o.lines - h) * 0.28)),
    col = math.max(0, math.floor((vim.o.columns - w) / 2)),
  })
  vim.g.toggleterm_float_size = { width = w, height = h }
end

return M
