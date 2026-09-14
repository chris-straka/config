# Cmd keys → Neovim: how the transport works

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
`<D-e>` (tree focus) and `<D-S-e>` (tree peek). Still missing: `<D-p>`,
`<D-o>`, `<D-S-f>`, `<D-z>`-family from floats (undo's bare-`u` RHS needs
care — in terminal mode it would be typed into the shell).

## File inventory (2026-09-14: slots retired, Ghostty tabs own projects)

- Ghostty `config` and `nvim-launcher`: Cmd+digits stay native (goto_tab),
  Cmd+letters go to nvim as CSI-u; Shift+Cmd+H/L switch Ghostty tabs
  natively; Cmd+T new tab, Cmd+W / Cmd+Opt+W close. Zero legacy sequences. The launcher duplicates
  the binds inline because the `open --args --config-file=…` handoff
  proved unreliable for includes — **mirror any keybind change in both
  files**. Window chrome (`transparent` titlebar, always-show tab bar) is
  duplicated too, for the same reason.
- Kitty config converted the same way (other track).
- `nvim/lua/config/keymaps.lua`: `<D-…>` maps are the live path; the old
  `<Esc>[9xx…` maps stay as harmless fallback; `<D-e>` and `<D-S-e>` have
  terminal mode maps, other letters don't (see above).
- Backups of the four terminal configs: `/tmp/dotbackup/` — note `/tmp`
  clears on reboot, move these somewhere permanent if they still matter.
- Full nvim config backup: `~/.config/nvim.bak-20260913`.

## How it was proven

pty rig driving the full config: injected `Esc[101;9u` → tree opened;
`Esc[50;9u` → slot terminal 2 float; `Esc[101;9u` from inside that float →
tree toggled shut. Each observed both on-screen and via a second RPC
observer. The old `~` sequences were shown undeliverable the same way on
Ghostty and kitty.
