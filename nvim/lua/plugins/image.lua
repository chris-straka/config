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
