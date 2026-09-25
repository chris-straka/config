-- Unit test for config/audio.lua (no framework, plain asserts).
-- Run: nvim --headless --noplugin -l ~/.config/nvim/tests/audio_opener.lua
local nvim = vim.env.HOME .. '/.config/nvim'
vim.opt.rtp:prepend(nvim)

local failures = 0
local function check(name, ok)
  if ok then
    print('PASS: ' .. name)
  else
    failures = failures + 1
    print('FAIL: ' .. name)
  end
end

local audio = require('config.audio')
check('module exposes open', type(audio.open) == 'function')
check('module exposes open_current', type(audio.open_current) == 'function')
check('mp3 handled', audio.handles('/tmp/track.mp3'))
check('WAV handled (case-insensitive)', audio.handles('/tmp/HIT.WAV'))
check('flac handled', audio.handles('/tmp/a.flac'))
check('ogg handled', audio.handles('/tmp/a.ogg'))
check('m4a handled', audio.handles('/tmp/a.m4a'))
check('rs not handled', not audio.handles('/tmp/main.rs'))
check('Godot mp3.import sidecar not handled', not audio.handles('/tmp/x.mp3.import'))
check('extensionless not handled', not audio.handles('/tmp/Makefile'))
check('dotfile without ext not handled', not audio.handles('/tmp/.gitignore'))

if failures > 0 then
  print(failures .. ' FAILURES')
  os.exit(1)
end
print('audio_opener: all pass')
