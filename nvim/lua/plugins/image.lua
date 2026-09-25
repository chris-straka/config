-- Image preview: opening an image file renders it in the buffer, and
-- Markdown images render inline. Ghostty implements Kitty's graphics
-- protocol, so the `kitty` backend just works (no ueberzug/sixel needed).
-- Eager on purpose: `hijack_file_patterns` must be armed before the
-- first file opens, so `nvim photo.png` from a shell renders too.
-- Needs the `magick` CLI (brew install imagemagick); without it the
-- plugin stays unloaded and images open as binary, as before.
--
-- Raw bytes hatch: a hijacked buffer shows the render, not the file.
-- SVG never hijacks (it is text you edit; Telescope still thumbnails
-- it). For the binary formats, <leader>ir flips the buffer between the
-- render and the raw bytes (then :HexToggle works on them too).
return {
  {
    '3rd/image.nvim',
    cond = function() return vim.fn.executable('magick') == 1 end,
    config = function()
      require('image').setup({
        backend = 'kitty',
        processor = 'magick_cli',
        -- PDF renders via ghostscript (brew install ghostscript): covers
        -- :edit / Telescope / harpoon opens (single static page). The
        -- tree and gx send PDFs to Zathura instead (see config/pdf.lua).
        hijack_file_patterns = { '*.png', '*.jpg', '*.jpeg', '*.gif', '*.webp', '*.avif', '*.bmp', '*.ico', '*.pdf' },
        -- Kitty graphics ignore window z-order, so an image in the main
        -- window bleeds through any float on top of it — including every
        -- toggleterm float. Overlap clearing hides images behind floats
        -- (toggleterm floats mask; never add them to the ignore list).
        window_overlap_clear_enabled = true,
      })
      -- Terminal-Insert gap: the overlap pass above only runs from the
      -- decoration provider, which bails outside Normal mode — and every
      -- toggleterm float lands in Terminal-Insert. So entering any
      -- terminal shallow-clears every image (the render goes away but the
      -- state stays, so they come back when the float closes). Not
      -- api.clear(): with no id that drops every image from state
      -- (non-shallow) and nothing would re-render afterwards.
      vim.api.nvim_create_autocmd({ 'TermEnter', 'BufEnter', 'WinEnter' }, {
        group = vim.api.nvim_create_augroup('ImageHideOnTerminal', { clear = true }),
        callback = function(ev)
          local buf = ev.buf
          if not vim.api.nvim_buf_is_valid(buf) then return end
          if vim.bo[buf].buftype ~= 'terminal' and vim.bo[buf].filetype ~= 'toggleterm' then return end
          local ok, api = pcall(require, 'image')
          if not ok then return end
          for _, img in ipairs(api.get_images()) do
            pcall(function() img:clear(true) end)
          end
        end,
      })
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('ImageRawView', { clear = true }),
        pattern = 'image_nvim',
        callback = function(ev)
          vim.keymap.set('n', '<leader>ir', function()
            if vim.bo[ev.buf].modified then
              vim.notify('Write or discard first: toggle reloads the file', vim.log.levels.WARN)
              return
            end
            local image = require('image')
            -- disable() clears every render and makes the hijack bail,
            -- so :edit! reloads raw bytes; enable() re-arms it.
            if image.is_enabled() then image.disable() else image.enable() end
            vim.cmd('edit!')
          end, { buffer = ev.buf, desc = 'Image render <-> raw bytes' })
        end,
      })
    end,
  },
}
