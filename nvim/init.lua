-- Modernized from https://github.com/chris-straka/nvim (packer era)
-- Neovim >= 0.11, plugin manager: lazy.nvim
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Per-machine overrides (untracked, see .gitignore), e.g. vim.g.center_width.
pcall(require, 'config.local')

require 'config.options'
require 'config.lazy'
require 'config.keymaps'
require 'config.autocmds'
require 'config.whichkey'
