package.path = 'lua/nfnl/nfnl/?.lua;' .. package.path
local fennel = require('fennel')

local src_root = 'test/fnl'
local out_root = 'test/lua'

local busted_globals = {
  'describe',
  'it',
  'before_each',
  'after_each',
  'setup',
  'teardown',
  'pending',
}

local allowed_globals = vim.list_extend(vim.tbl_keys(_G), busted_globals)

--- @param path string
--- @return string
local function read(path)
  local file = assert(io.open(path, 'r'))
  local content = file:read('*a')
  file:close()
  return content
end

vim.fn.delete(out_root, 'rf')

for _, fnl_path in ipairs(vim.fn.glob(src_root .. '/**/*.fnl', false, true)) do
  local lua_path = out_root .. fnl_path:sub(#src_root + 1):gsub('%.fnl$', '.lua')
  local lua_code = fennel.compileString(read(fnl_path), {
    filename = fnl_path,
    allowedGlobals = allowed_globals,
    correlate = true,
  })
  vim.fn.mkdir(vim.fs.dirname(lua_path), 'p')
  local file = assert(io.open(lua_path, 'w'))
  file:write(lua_code)
  file:close()
end
