# config

Personal machine config, one Ghostty tab per project. New machine:
`git clone https://github.com/chris-straka/config.git ~/config &&
~/config/install.sh`, then restart Ghostty.

| dir | what | live path |
| --- | ---- | --------- |
| `nvim/` | Neovim (lazy.nvim) — simple terminal toggles, project lualine, VSCode folds, tree on startup | `~/.config/nvim` |
| `ghostty/` | Ghostty — visible tab bar, Shift+Cmd+H/L tab nav, Cmd+digits/letters to nvim | `~/.config/ghostty` |
| `muse/` | Muse Code `settings.json` (MCP server list, no secrets) | `~/.config/muse/settings.json` |
| `zsh/` | `.zshrc`, `.zprofile` | `~` |
| `git/` | `.gitconfig` | `~` |

Everything is symlinked into place, so the live paths are the source of
truth — edit in place, commit here. `nvim/tests/smoke.lua` is the headless
check (`nvim --headless --noplugin -l ~/config/nvim/tests/smoke.lua`).

Never versioned: `muse/auth.json` (live OAuth tokens), `*.lock`,
`*.bak-*`, `.DS_Store` — see the `.gitignore` files.
