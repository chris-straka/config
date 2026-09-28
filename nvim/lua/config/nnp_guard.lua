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

---Register overseer's sidebar as a no-neck-pain integration so the task
---list coexists with the pads (same as NvimTree): unregistered, the
---sidebar counts as a second main window and the gutters go away while
---it is open. Pokes plugin internals — the constants template, which
---every layout scan copies into the per-tab state — so the entry
---survives rescans by construction. Same as the init guard above:
---revisit on plugin updates past 0df6659.
---@return boolean true when the entry is present
function M.register_overseer()
  local ok_c, constants = pcall(require, 'no-neck-pain.util.constants')
  if not ok_c or type(constants.INTEGRATIONS) ~= 'table' then return false end
  if constants.INTEGRATIONS.overseer ~= nil then return true end
  constants.INTEGRATIONS.overseer = {
    -- startswith match: covers OverseerList and OverseerOutput.
    fileTypePattern = 'overseer',
    -- Unused by this version (kept for shape parity with the builtins).
    close = 'OverseerClose',
    open = 'OverseerOpen',
  }
  -- Width math looks the entry up in the user config too
  -- (ui.get_side_width indexes .position); without this the lookup
  -- crashes on a nil the moment the sidebar opens. Position none is
  -- the DAPUI precedent for panels that are not left/right sidebars,
  -- so no pad is ever shrunk for it. Runtime patch, not setup opts,
  -- so the builtin entries merge untouched.
  local app = _G.NoNeckPain
  if type(app) == 'table' and type(app.config) == 'table' and type(app.config.integrations) == 'table' then
    app.config.integrations.overseer = { position = 'none', reopen = true }
  end
  return true
end

return M
