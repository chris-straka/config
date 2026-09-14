-- Keymaps entry point. Ported from old mappings.lua; split from the single
-- keymaps.lua into focused modules (general editing, workspace navigation,
-- terminals). `require 'config.keymaps'` keeps resolving here, so init.lua
-- and the smoke suite need no changes to find the maps.
--
-- Transport note for every Cmd map in these modules: Cmd keys arrive as
-- CSI-u super encodings decoded to <D-...> (see terminal configs). Without
-- this, Cmd never reaches terminal nvim and these silently do nothing.
--
-- (Retired 2026-09-14: the pre-0.12 <Esc>[9xx;1~ fallback maps lived here
-- alongside every live map above. Nothing sends those sequences anymore —
-- Ghostty and Kitty both emit CSI-u super encodings, which Neovim 0.12
-- decodes to <D-...> — so they were unmapped dead weight. Restore from
-- git history if a terminal without CSI-u ever shows up.)
require 'config.keymaps.general'
require 'config.keymaps.workspace'
require 'config.keymaps.terminal'
