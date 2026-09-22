-- Guarded entry to no-neck-pain's rebuild. Upstream init assumes the layout
-- it scanned is still alive, but tree open/close settles race its debounced
-- frames: by the time init runs, a recorded side window can be dead and
-- `move_sides` hard-errors (`Invalid window id`, ui.lua callback in the
-- trace). So: run init only when every recorded window is live, rescan once
-- when one is not, and skip the pass when still stale — the plugin's own
-- WinEnter/WinClosed scans re-fire init on the next move. Never raises.
local M = {}

---@param scope string
---@param init_fn function the original `main.init`
---@return boolean true when init ran
function M.init(scope, init_fn)
  local ok_state, state = pcall(require, 'no-neck-pain.state')
  if not ok_state or not state.enabled then return false end
  if type(init_fn) ~= 'function' then return false end
  local function live()
    for _, side in ipairs({ 'left', 'right', 'curr' }) do
      local ok, id = pcall(function() return state:get_side_id(side) end)
      if ok and id ~= nil and not vim.api.nvim_win_is_valid(id) then return false end
    end
    return true
  end
  if not live() then pcall(function() state:scan_layout(scope) end) end
  if not live() then return false end
  local ok = pcall(init_fn, scope)
  return ok
end

return M
