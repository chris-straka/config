-- Mouse hover docs (VSCode-style tooltip): with mousemoveevent on, mouse
-- movement in normal mode runs on_mouse_move(), which requests LSP hover
-- for the word under the mouse and shows it in a float anchored at the
-- mouse. Moves within the same word are ignored; moving onto blank space
-- or out of a code window dismisses the float. K stays the keyboard way in.
local M = {}

-- Hover delay in ms: the mouse must rest on a word this long. VSCode-like,
-- and keeps slow servers from being spammed while sweeping across code.
M.delay = 250

-- Hover float width cap (columns). open_floating_preview() defaults its
-- wrap width to the current window width, so on a wide monitor the docs
-- span the whole screen (see screenshot). max_width caps both the window
-- and the wrap, keeping the tooltip a readable column. Read by the K
-- hover mapping in lua/plugins/lsp.lua — one value for both.
M.max_width = 80

-- Mouse position source (seam for tests).
M._mousepos = function() return vim.fn.getmousepos() end

local last_key = nil
local timer = nil
local float_win = nil

-- Dismiss the float and cancel a pending request. Safe to call anytime.
function M.close()
  if timer ~= nil then
    timer:stop()
    timer:close()
    timer = nil
  end
  if float_win ~= nil and vim.api.nvim_win_is_valid(float_win) then
    vim.api.nvim_win_close(float_win, true)
  end
  float_win = nil
end

local function word_at(text, col)
  if text == '' or col < 1 then return '' end
  local c = math.min(col, #text)
  if not text:sub(c, c):match('[%w_]') then return '' end
  local s = c
  while s > 1 and text:sub(s - 1, s - 1):match('[%w_]') do s = s - 1 end
  local e = c
  while e <= #text and text:sub(e, e):match('[%w_]') do e = e + 1 end
  return text:sub(s, e - 1)
end

-- Same empty-response rules as vim.lsp.buf.hover: MarkedString shapes with
-- no text carry no information.
local function is_empty_contents(c)
  if type(c) == 'string' then return #c == 0 end
  local v = vim.tbl_get(c, 'value') or vim.tbl_get(c, 1, 'value') or c[1] or ''
  return #v == 0
end

-- Ask every server for hover at the mouse position. Split out so the
-- scheduled path stays thin.
function M.request(bufnr, params, key)
  vim.lsp.buf_request_all(bufnr, 'textDocument/hover', params, function(results)
    M._on_results(results, key, bufnr)
  end)
end

-- Render hover results into a mouse-anchored float. Returns a status word.
function M._on_results(results, key, bufnr)
  if key ~= last_key then return 'stale' end
  if not vim.api.nvim_buf_is_valid(bufnr) then return 'dead-buffer' end
  local valid = {}
  for client_id, resp in pairs(results) do
    if resp.err == nil and resp.result ~= nil and resp.result.contents ~= nil
      and not is_empty_contents(resp.result.contents)
    then
      valid[#valid + 1] = { client_id = client_id, result = resp.result }
    end
  end
  -- Deliberately silent: unlike K, the mouse must never notify-spam.
  if #valid == 0 then return 'empty' end
  local util = vim.lsp.util
  local MarkupKind = vim.lsp.protocol.MarkupKind
  local contents, format = {}, MarkupKind.Markdown
  for _, item in ipairs(valid) do
    if #valid > 1 then
      local client = vim.lsp.get_client_by_id(item.client_id)
      contents[#contents + 1] = string.format('# %s', client and client.name or '?')
    end
    local c = item.result.contents
    if type(c) == 'table' and c.kind == MarkupKind.PlainText then
      local lines = vim.split(c.value or '', '\n', { trimempty = true })
      if #valid == 1 then
        format = MarkupKind.PlainText
        contents = lines
      else
        contents[#contents + 1] = '```'
        vim.list_extend(contents, lines)
        contents[#contents + 1] = '```'
      end
    else
      vim.list_extend(contents, util.convert_input_to_markdown_lines(c))
    end
    contents[#contents + 1] = '---'
  end
  contents[#contents] = nil
  local _, winid = util.open_floating_preview(contents, format, {
    relative = 'mouse',
    focus_id = 'textDocument/hover',
    close_events = { 'CursorMoved', 'CursorMovedI', 'InsertCharPre', 'BufLeave' },
    max_width = M.max_width,
  })
  float_win = winid
  return 'shown'
end

-- <MouseMove> entry point. Returns a status word (useful for tests).
function M.on_mouse_move()
  local mouse = M._mousepos()
  if mouse.winid == 0 or mouse.line == 0 or mouse.column == 0 then
    M.close()
    last_key = nil
    return 'no-window'
  end
  local ok, valid = pcall(vim.api.nvim_win_is_valid, mouse.winid)
  if not ok or not valid then
    M.close()
    last_key = nil
    return 'bad-window'
  end
  -- Hovering a float (e.g. the docs themselves): leave it alone so the
  -- tooltip can still be moused into and read.
  if vim.api.nvim_win_get_config(mouse.winid).relative ~= '' then return 'float-window' end
  local bufnr = vim.api.nvim_win_get_buf(mouse.winid)
  -- Tree, terminals, prompts and friends never get hover docs.
  if vim.bo[bufnr].buftype ~= '' then
    M.close()
    last_key = nil
    return 'special-buffer'
  end
  local text = vim.api.nvim_buf_get_lines(bufnr, mouse.line - 1, mouse.line, false)[1] or ''
  local word = word_at(text, mouse.column)
  if word == '' then
    M.close()
    last_key = nil
    return 'no-symbol'
  end
  local key = bufnr .. ':' .. mouse.line .. ':' .. word
  if key == last_key then return 'same-word' end
  last_key = key
  M.close()
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = 'textDocument/hover' })
  if #clients == 0 then
    last_key = nil
    return 'no-client'
  end
  local encoding = clients[1].offset_encoding or 'utf-16'
  local params = {
    textDocument = { uri = vim.uri_from_bufnr(bufnr) },
    position = {
      line = mouse.line - 1,
      -- getmousepos columns are 1-based bytes; servers want 0-based
      -- encoded characters.
      character = vim.str_utfindex(text, encoding, mouse.column - 1, false),
    },
  }
  timer = vim.uv.new_timer()
  timer:start(M.delay, 0, vim.schedule_wrap(function()
    timer:stop()
    timer:close()
    timer = nil
    M.request(bufnr, params, key)
  end))
  return 'scheduled'
end

return M
