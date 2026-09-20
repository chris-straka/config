-- Image viewer: OS viewer (Preview.app on macOS) instead of opening raster
-- data in a buffer from the tree. image.nvim stays as the in-buffer renderer
-- for :edit / Telescope opens. vim.ui.open returns immediately, so Space
-- shows the image while the cursor stays in the tree.
local M = {}

local VIEWER_EXTS = {
  png = true,
  jpg = true,
  jpeg = true,
  gif = true,
  webp = true,
  bmp = true,
  tif = true,
  tiff = true,
  ico = true,
  svg = true,
}

---@param path string absolute file path
---@return boolean true when the path is an image this module handles
function M.handles(path)
  local ext = path:lower():match('%.([%w%d]+)$')
  return ext ~= nil and VIEWER_EXTS[ext] or false
end

---@param path string absolute file path
function M.open(path)
  vim.ui.open(path)
end

return M
