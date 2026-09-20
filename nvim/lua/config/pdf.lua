-- PDF reader: Zathura (vim keys, TOC, search, multi-page) instead of
-- Preview.app. image.nvim stays as the in-buffer renderer for :edit /
-- Telescope opens, but it rasterizes a single static page, so the tree
-- and gx send every PDF to the real reader. Launched detached: quitting
-- nvim leaves the reader open.
local M = {}

---@param path string absolute file path
function M.open(path)
  if vim.fn.executable('zathura') == 1 then
    vim.fn.jobstart({ 'zathura', path }, { detach = true })
    return
  end
  vim.notify('zathura not installed (brew install zathura zathura-pdf-mupdf): using the OS viewer', vim.log.levels.WARN)
  vim.ui.open(path)
end

return M
