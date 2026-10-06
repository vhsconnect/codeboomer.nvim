-- [nfnl] fnl/codeboomer/agent.fnl
vim = vim
local git = require("codeboomer.git")
local review = require("codeboomer.review")
local M = {}
local shim_path = (vim.fn.stdpath("data") .. "/codeboomer-agent")
M["reply-instructions"] = function()
  return ("Reply to each thread above. Keep your responses in the thread short and consice and use the harnass to provide detail. Answer in the thread with: " .. shim_path .. " reply <thread-id> <text>\n")
end
local usage = "usage: codeboomer-agent reply <thread-id> <text>\n       codeboomer-agent comment <file> <line>[-<line>] <text>\n       codeboomer-agent file-comment <file> <text>"
local help_text = (usage .. "\n\n" .. "codeboomer-agent posts a review agent's comments into codeboomer's\n" .. "comment threads from outside nvim \226\128\148 thread ids arrive inline\n" .. "wherever a review's annotations were sent to you.\n\n" .. "verbs:\n" .. "  reply <thread-id> <text...>   reply to an existing, open thread.\n" .. "                                Fails if the thread doesn't exist or\n" .. "                                is resolved/deleted.\n" .. "  comment <file> <line>[-<line>] <text...>\n" .. "                                start a new thread on a line or an\n" .. "                                inclusive line range of <file>.\n" .. "  file-comment <file> <text...> start a new thread on <file> as a\n" .. "                                whole.\n" .. "  help | -h | --help            show this message.\n\n" .. "<file> is relative to the current directory's work tree (absolute\n" .. "paths inside it work too); lines count from 1 as the file reads on\n" .. "disk \226\128\148 comment on committed code: a range edited since HEAD can't\n" .. "be promoted to the PR. <text> is every argument after the last\n" .. "positional one, joined with spaces \226\128\148 no quoting needed.\n\n" .. "exit status: 0 on success, 1 on failure (the message says why).\n")
local function resolve_file(path)
  local root = git["work-root"](vim.fn.getcwd())
  local real_root
  if root then
    real_root = vim.uv.fs_realpath(root)
  else
    real_root = nil
  end
  local joined
  if vim.startswith(path, "/") then
    joined = path
  else
    joined = vim.fs.joinpath(vim.fn.getcwd(), path)
  end
  local real = vim.uv.fs_realpath(joined)
  local stat
  if real then
    stat = vim.uv.fs_stat(real)
  else
    stat = nil
  end
  if not real_root then
    return nil, "not inside a git work tree"
  elseif not real then
    return nil, ("no such file: " .. path)
  elseif not vim.startswith(real, (real_root .. "/")) then
    return nil, ("file is outside the work tree: " .. path)
  else
    local _5_
    do
      local t_4_ = stat
      if (nil ~= t_4_) then
        t_4_ = t_4_.type
      else
      end
      _5_ = t_4_
    end
    if ("file" ~= _5_) then
      return nil, ("not a file: " .. path)
    else
      return {rel = real:sub((2 + #real_root)), lines = vim.fn.readfile(real)}
    end
  end
end
local function parse_range(spec)
  local single = tonumber(string.match((spec or ""), "^(%d+)$"))
  local from, to = string.match((spec or ""), "^(%d+)-(%d+)$")
  if single then
    return single, single
  else
    return tonumber(from), tonumber(to)
  end
end
local no_session = "no review session \226\128\148 run from a checked-out branch"
local function reply(args)
  local thread_id = tonumber(args[2])
  local body = table.concat(vim.list_slice(args, 3), " ")
  if not thread_id then
    return false, "thread id must be a number"
  elseif (body == "") then
    return false, "missing answer text"
  else
    local id = review["agent-reply"](thread_id, body)
    if id then
      return true, string.format("posted reply to thread #%d (comment %d)", thread_id, id)
    else
      return false, "reply rejected"
    end
  end
end
local function line_comment(args)
  local file, err = resolve_file((args[2] or ""))
  local from, to = parse_range(args[3])
  local body = table.concat(vim.list_slice(args, 4), " ")
  if not file then
    return false, err
  elseif not from then
    return false, "lines must look like 12 or 12-18"
  elseif ((from < 1) or (to < from) or (to > #file.lines)) then
    return false, string.format("lines %d-%d out of range \226\128\148 %s has %d lines", from, to, file.rel, #file.lines)
  elseif (body == "") then
    return false, "missing comment text"
  else
    local sid = review["ensure-session"]()
    local snapshot = table.concat(vim.list_slice(file.lines, from, to), "\n")
    if not sid then
      return false, no_session
    else
      return true, string.format("opened thread #%d on %s:%d-%d", review["agent-comment"](sid, file.rel, from, to, snapshot, body), file.rel, from, to)
    end
  end
end
local function file_comment(args)
  local file, err = resolve_file((args[2] or ""))
  local body = table.concat(vim.list_slice(args, 3), " ")
  if not file then
    return false, err
  elseif (body == "") then
    return false, "missing comment text"
  else
    local sid = review["ensure-session"]()
    if not sid then
      return false, no_session
    else
      return true, string.format("opened thread #%d on %s", review["agent-file-comment"](sid, file.rel, body), file.rel)
    end
  end
end
local verbs = {reply = reply, comment = line_comment, ["file-comment"] = file_comment}
M.run = function(args)
  local verb = verbs[(args[1] or "")]
  if verb then
    return verb(args)
  else
    return false, "expected reply, comment or file-comment as the first argument"
  end
end
M.main = function()
  local args = vim.split((os.getenv("CODEBOOMER_AGENT_ARGS") or ""), " ", {trimempty = true})
  local verb = args[1]
  if (not verb or (verb == "help") or (verb == "-h") or (verb == "--help")) then
    print(help_text)
    return os.exit(0, true)
  else
    local ok, msg = M.run(args)
    if ok then
      print(("codeboomer-agent: " .. msg))
      return os.exit(0, true)
    else
      print(("codeboomer-agent: " .. msg .. "\n" .. usage .. "\nrun `codeboomer-agent help` for details"))
      return os.exit(1, true)
    end
  end
end
local function shim_content()
  local entry
  do
    local t_18_ = vim.api.nvim_get_runtime_file("plugin/codeboomer.lua", false)
    if (nil ~= t_18_) then
      t_18_ = t_18_[1]
    else
    end
    entry = t_18_
  end
  if entry then
    local root = vim.fs.dirname(vim.fs.dirname(entry))
    local ld = (os.getenv("LD_LIBRARY_PATH") or "")
    return string.format("#!/usr/bin/env bash\n# codeboomer-agent \226\128\148 post review comments from outside nvim.\n# GENERATED by codeboomer.nvim on load \226\128\148 edits are overwritten.\nset -euo pipefail\nexport CODEBOOMER_PATH='%s'\nexport LD_LIBRARY_PATH='%s'\nexport CODEBOOMER_AGENT_ARGS=\"$*\"\nexec nvim --headless -u NONE --cmd \"set rtp^=${CODEBOOMER_PATH}\" -c 'lua require(\"codeboomer.agent\").main()' -c 'qa!'\n", root, ld)
  else
    return nil
  end
end
M["ensure-shim"] = function()
  local content = shim_content()
  if content then
    local lines = vim.split(content, "\n", {plain = true})
    local ok, existing = pcall(vim.fn.readfile, shim_path)
    local same = (ok and (type(existing) == "table") and (table.concat((existing or {}), "\n") == table.concat(lines, "\n")))
    if not same then
      vim.fn.writefile(lines, shim_path)
      return pcall(vim.loop.fs_chmod, shim_path, 493)
    else
      return nil
    end
  else
    return nil
  end
end
M["ensure-shim"]()
return M
