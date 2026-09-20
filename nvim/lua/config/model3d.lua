-- 3D model viewer: f3d (keyboard-driven GLB/FBX/OBJ/...) instead of
-- opening binary mesh data in a buffer; .blend files go to Blender.
-- Launched detached: quitting nvim leaves the viewer open.
local M = {}

local VIEWER_EXTS = {
  glb = true,
  gltf = true,
  fbx = true,
  obj = true,
  stl = true,
  ply = true,
  dae = true,
  ['3ds'] = true,
  usd = true,
  usdz = true,
}

---@param path string absolute file path
---@return boolean true when the path is a 3D model this module handles
function M.handles(path)
  local ext = path:lower():match('%.([%w%d]+)$')
  if ext == 'blend' then
    return true
  end
  return ext ~= nil and VIEWER_EXTS[ext] or false
end

---@param path string absolute file path
function M.open(path)
  if path:lower():match('%.blend$') then
    vim.fn.jobstart({ 'open', '-a', 'Blender', path }, { detach = true })
    return
  end
  if vim.fn.executable('f3d') == 1 then
    vim.fn.jobstart({ 'f3d', path }, { detach = true })
    return
  end
  vim.notify('f3d not installed (brew install f3d): using the OS viewer', vim.log.levels.WARN)
  vim.ui.open(path)
end

return M
