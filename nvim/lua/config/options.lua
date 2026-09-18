local o = vim.opt
local g = vim.g

o.autowrite = true
o.autoread = true
o.clipboard = 'unnamedplus'
o.fileencoding = 'utf-8'
o.number = true
o.relativenumber = true
o.splitbelow = true
o.splitright = true
o.errorbells = false
o.title = true
-- Short tab titles: Ghostty shows nvim's terminal title, and the default
-- includes the full terminal buffer path, so a toggleterm float reads
-- like `zsh;#toggleterm#1 - (term protocol path) - Nvim`. Show just the
-- project (cwd basename) plus a short label instead (see
-- config.terminal.title_label): files show their tail, terminals show
-- their slot plus the terminal count (`term 2 / 3`, lone terminals
-- plain `term N`), empty buffers `nvim`.
o.titlestring =
  [[%{fnamemodify(getcwd(), ':t')} – %{v:lua.require('config.terminal').title_label()}]]
-- Huge scrolloff keeps the cursor centered, so scrolling past end-of-file
-- shows empty space below the last line (G parks the last line
-- mid-screen instead of pinning it to the bottom).
o.scrolloff = 999
o.expandtab = true
o.tabstop = 2
o.smartindent = true
o.shiftwidth = 2
o.termguicolors = true
-- Mouse in every mode: nvim captures clicks itself (middle-click is ours
-- to bind) instead of the emulator stealing them for selection paste.
o.mouse = 'a'
-- Deliver mouse movements as <MouseMove> (see the map in config/keymaps/general.lua):
-- resting the mouse on a word shows its hover docs. Tradeoff: moving the
-- mouse aborts a half-typed mapping, same as pressing a wrong key would.
o.mousemoveevent = true
-- Right-click popup: drop the "How to disable mouse" item (and its
-- separator) from Neovim's default PopUp menu; the rest (Inspect,
-- Go to definition, Cut/Copy/Paste, ...) stays. pcall: defaults may not
-- define the item on every version, and that must not break startup.
pcall(vim.cmd, 'aunmenu PopUp.How-to\\ disable\\ mouse')
pcall(vim.cmd, 'aunmenu PopUp.-2-')
-- 200ms: Space is the leader and which-key intentionally holds bare Space
-- taps this long waiting for the follow-up key (that hold IS the "space
-- lag"); combos resolve instantly once the next key arrives, so this only
-- shortens the lone-tap stall, not real typing.
o.timeoutlen = 200
-- Alt keys arrive as Esc-prefixed sequences (now in insert mode too), so a
-- lone Esc must resolve fast: 10ms keeps Esc snappy while still
-- recognizing the sequences, which always arrive in a single write.
-- (Cmd keys now arrive as CSI-u super encodings, decoded before mapping.)
o.ttimeoutlen = 10
o.exrc = true -- per-project '.nvim.lua' overrides (e.g. disable a server)
o.hlsearch = false
o.ignorecase = true
o.smartcase = true
o.laststatus = 3
-- One Ghostty tab = one project, so nvim tabs are rare; show the tab bar
-- only when more than one exists. Project identity lives in lualine.
o.showtabline = 1
o.signcolumn = 'yes'
o.updatetime = 250
o.undofile = true
o.swapfile = false
-- VSCode-style: no .swp files, so the E325 "swap file exists" prompt can
-- never appear. Crash recovery still has persistent undo (above) plus
-- manual <leader>Sw session snapshots; autosave (see autocmds) makes
-- unsaved-loss rare in the first place.
o.breakindent = true
o.completeopt = 'menu,menuone,noselect'
-- Folding from treesitter grammars (no extra plugin): the parser computes
-- fold regions, `za` toggles, `zc`/`zo` close/open, `zM`/`zR` close/open
-- all. Start with everything open so files never load pre-folded.
o.foldmethod = 'expr'
o.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
o.foldlevel = 99
o.foldlevelstart = 99
o.foldenable = true
-- Compact fold line (see config/fold.lua): the stock foldtext stretches
-- `+-- N lines: ...` dot padding across the whole window; this keeps the
-- same facts (`+ 6 lines · first line`) with no fill. foldtext only
-- builds the label — Neovim still pads the rest of a closed fold line
-- with the `fold` fillchar (dots), so that goes to a space too.
o.foldtext = [[v:lua.require('config.fold').foldtext()]]
o.fillchars:append({ fold = ' ' })

g.gitblame_enabled = 0

-- colorscheme is set in lua/plugins/ui.lua (catppuccin spec config):
-- options.lua runs before lazy.nvim puts plugins on the rtp, so any
-- :colorscheme here would silently no-op on every start.
