# Cmd keys → Neovim: how the transport works

_Record of the 2026-09-14 CSI-u migration. The transport scheme below is
current; the file inventory has been updated as behavior changed since
(the "how it was proven" section is the original test log).

## The one-paragraph version

Terminal apps cannot see the Cmd key. macOS reserves Cmd for itself and
menus; the pipe between the terminal and Neovim carries only plain bytes.
So "Cmd+E inside nvim" is impossible directly — the emulator must
translate the keypress into bytes nvim can see.

## Why the old codes died

We translated Cmd keys into made-up codes like `Esc[925;1~`. The trouble:
anything starting with `Esc[` is a CSI ("Control Sequence Introducer") —
the escape-code system terminals use for real special keys (arrows, F-keys,
Home/End). Neovim 0.12 inspects every CSI at the door: recognized ones get
converted into keys, unrecognized ones (our made-up 900–939 numbers) get
thrown away before keymaps are even consulted. Picture a letter with a fake
postcode, discarded at the sorting office: the mailbox (your mappings) was
fine, the recipient (toggleterm, NvimTree) was home, the letter just never
arrived. That's why every layer looked innocent — maps registered, actions
worked when typed, both emulators emitted the bytes, timeouts and plugins
made no difference — while every live keypress died silently.

## The current scheme: CSI-u with the super modifier

Same keys, legal postcodes. Codes come from the standard CSI-u system
(`Esc[<unicode>;<modifier>u`), which Neovim parses into real Cmd-keys
(`<D-e>`, `<D-2>`, …) that the existing `<D-…>` maps catch unchanged:

| Pressed         | Sent          | Modifier math   | Lands as |
|-----------------|---------------|-----------------|----------|
| Cmd+key         | `Esc[…;9u`    | 8 (super) + 1   | `<D-…>`  |
| Cmd+Shift+key   | `Esc[…;10u`   | 8 + 1 + 1       | `<D-S-…>`|
| Cmd+Ctrl+key    | `Esc[…;13u`   | 8 + 4 + 1       | `<D-C-…>`|

The number before the `;` is the plain key (`101` = e, `50` = 2).

## The float rule

Inside a toggleterm float, keystrokes go to the shell job, not to Neovim.
Anything bound to a `:` command therefore needs terminal-mode handling
that steps out to Terminal-Normal first (`<C-\><C-n>`). Currently covered:
`<D-e>` (tree focus), `<D-S-e>` (tree peek), `<D-[>` / `<D-]>`
(terminal cycling), and `<D-w>` (buffer close / empty-buffer tabclose —
a Lua function RHS, so it runs in every mode with no drop-to-Normal).
`<D-t>` (new terminal) and `<D-1>`..`<D-0>` (positional jumps) are Lua
functions too, so they run in every mode — including inside a float —
with no drop-to-Normal.
Still missing: `<D-p>`,
`<D-o>`, `<D-S-f>`, `<D-z>`-family from floats (undo's bare-`u` RHS needs
care — in terminal mode it would be typed into the shell).

## File inventory (2026-09-14: slots retired, Ghostty tabs own projects)

- Ghostty `config` and `nvim-launcher`: Cmd+T mints a fresh nvim float
  as CSI-u (`<D-t>`), Cmd+[/] steps terminal floats, Cmd+1..0 jumps to
  the Nth live terminal (`<D-1>`..`<D-0>`, positional — out-of-range
  warns and stays put), Alt+digits stay native (goto_tab),
  Shift+Cmd+T opens a tab (was Ghostty's Cmd+T), Shift+Cmd+N opens a
  window (Cmd+N stays default too);
  Cmd+letters go to nvim as CSI-u (Cmd+W closes nvim's buffer, or the
  tab when the buffer is empty — tabclose only, never a window close);
  Shift+Cmd+H/L switch Ghostty tabs natively;
  escalating close (Cmd+W buffer, Shift+Cmd+W tab, Ctrl+Shift+Cmd+W
  window; Cmd+Opt+W still closes tabs, Ghostty default). Zero legacy sequences. The launcher duplicates
  the binds inline because the `open --args --config-file=…` handoff
  proved unreliable for includes — **edit shared-keybinds.conf and run
  install.sh, which splices the block into both files**. Window chrome
  (`transparent` titlebar, hidden tab bar — lualine names the project,
  Shift+Cmd+H/L switches) and the zoomed-in `font-size` are
  duplicated too, for the same reason.
- Kitty config converted the same way (other track): Cmd+T to nvim,
  Shift+Cmd+T tab, Shift+Cmd+N window, Cmd+1..0 jumps to terminal slots.
- `nvim/lua/config/keymaps/`: `<D-…>` maps are the live path (the old
  single `keymaps.lua` was split into focused modules); the pre-0.12
  `<Esc>[9xx…` fallback maps are retired — both terminals speak CSI-u.
  `<D-e>` / `<D-S-e>` keep their drop-to-Normal terminal maps; `<D-w>`
  is a Lua function map covering every mode including terminal.
- Backups of the four terminal configs: `/tmp/dotbackup/` — note `/tmp`
  clears on reboot, move these somewhere permanent if they still matter.
- Full nvim config backup: `~/.config/nvim.bak-20260913`.

## How it was proven

pty rig driving the full config: injected `Esc[101;9u` → tree opened;
`Esc[50;9u` → slot terminal 2 float; `Esc[101;9u` from inside that float →
tree toggled shut. Each observed both on-screen and via a second RPC
observer. The old `~` sequences were shown undeliverable the same way on
Ghostty and kitty.
