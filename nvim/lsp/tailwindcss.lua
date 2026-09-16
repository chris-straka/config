-- Only attach where the project actually uses Tailwind: a tailwind or
-- PostCSS config, a package.json depending on tailwindcss (covers v4,
-- which needs no tailwind.config.* — including @tailwindcss/*), or a
-- mix/Gemfile lock mentioning tailwind. Plain git checkouts without any
-- of these get no root, hence no server.
--
-- Both keys matter: the nvim-lspconfig base defines root_dir as a
-- function with a `.git` fallback for v4, and a function root_dir wins
-- over root_markers in the merge — markers alone are ignored and the
-- server attaches in every git repo.
local markers = {
  'tailwind.config.js',
  'tailwind.config.cjs',
  'tailwind.config.mjs',
  'tailwind.config.ts',
  'tailwind.config.mts',
  'tailwind.config.cts',
  'postcss.config.js',
  'postcss.config.cjs',
  'postcss.config.mjs',
  'postcss.config.ts',
  -- Django layout (config lives under theme/static_src).
  'theme/static_src/tailwind.config.js',
  'theme/static_src/tailwind.config.cjs',
  'theme/static_src/tailwind.config.mjs',
  'theme/static_src/tailwind.config.ts',
  'theme/static_src/postcss.config.js',
}

-- First upward file under `names` whose contents mention `needle`
-- (plain substring), or nil. Every candidate is scanned so a nested
-- file without the dep never shadows one further up that has it.
local function mentioning(names, needle, fname)
  for _, path in ipairs(vim.fs.find(names, { path = fname, upward = true, type = 'file' })) do
    local f = io.open(path, 'r')
    if f then
      for line in f:lines() do
        if line:find(needle, 1, true) then
          f:close()
          return path
        end
      end
      f:close()
    end
  end
  return nil
end

local function strict_root(fname)
  if fname == '' then return nil end
  local hit = vim.fs.find(markers, { path = fname, upward = true, type = 'file' })[1]
  if hit then return vim.fs.dirname(hit) end
  hit = mentioning({ 'package.json', 'package.json5' }, 'tailwindcss', fname)
  if hit then return vim.fs.dirname(hit) end
  hit = mentioning({ 'mix.lock', 'Gemfile.lock' }, 'tailwind', fname)
  if hit then return vim.fs.dirname(hit) end
  return nil
end

return {
  root_markers = markers,
  root_dir = function(bufnr, on_dir)
    on_dir(strict_root(vim.api.nvim_buf_get_name(bufnr)))
  end,
}
