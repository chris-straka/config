-- Audio playback: an mp3/wav/flac/... opened from the tree, :edit,
-- Telescope, or <leader>p plays in a floating popup (file info + live
-- timeline) instead of a binary buffer. Backend is headless mpv over
-- its JSON IPC socket: play/pause/seek/volume are gapless with no
-- process restarts, and closing the popup quits mpv (no orphans).
-- Popup keys: Space pauses, Left/Right seek, Up/Down volume, L cycles
-- the folder mode, >/< skips tracks, q/Esc closes. :SfxPlayerOpen
-- plays any path with completion; :SfxPlayerClose stops.
return {
  {
    'monok-robeto/nvim.sfx_player',
    event = 'VeryLazy',
    cond = function() return vim.fn.executable('mpv') == 1 end,
    config = function()
      require('nvim.sfx_player').setup({
        -- Auditioning default: the popup (and playback) closes when it
        -- loses focus. Set auto_close_on_leave = false to keep music
        -- playing while you work.
        -- Extensions are the plugin default, repeated so the coupling
        -- is visible: config/audio.lua AUDIO_EXTS must mirror this
        -- list (the tree routes on it before the plugin loads).
        extensions = {
          'mp3', 'wav', 'flac', 'ogg', 'oga', 'opus', 'm4a',
          'aac', 'wma', 'aiff', 'aif', 'alac', 'ape', 'mka',
        },
      })
    end,
  },
}
