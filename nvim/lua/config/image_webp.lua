-- WebP workaround for image.nvim (wired in lua/plugins/image.lua).
-- Two upstream gaps, both from assuming GIF is the only multi-frame format
-- and plain VP8 the only WebP layout:
-- 1. The fast parser skips the chunk FourCC and reads VP8 frame offsets
--    unconditionally. VP8X (animated, or stills with EXIF/XMP/alpha) and
--    VP8L (lossless) store dimensions elsewhere, so e.g. a 1600x900 VP8X
--    reports 768x3 and renders squished into a few rows at the top.
-- 2. convert/transform only pin `[0]` (first frame) for GIF, so animated
--    WebP converts into `out-0.png`, `out-1.png`, ... while the caller
--    waits on `out.png`, which never appears.
local M = {}

-- Canvas dimensions for all three WebP layouts, or nil if unparseable.
local function webp_dimensions(path)
  local file = io.open(path, 'rb')
  if not file then return nil end
  local head = file:read(30)
  file:close()
  if not head or #head < 30 then return nil end
  if head:sub(1, 4) ~= 'RIFF' or head:sub(9, 12) ~= 'WEBP' then return nil end
  local b = { head:byte(1, #head) }
  local fourcc = head:sub(13, 16)
  if fourcc == 'VP8 ' then
    if b[24] ~= 0x9D or b[25] ~= 0x01 or b[26] ~= 0x2A then return nil end
    local w, h = b[27] + (b[28] % 64) * 256, b[29] + (b[30] % 64) * 256
    if w == 0 or h == 0 then return nil end
    return { width = w, height = h }
  elseif fourcc == 'VP8L' then
    if b[21] ~= 0x2F then return nil end
    local u = b[22] + b[23] * 256 + b[24] * 65536 + b[25] * 16777216
    return { width = (u % 16384) + 1, height = (math.floor(u / 16384) % 16384) + 1 }
  elseif fourcc == 'VP8X' then
    local w = b[25] + b[26] * 256 + b[27] * 65536
    local h = b[28] + b[29] * 256 + b[30] * 65536
    return { width = w + 1, height = h + 1 }
  end
  return nil
end

function M.apply()
  local ok_dims, dims = pcall(require, 'image/utils/dimensions')
  if not ok_dims or dims._webp_workaround then return end
  dims._webp_workaround = true
  local magic = require('image/utils/magic')
  local fast = dims.get_dimensions
  dims.get_dimensions = function(path)
    -- Unparseable files fall through to the upstream parser, preserving
    -- its exact behavior (including its identify fallback) for anything
    -- that is not a well-formed WebP.
    if magic.detect_format(path) == 'webp' then return webp_dimensions(path) or fast(path) end
    return fast(path)
  end
  local ok_cli, cli = pcall(require, 'image/processors/magick_cli')
  if not ok_cli or cli._webp_workaround then return end
  cli._webp_workaround = true
  local transform, convert = cli.transform, cli.convert_to_png
  cli.transform = function(path, request, output_path, callback)
    if (request.source_format or ''):lower() == 'webp' then path = path .. '[0]' end
    return transform(path, request, output_path, callback)
  end
  cli.convert_to_png = function(path, output_path)
    if cli.get_format(path) == 'webp' then path = path .. '[0]' end
    return convert(path, output_path)
  end
end

return M
