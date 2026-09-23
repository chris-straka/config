-- Image routing for the tree: formats image.nvim hijacks open in a buffer
-- (rendered via Kitty graphics, Ghostty speaks it); the rest a buffer
-- cannot render, so they still go to the OS viewer (Preview.app).
-- image.nvim stays as the in-buffer renderer for :edit / Telescope opens.
local M = {}

local VIEWER_EXTS = {
  png = true,
  jpg = true,
  jpeg = true,
  gif = true,
  webp = true,
  avif = true,
  bmp = true,
  tif = true,
  tiff = true,
  ico = true,
  svg = true,
}

-- Must mirror image.nvim's hijack_file_patterns (see lua/plugins/image.lua):
-- svg is text you edit, tif/tiff never hijack, so those stay external.
local IN_BUFFER_EXTS = {
  png = true,
  jpg = true,
  jpeg = true,
  gif = true,
  webp = true,
  avif = true,
  bmp = true,
  ico = true,
}

---@param path string absolute file path
---@return boolean true when the path is an image this module handles
function M.handles(path)
  local ext = path:lower():match('%.([%w%d]+)$')
  return ext ~= nil and VIEWER_EXTS[ext] or false
end

---@param path string absolute file path
---@return boolean true when the image renders in a buffer (not externally)
function M.in_buffer(path)
  local ext = path:lower():match('%.([%w%d]+)$')
  return ext ~= nil and IN_BUFFER_EXTS[ext] or false
end

---@param path string absolute file path
function M.open(path)
  vim.ui.open(path)
end

return M
