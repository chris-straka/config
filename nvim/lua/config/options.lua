local o = vim.opt
local g = vim.g

o.autowrite = true
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
-- project (cwd basename) plus a short label instead: files show their
-- tail, terminals show `term`, empty buffers show `nvim`.
o.titlestring = [[%{fnamemodify(getcwd(), ':t')} – %{&buftype == 'terminal' ? 'term' : expand('%:t') == '' ? 'nvim' : expand('%:t')}]]
-- Huge scrolloff keeps the cursor centered, so scrolling past end-of-file
-- shows empty space below the last line (G parks the last line
-- mid-screen instead of pinning it to the bottom).
o.scrolloff = 999
o.expandtab = true
o.tabstop = 2
o.smartindent = true
o.shiftwidth = 2
o.termguicolors = true
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

g.gitblame_enabled = 0

-- colorscheme is set in lua/plugins/ui.lua (catppuccin spec config):
-- options.lua runs before lazy.nvim puts plugins on the rtp, so any
-- :colorscheme here would silently no-op on every start.
