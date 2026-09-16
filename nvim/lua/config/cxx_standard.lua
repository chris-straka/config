-- C++ standard for the statusline: answers "C++20?" per file without
-- ever shelling out on the statusline path. Order: the file's own -std=
-- flag in compile_commands.json (headers are often absent from the db,
-- so a miss falls through), then CMAKE_CXX_STANDARD / cxx_std_XX in the
-- nearest upward CMakeLists.txt, else nil (plain C++ label). Everything
-- is cached (the db keyed by mtime), so after the first lookup a refresh
-- is a few table hits.
local M = {}

---@type table<string, { mtime: integer, by_file: table<string, string> }>
local cc_parsed = {}
---@type table<string, string|false> upward search hits by start dir
local cc_found = {}
---@type table<string, string|false> cmake hits by directory
local cmake_found = {}

---@param ver string|nil
---@return string|nil ver when it names a known standard
local function valid_std(ver)
  if ver == '98' or ver == '03' or ver == '11' or ver == '14' then
    return ver
  end
  if ver == '17' or ver == '20' or ver == '23' or ver == '26' then
    return ver
  end
  return nil
end

---Map a -std= value to its two-digit standard: c++20 -> '20',
---gnu++2b -> '23'. C flags (c11) and unknown values give nil.
---@param value string text after -std=
---@return string|nil
local function std_from_value(value)
  local ver = value:match('^%w*%+%+(%w+)$')
  if not ver then return nil end
  if ver == '2a' then return '20' end
  if ver == '2b' then return '23' end
  if ver == '2c' then return '26' end
  return valid_std(ver)
end

---First -std= flag in a compile entry: raw command strings are scanned
---as text (no word-splitting, so quoted paths cannot hide the flag),
---argument vectors element by element.
---@param entry table one compile_commands.json entry
---@return string|nil two-digit standard
local function std_from_entry(entry)
  if type(entry.arguments) == 'table' then
    for _, arg in ipairs(entry.arguments) do
      if type(arg) == 'string' and arg:sub(1, 5) == '-std=' then
        local std = std_from_value(arg:sub(6))
        if std then return std end
      end
    end
    return nil
  end
  if type(entry.command) ~= 'string' then return nil end
  local value = entry.command:match('%-std=([^%s]+)')
  return value and std_from_value(value) or nil
end

---@param entry table one compile_commands.json entry
---@return string|nil normalized path of the entry's file
local function entry_file(entry)
  if type(entry.file) ~= 'string' or entry.file == '' then
    return nil
  end
  if entry.file:sub(1, 1) == '/' then return entry.file end
  if type(entry.directory) ~= 'string' or entry.directory == '' then
    return nil
  end
  return vim.fn.simplify(entry.directory .. '/' .. entry.file)
end

---@param path string
---@return integer mtime seconds, 0 when the file is missing
local function mtime_of(path)
  local stat = vim.uv.fs_stat(path)
  local mtime = stat and stat.mtime
  return (mtime and mtime.sec) or 0
end

---@param cc string compile_commands.json path
---@return table<string, string> standard by entry file path
local function parse_cc(cc)
  local mtime = mtime_of(cc)
  local cached = cc_parsed[cc]
  if cached and cached.mtime == mtime then return cached.by_file end
  local by_file = {}
  local f = io.open(cc, 'r')
  if f then
    local text = f:read('*a')
    f:close()
    local ok, db = pcall(vim.json.decode, text)
    if ok and type(db) == 'table' then
      for _, entry in ipairs(db) do
        if type(entry) == 'table' then
          local path = entry_file(entry)
          if path and not by_file[path] then
            local std = std_from_entry(entry)
            if std then by_file[path] = std end
          end
        end
      end
    end
  end
  cc_parsed[cc] = { mtime = mtime, by_file = by_file }
  return by_file
end

---@param file string
---@return string[] ancestor directories, deepest first (excludes '/')
local function ancestors(file)
  local dirs = {}
  local dir = vim.fn.fnamemodify(file, ':p:h')
  while dir ~= '' and dir ~= '/' do
    dirs[#dirs + 1] = dir
    local parent = vim.fn.fnamemodify(dir, ':h')
    if parent == dir then break end
    dir = parent
  end
  return dirs
end

---Upward compile_commands.json search: DIR/compile_commands.json, then
---DIR/build/compile_commands.json (the usual CMake layout), per level.
---@param dirs string[]
---@return string|nil db path
local function find_cc(dirs)
  for _, dir in ipairs(dirs) do
    local hit = cc_found[dir]
    if hit == nil then
      local plain = dir .. '/compile_commands.json'
      local built = dir .. '/build/compile_commands.json'
      if vim.uv.fs_stat(plain) then
        hit = plain
      elseif vim.uv.fs_stat(built) then
        hit = built
      else
        hit = false
      end
      cc_found[dir] = hit
    end
    if hit then return hit end
  end
  return nil
end

---@param dirs string[]
---@return string|nil two-digit standard from the nearest CMakeLists.txt
local function find_cmake_std(dirs)
  for _, dir in ipairs(dirs) do
    local hit = cmake_found[dir]
    if hit == nil then
      hit = false
      local f = io.open(dir .. '/CMakeLists.txt', 'r')
      if f then
        local text = f:read('*a')
        f:close()
        local ver = text:match('CMAKE_CXX_STANDARD%s+(%d%d)')
          or text:match('cxx_std_(%d%d)')
        if valid_std(ver) then hit = ver end
      end
      cmake_found[dir] = hit
    end
    if hit then return hit end
  end
  return nil
end

---@param file string absolute file path, '' for unnamed buffers
---@return string|nil two-digit C++ standard, nil when nothing declares one
function M.std_for_file(file)
  if file == '' then return nil end
  local dirs = ancestors(file)
  local cc = find_cc(dirs)
  if cc then
    local by_file = parse_cc(cc)
    if by_file[file] then return by_file[file] end
    local resolved = vim.fn.resolve(file)
    if by_file[resolved] then return by_file[resolved] end
  end
  return find_cmake_std(dirs)
end

---@return string statusline label for the current buffer
function M.label()
  local std = M.std_for_file(vim.api.nvim_buf_get_name(0))
  return std and ('C++' .. std) or 'C++'
end

return M
