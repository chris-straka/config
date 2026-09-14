-- Bootstrap lazy.nvim (replaces packer.nvim, which is unmaintained)
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  local repo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', repo, lazypath }
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({ { 'Failed to clone lazy.nvim:\n', 'ErrorMsg' }, { out, 'WarningMsg' } }, true, {})
  end
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup('plugins', {
  defaults = { lazy = false, version = false },
  checker = { enabled = false },
  performance = {
    rtp = {
      disabled_plugins = { 'gzip', 'tarPlugin', 'tohtml', 'tutor', 'zipPlugin' },
    },
  },
})
