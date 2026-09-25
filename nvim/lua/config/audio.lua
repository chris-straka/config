-- Audio routing for the tree: mp3/wav/flac/... open in the sfx_player
-- popup (headless mpv over JSON IPC: real pause/seek/volume) instead
-- of a binary buffer. Mirrors config/image.lua + config/model3d.lua:
-- handles() routes, open() plays. The lazy spec lives in
-- lua/plugins/audio.lua.
local M = {}

-- Must mirror sfx_player's `extensions` setup (see lua/plugins/audio.lua).
local AUDIO_EXTS = {
  mp3 = true,
  wav = true,
  flac = true,
  ogg = true,
  oga = true,
  opus = true,
  m4a = true,
  aac = true,
  wma = true,
  aiff = true,
  aif = true,
  alac = true,
  ape = true,
  mka = true,
}

---@param path string absolute file path
---@return boolean true when the path is audio this module handles
function M.handles(path)
  local ext = path:lower():match('%.([%w%d]+)$')
  return ext ~= nil and AUDIO_EXTS[ext] or false
end

-- Force-loads the lazy plugin first: VeryLazy may not have fired for
-- `nvim song.mp3` straight from a shell. Mirrors config/tree.lua.
local function with_player()
  local ok_lazy, lazy = pcall(require, 'lazy')
  if ok_lazy then pcall(lazy.load, { plugins = { 'nvim.sfx_player' } }) end
  local ok, sfx = pcall(require, 'nvim.sfx_player')
  if not ok then
    vim.notify('sfx_player not loaded', vim.log.levels.WARN)
    return nil
  end
  return sfx
end

---@param path string absolute file path
function M.open(path)
  if vim.fn.executable('mpv') ~= 1 then
    vim.notify('mpv not installed (brew install mpv)', vim.log.levels.WARN)
    return
  end
  local sfx = with_player()
  if not sfx then return end
  local ok, err = pcall(sfx.open, path)
  if not ok then vim.notify('Audio open failed: ' .. tostring(err), vim.log.levels.WARN) end
end

-- Plays the file in the current buffer. The <leader>p map and the
-- AudioAutoOpen autocmd both funnel through here.
function M.open_current()
  local buf = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(buf)
  if path == '' or not M.handles(path) then
    vim.notify('Not an audio file', vim.log.levels.WARN)
    return
  end
  M.open(vim.fn.fnamemodify(path, ':p'))
end

return M
