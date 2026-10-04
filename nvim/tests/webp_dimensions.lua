-- WebP dimensions: VP8X/VP8L stills must report true dimensions, not the
-- garbage upstream's fast parser reads (a 1600x900 VP8X reports 768x3 and
-- renders squished). Run: nvim --headless --noplugin -l ~/.config/nvim/tests/webp_dimensions.lua
local home = vim.env.HOME
vim.opt.rtp:prepend(home .. '/.config/nvim')
vim.opt.rtp:prepend(home .. '/.local/share/nvim/lazy/image.nvim')

if vim.fn.executable('magick') ~= 1 then
  print('webp_dimensions: SKIP (no magick)')
  return
end
if not pcall(require, 'image/utils/dimensions') then
  print('webp_dimensions: SKIP (no image.nvim)')
  return
end

local failures = 0
local function check(name, ok)
  if ok then
    print('PASS: ' .. name)
  else
    failures = failures + 1
    print('FAIL: ' .. name)
  end
end

require('config.image_webp').apply()
local dims = require('image/utils/dimensions')
local proc = require('image/processors/magick_cli')

local dir = vim.fn.tempname()
vim.fn.mkdir(dir, 'p')
local function magick(args)
  local rc = os.execute('magick ' .. args)
  assert(rc == 0 or rc == true, 'magick failed: ' .. args)
end
magick('-size 1600x900 xc:skyblue +profile "*" ' .. dir .. '/vp8.webp')
magick('-size 1600x900 xc:skyblue +profile "*" -define webp:lossless=true ' .. dir .. '/vp8l.webp')
magick('-size 1600x900 xc:skyblue ' .. dir .. '/a.png')
magick('-size 1600x900 xc:coral ' .. dir .. '/b.png')
magick('-delay 50 ' .. dir .. '/a.png ' .. dir .. '/b.png ' .. dir .. '/vp8x.webp')

local function fourcc(path)
  local f = assert(io.open(path, 'rb'))
  f:seek('set', 12)
  local cc = f:read(4)
  f:close()
  return cc
end
check('vp8 fixture is plain VP8', fourcc(dir .. '/vp8.webp') == 'VP8 ')
check('vp8l fixture is lossless VP8L', fourcc(dir .. '/vp8l.webp') == 'VP8L')
check('vp8x fixture is extended VP8X', fourcc(dir .. '/vp8x.webp') == 'VP8X')

local function sized(path)
  local d = proc.get_dimensions(path)
  return d and d.width == 1600 and d.height == 900
end
check('VP8 reports 1600x900', sized(dir .. '/vp8.webp'))
check('VP8L reports 1600x900', sized(dir .. '/vp8l.webp'))
check('VP8X reports 1600x900', sized(dir .. '/vp8x.webp'))
check('png fast path untouched', sized(dir .. '/a.png'))
local fast_vp8x = dims.get_dimensions(dir .. '/vp8x.webp')
check('fast parser reads VP8X canvas directly', fast_vp8x and fast_vp8x.width == 1600 and fast_vp8x.height == 900)
local converted = proc.convert_to_png(dir .. '/vp8x.webp', dir .. '/c.png')
check('animated webp converts to one png', vim.fn.filereadable(converted) == 1)
local done, result = false, nil
proc.transform(
  dir .. '/vp8x.webp',
  {
    source_format = 'webp',
    output_format = 'png',
    target_width = 800,
    target_height = 450,
  },
  dir .. '/t.png',
  function(res)
    result, done = res, true
  end
)
vim.wait(15000, function() return done end)
check('animated webp transforms to one png', done and result.ok and vim.fn.filereadable(dir .. '/t.png') == 1)
local scaled = vim.fn.filereadable(dir .. '/t.png') == 1 and proc.get_dimensions(dir .. '/t.png') or nil
check('scaled png is 800x450', scaled and scaled.width == 800 and scaled.height == 450)

vim.fn.delete(dir, 'rf')
if failures > 0 then
  print(failures .. ' FAILURES')
  os.exit(1)
end
print('webp_dimensions: all pass')
