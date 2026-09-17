-- Surround keys (mini.surround): normal-mode `ys`/`ds`/`cs` like nvim-surround,
-- but visual surround-add on `S`, not `ys` — with `ys` mapped in visual mode,
-- every bare visual `y` yank waited the full timeoutlen (200ms) for a
-- possible `s`. `S` is vim-surround's visual key (mini.surround's own
-- documented remap pattern); lone `y` is no longer a prefix in visual mode.
local M = {}

function M.setup()
  require('mini.surround').setup {
    mappings = { add = 'ys', delete = 'ds', replace = 'cs' },
  }
  vim.keymap.del('x', 'ys')
  vim.keymap.set(
    'x',
    'S',
    ':<C-u>lua MiniSurround.add("visual")<CR>',
    { silent = true, desc = 'Add surrounding to selection' }
  )
end

return M
