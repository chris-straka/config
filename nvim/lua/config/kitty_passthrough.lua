-- Inline images for TUIs in terminal floats (cz tui): a :terminal job's
-- Kitty graphics commands (APC `ESC _ G … ESC \`) reach nvim as TermRequest
-- events and stop there, so forward them to the outer terminal (Ghostty
-- speaks the protocol). The job draws with Unicode placeholders (U+10EEEE
-- cells coloured with the image id), which are ordinary text in the float's
-- grid, so the image moves, scrolls, and hides with the float — no
-- positioning on nvim's side. Needs termguicolors (the id rides a 24-bit
-- foreground). Wired from autocmds.lua.
local M = {}

-- Forward one sequence if it is a Kitty graphics command; true when sent.
---@param sequence string|nil the APC/OSC/DCS body as TermRequest reports it
---@param terminator string|nil BEL or ST, as received
---@return boolean
function M.forward(sequence, terminator)
  if type(sequence) ~= 'string' or sequence:sub(1, 3) ~= '\27_G' then return false end
  if type(vim.api.nvim_ui_send) ~= 'function' then return false end
  vim.api.nvim_ui_send(sequence .. (terminator or '\27\\'))
  return true
end

function M.setup()
  vim.api.nvim_create_autocmd('TermRequest', {
    group = vim.api.nvim_create_augroup('KittyPassthrough', { clear = true }),
    callback = function(ev) M.forward(ev.data.sequence, ev.data.terminator) end,
  })
end

return M
