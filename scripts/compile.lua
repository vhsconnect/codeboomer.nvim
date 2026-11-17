-- Batch-compile the fnl/ tree to lua/, mirroring what nfnl's
-- :NfnlCompileAllFiles does, but without requiring the nfnl plugin on the
-- runtimepath — we drive the Fennel compiler vendored at lua/nfnl/nfnl/.
-- Conventions kept identical to nfnl:
--   * .fnlm macro modules are never compiled; they are only found via the
--     macro search path when another module does (import-macros ...)
--   * every output starts with a "-- [nfnl] <source>" header and ends with
--     a trailing newline
--   * a .lua file whose first lines carry no [nfnl] tag is never overwritten
--     (anything before the tag is preserved as an intentional prefix)
-- Run from the project root: nvim -l scripts/compile.lua

package.path = 'lua/nfnl/nfnl/?.lua;' .. package.path
local fennel = require('fennel')

-- The same search paths nfnl derives for a project root: the fnl/ tree
-- first, then the root itself; macros (.fnlm) before plain modules (.fnl).
fennel.path = '?.fnl;?/init.fnl;fnl/?.fnl;fnl/?/init.fnl'
fennel['macro-path'] = table.concat({
  '?.fnlm',
  '?/init.fnlm',
  '?/init-macros.fnlm',
  'fnl/?.fnlm',
  'fnl/?/init.fnlm',
  'fnl/?/init-macros.fnlm',
  '?.fnl',
  '?/init.fnl',
  '?/init-macros.fnl',
  'fnl/?.fnl',
  'fnl/?/init.fnl',
  'fnl/?/init-macros.fnl',
}, ';')

local failures = 0

--- @param path string
--- @return string
local function read(path)
  local file = assert(io.open(path, 'r'))
  local content = file:read('*a')
  file:close()
  return content
end

--- Like nfnl's header.read: look for the [nfnl] tag within the first few
--- lines of an existing destination.
--- @param path string
--- @return string|nil prefix to keep before the new header ('' for a fresh
---   file), or nil when the file exists but is not nfnl-tagged
local function header_prefix(path)
  local file = io.open(path, 'r')
  if not file then
    return ''
  end
  local prefix = {}
  local line = file:read('*l')
  local n = 1
  while line and n < 5 and not line:find('[nfnl]', 1, true) do
    prefix[#prefix + 1] = line .. '\n'
    line = file:read('*l')
    n = n + 1
  end
  file:close()
  if line and line:find('[nfnl]', 1, true) then
    return table.concat(prefix)
  end
  return nil
end

--- @param fnl_path string
local function compile_file(fnl_path)
  if fnl_path:sub(-5) == '.fnlm' then
    print(('  skip (macro module): %s'):format(fnl_path))
    return
  end
  local lua_path = fnl_path:gsub('^fnl/', 'lua/', 1):gsub('%.fnl$', '.lua')
  local ok, res = pcall(fennel.compileString, read(fnl_path), {
    filename = fnl_path,
    ['error-pinpoint'] = false,
  })
  if not ok then
    failures = failures + 1
    io.stderr:write(res .. '\n')
    return
  end
  local prefix = header_prefix(lua_path)
  if prefix == nil then
    failures = failures + 1
    io.stderr:write(lua_path .. ' is not tagged [nfnl]; delete it manually if you wish to compile into it\n')
    return
  end
  vim.fn.mkdir(vim.fs.dirname(lua_path), 'p')
  local file = assert(io.open(lua_path, 'w'))
  file:write(('%s-- [nfnl] %s\n%s\n'):format(prefix, fnl_path, res))
  file:close()
  print(('  compiled: %s -> %s'):format(fnl_path, lua_path))
end

-- The source-file-patterns from .nfnl.fnl, globbed and de-duplicated.
local seen = {}
local sources = {}
for _, pattern in ipairs({ 'fnl/*.fnl', 'fnl/**/*.fnl', 'fnl/*.fnlm', 'fnl/**/*.fnlm' }) do
  for _, fnl_path in ipairs(vim.fn.glob(pattern, false, true)) do
    if not seen[fnl_path] then
      seen[fnl_path] = true
      sources[#sources + 1] = fnl_path
    end
  end
end
table.sort(sources)

for _, fnl_path in ipairs(sources) do
  compile_file(fnl_path)
end

if failures > 0 then
  io.stderr:write(failures .. ' file(s) failed to compile\n')
  os.exit(1)
end
