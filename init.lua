-- Modernized from https://github.com/chris-straka/nvim (packer era)
-- Neovim >= 0.11, plugin manager: lazy.nvim
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

require 'config.options'
require 'config.lazy'
require 'config.keymaps'
require 'config.autocmds'
require 'config.whichkey'
