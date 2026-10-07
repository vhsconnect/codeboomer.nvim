-- [nfnl] fnl/codeboomer/sidebar.fnl
vim = vim
local review = require("codeboomer.review")
local input = require("codeboomer.input")
local git = require("codeboomer.git")
local github = require("codeboomer.github")
local M = {}
local augroup_name = "codeboomer-review-pane"
local pane_buf_name = "codeboomer://review-comments"
local extmark_ns = vim.api.nvim_create_namespace("codeboomer-review-pane")
local flash_ns = vim.api.nvim_create_namespace("codeboomer-review-flash")
local flash_ms = 2000
local pane_width = 40
local pane_keys_footer = {("\226\148\128\226\148\128 keys " .. string.rep("\226\148\128", (pane_width - 8))), "r reply \194\183 a agent \194\183 d delete", "p promote \194\183 e edit \194\183 f refresh", "q resolve \194\183 n/N thread \194\183 z execute"}
local rest_ms = 100
local db_refresh_ms = 5000
local pane_win = nil
local threads_by_path = {}
local all_threads = {}
local timer_id = nil
local db_refresh_timer = nil
local pane_source_win = nil
local pane_path = nil
local current_thread = nil
local pane_header_rows = {}
local function thread_hl(index)
  local groups = {"Title", "Special", "String", "Function"}
  return groups[(1 + ((index - 1) % #groups))]
end
local function normal_buf(bufnr)
  local _2_
  do
    local t_1_ = vim.bo
    if (nil ~= t_1_) then
      t_1_ = t_1_[bufnr]
    else
    end
    if (nil ~= t_1_) then
      t_1_ = t_1_.buftype
    else
    end
    _2_ = t_1_
  end
  return ("" == (_2_ or ""))
end
local function source_win_3f(win)
  local buf = vim.api.nvim_win_get_buf(win)
  local name = vim.api.nvim_buf_get_name(buf)
  local _6_
  do
    local t_5_ = vim.api.nvim_win_get_config(win)
    if (nil ~= t_5_) then
      t_5_ = t_5_.relative
    else
    end
    _6_ = t_5_
  end
  return (("" == (_6_ or "")) and normal_buf(buf) and ("" ~= name) and (1 == vim.fn.filereadable(name)) and (nil ~= git["work-root"](name)))
end
local rel_path_cache = {}
local function buf_rel_path(bufnr)
  local or_8_ = rel_path_cache[bufnr]
  if not or_8_ then
    local p = git["rel-path"](vim.api.nvim_buf_get_name(bufnr))
    rel_path_cache[bufnr] = p
    or_8_ = p
  end
  return or_8_
end
local function source_buf_name()
  local cur = vim.api.nvim_get_current_win()
  local via_source = not normal_buf(vim.api.nvim_win_get_buf(cur))
  local win
  if (via_source and pane_source_win and vim.api.nvim_win_is_valid(pane_source_win)) then
    win = pane_source_win
  else
    win = cur
  end
  local buf = vim.api.nvim_win_get_buf(win)
  if normal_buf(buf) then
    return vim.api.nvim_buf_get_name(buf)
  else
    return nil
  end
end
local function source_session()
  local name = source_buf_name()
  if name then
    return review["session-for"](name)
  else
    return nil
  end
end
local function _13_()
  local t_14_ = source_session()
  if (nil ~= t_14_) then
    t_14_ = t_14_.id
  else
  end
  return t_14_
end
M["session-id"] = _13_
local function covers_3f(t, line)
  return (t.line_start and t.line_end and (line >= t.line_start) and (line <= t.line_end))
end
local function threads_at(path, line)
  local found = nil
  for _, t in ipairs((threads_by_path[path] or {})) do
    if found then break end
    if covers_3f(t, line) then
      found = t
    else
    end
  end
  if found then
    return {found}
  else
    return {}
  end
end
local function fresh(t)
  local out = nil
  for _, th in ipairs(all_threads) do
    if out then break end
    if (t and ((th.id or 0) == (t.id or 0))) then
      out = th
    else
    end
  end
  return out
end
local function index_of(t)
  local found = nil
  for i, th in ipairs(all_threads) do
    local or_19_ = found
    if not or_19_ then
      if (t and (th.id == t.id)) then
        or_19_ = (i - 1)
      else
        or_19_ = nil
      end
    end
    found = or_19_
  end
  return found
end
local function ensure_current()
  if not fresh(current_thread) then
    current_thread = all_threads[1]
    return nil
  else
    return nil
  end
end
local function stamp_thread(t)
  local twin = review.twin((t.id or 0))
  if twin then
    t["twin-kind"] = twin.kind
  else
    t["twin-kind"] = nil
  end
  t.conversation = review["conversation-comments"]((t.id or 0))
  for _, c in ipairs((t.conversation or {})) do
    local _24_
    do
      local t_23_ = review["comment-author"](c)
      if (nil ~= t_23_) then
        t_23_ = t_23_.name
      else
      end
      _24_ = t_23_
    end
    c["author-name"] = (_24_ or "unknown")
  end
  if t.anchor_commit then
    t["anchor-sha"] = review["commit-sha"](t.anchor_commit)
  else
    t["anchor-sha"] = nil
  end
  return nil
end
local map_version = 0
local rendered_sig = nil
local function conv_sig(t)
  local sig = ""
  for _, c in ipairs((t.conversation or {})) do
    sig = (sig .. tostring((c.id or 0)) .. ",")
  end
  return sig
end
local function map_sig()
  local sig = ""
  for _, t in ipairs(all_threads) do
    sig = (sig .. tostring((t.id or 0)) .. ":" .. conv_sig(t) .. ";")
  end
  return sig
end
local function short_sha(sha)
  if (sha and (#sha >= 7)) then
    return sha:sub(1, 7)
  else
    return (sha or "?")
  end
end
local function thread_header(base, t)
  local status
  local _28_
  if (t.gh_outdated and ((t.gh_outdated or 0) > 0)) then
    _28_ = ", outdated"
  else
    _28_ = nil
  end
  local _30_
  if ("review" == (t["twin-kind"] or "local")) then
    _30_ = " \194\183 promoted"
  else
    _30_ = nil
  end
  local _32_
  local _34_
  do
    local t_33_ = t.conversation
    if (nil ~= t_33_) then
      t_33_ = t_33_[1]
    else
    end
    if (nil ~= t_33_) then
      t_33_ = t_33_.source
    else
    end
    _34_ = t_33_
  end
  if ("agent" == _34_) then
    _32_ = " \194\183 by agent"
  else
    _32_ = nil
  end
  status = ((t.status or "open") .. (_28_ or "") .. (_30_ or "") .. (_32_ or ""))
  local pos
  if ("file" == (t.type or "line")) then
    pos = "file"
  else
    pos = ((t.line_start or "?") .. "-" .. (t.line_end or "?"))
  end
  return string.format("#%d  %s:%s  (%s)  anchor %s", (t.id or 0), base, pos, status, short_sha(t["anchor-sha"]))
end
local function comment_label(c)
  return string.format("[%s] %s", (c.source or "user"), (c["author-name"] or "unknown"))
end
local comment_hls = {posted = "MoreMsg", sent = "Directory", draft = "WarningMsg", agent = "Special", github = "Identifier"}
local function comment_status(c)
  local source = (c.source or "user")
  if ("github" == source) then
    return "github"
  elseif ("agent" == source) then
    return "agent"
  elseif (((c.posted or 0) > 0) or c.gh_comment_id) then
    return "posted"
  elseif ((c.sent or 0) > 0) then
    return "sent"
  else
    return "draft"
  end
end
local function comment_hl(c)
  return comment_hls[comment_status(c)]
end
local function render(path, threads)
  local lines = {}
  local headers = {}
  local labels = {}
  local base = (vim.fs.basename((path or "")) or "?")
  for i, t in ipairs(threads) do
    if (i > 1) then
      table.insert(lines, string.rep("\226\148\128", pane_width))
    else
    end
    table.insert(headers, {row = (#lines + 1), hl = thread_hl((t["hl-index"] or i)), thread = t})
    table.insert(lines, thread_header(base, t))
    table.insert(lines, "")
    for j, c in ipairs((t.conversation or {})) do
      if (j > 1) then
        table.insert(lines, "")
      else
      end
      table.insert(labels, {row = (#lines + 1), hl = comment_hl(c)})
      table.insert(lines, comment_label(c))
      for _, l in ipairs(vim.split((c.body or ""), "\n")) do
        table.insert(lines, l)
      end
    end
  end
  if (#threads > 0) then
    table.insert(lines, "")
    for _, l in ipairs(pane_keys_footer) do
      table.insert(labels, {row = (#lines + 1)})
      table.insert(lines, l)
    end
  else
  end
  return {lines = lines, headers = headers, labels = labels}
end
local function pane_sig(path, threads)
  local _43_
  do
    local tbl_26_ = {}
    local i_27_ = 0
    for _, t in ipairs((threads or {})) do
      local val_28_ = tostring((t.id or 0))
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    _43_ = tbl_26_
  end
  return ((path or "") .. "|" .. tostring(map_version) .. "|" .. table.concat(_43_, ","))
end
local function render_pane(path, threads)
  if (pane_sig(path, threads) ~= rendered_sig) then
    rendered_sig = pane_sig(path, threads)
    local buf = vim.api.nvim_win_get_buf(pane_win)
    local bo = vim.bo[buf]
    local _let_45_ = render(path, threads)
    local lines = _let_45_.lines
    local headers = _let_45_.headers
    local labels = _let_45_.labels
    pane_path = path
    pane_header_rows = headers
    vim.api.nvim_buf_clear_namespace(buf, extmark_ns, 0, -1)
    bo.modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    bo.modifiable = false
    for _, h in ipairs(headers) do
      vim.api.nvim_buf_set_extmark(buf, extmark_ns, (h.row - 1), 0, {line_hl_group = h.hl})
    end
    for _, l in ipairs(labels) do
      vim.api.nvim_buf_set_extmark(buf, extmark_ns, (l.row - 1), 0, {line_hl_group = (l.hl or "Comment")})
    end
    return nil
  else
    return nil
  end
end
local function pane_thread_at(row)
  local t = nil
  for _, h in ipairs(pane_header_rows) do
    if (h.row > row) then break end
    t = h.thread
  end
  return t
end
local function refresh_pane()
  if (pane_win and vim.api.nvim_win_is_valid(pane_win)) then
    if current_thread then
      stamp_thread(current_thread)
    else
    end
    map_version = (1 + map_version)
    local function _48_()
      if current_thread then
        return {current_thread}
      else
        return {}
      end
    end
    return render_pane(pane_path, _48_())
  else
    return nil
  end
end
local function review_half(t)
  if ("review" == (t.kind or "local")) then
    return t
  else
    local twin = review.twin((t.id or 0))
    if (twin and ("review" == (twin.kind or "local"))) then
      return twin
    else
      return nil
    end
  end
end
local function pane_reply()
  local t
  local function _53_()
    local t_52_ = vim.api.nvim_win_get_cursor(pane_win)
    if (nil ~= t_52_) then
      t_52_ = t_52_[1]
    else
    end
    return t_52_
  end
  t = pane_thread_at(_53_())
  if not t then
    return vim.notify("codeboomer: no thread block under the pane cursor", vim.log.levels.WARN)
  else
    local target = review_half(t)
    if not target then
      return vim.notify("codeboomer: thread not promoted \226\128\148 p promotes it first", vim.log.levels.WARN)
    else
      local function _55_(lines)
        if review["user-reply"]((target.id or 0), table.concat(lines, "\n")) then
          return refresh_pane()
        else
          return nil
        end
      end
      return input.open({title = string.format(" Reply on thread #%d> ", (t.id or 0)), ["on-submit"] = _55_})
    end
  end
end
local execute_body = "execute"
local function with_agent_half(k)
  local t
  local function _60_()
    local t_59_ = vim.api.nvim_win_get_cursor(pane_win)
    if (nil ~= t_59_) then
      t_59_ = t_59_[1]
    else
    end
    return t_59_
  end
  t = pane_thread_at(_60_())
  if not t then
    return vim.notify("codeboomer: no thread block under the pane cursor", vim.log.levels.WARN)
  else
    local target
    if ("local" == (t.kind or "local")) then
      target = t
    else
      target = (review.twin((t.id or 0)) or review["ensure-local-twin"]((t.id or 0)))
    end
    if not target then
      return vim.notify("codeboomer: could not open the conversation", vim.log.levels.ERROR)
    else
      return k(t, target)
    end
  end
end
local function pane_agent_reply()
  local compose
  local function _65_(t, target)
    local submit
    local function _66_(lines)
      if review["user-reply"]((target.id or 0), table.concat(lines, "\n")) then
        return refresh_pane()
      else
        return nil
      end
    end
    submit = _66_
    return input.open({title = string.format(" Reply to the agent on thread #%d> ", (t.id or 0)), ["on-submit"] = submit})
  end
  compose = _65_
  return with_agent_half(compose)
end
local function pane_execute()
  local function _68_(_, target)
    if review["user-reply"]((target.id or 0), execute_body) then
      return refresh_pane()
    else
      return nil
    end
  end
  return with_agent_half(_68_)
end
local function virgin_body(t)
  local cs = review["conversation-comments"]((t.id or 0))
  if (1 == #cs) then
    local c = cs[1]
    if ("user" == (c.source or "user")) then
      return (c.body or "")
    else
      return nil
    end
  else
    return nil
  end
end
local function root_body(t)
  local t_72_ = review["conversation-comments"]((t.id or 0))
  if (nil ~= t_72_) then
    t_72_ = t_72_[1]
  else
  end
  if (nil ~= t_72_) then
    t_72_ = t_72_.body
  else
  end
  return t_72_
end
local function pane_promote()
  local t
  local function _76_()
    local t_75_ = vim.api.nvim_win_get_cursor(pane_win)
    if (nil ~= t_75_) then
      t_75_ = t_75_[1]
    else
    end
    return t_75_
  end
  t = pane_thread_at(_76_())
  if not t then
    return vim.notify("codeboomer: no thread block under the pane cursor", vim.log.levels.WARN)
  elseif ("review" == (t.kind or "local")) then
    return vim.notify("codeboomer: this thread is already on github", vim.log.levels.WARN)
  elseif review.twin((t.id or 0)) then
    return vim.notify(string.format("codeboomer: thread #%d already promoted", (t.id or 0)), vim.log.levels.WARN)
  else
    local session = source_session()
    local ctx = require("codeboomer.review-mode")["promote-context"](session)
    if not ctx then
      return vim.notify("codeboomer: this branch's session is not bound to a PR \226\128\148 :Codeboomer Review first", vim.log.levels.WARN)
    elseif (ctx["head-ranges"] and github["thread-off-diff"](t, ctx["head-ranges"])) then
      return vim.notify("codeboomer: the range falls outside the PR diff \226\128\148 move or resolve the thread first", vim.log.levels.ERROR)
    else
      local as_is = virgin_body(t)
      if as_is then
        if review.promote((t.id or 0), as_is, ctx["session-id"]) then
          refresh_pane()
          return vim.notify(string.format("codeboomer: thread #%d promoted", (t.id or 0)), vim.log.levels.INFO)
        else
          return nil
        end
      else
        local function _79_(lines)
          local body = table.concat(lines, "\n")
          if (("" ~= vim.trim(body)) and review.promote((t.id or 0), body, ctx["session-id"])) then
            refresh_pane()
            return vim.notify(string.format("codeboomer: thread #%d promoted", (t.id or 0)), vim.log.levels.INFO)
          else
            return nil
          end
        end
        return input.open({title = string.format(" Promote thread #%d> ", (t.id or 0)), prefill = (root_body(t) or ""), ["on-submit"] = _79_})
      end
    end
  end
end
local function pane_edit()
  local t
  local function _85_()
    local t_84_ = vim.api.nvim_win_get_cursor(pane_win)
    if (nil ~= t_84_) then
      t_84_ = t_84_[1]
    else
    end
    return t_84_
  end
  t = pane_thread_at(_85_())
  if not t then
    return vim.notify("codeboomer: no thread block under the pane cursor", vim.log.levels.WARN)
  else
    local target = review_half(t)
    if not target then
      return vim.notify("codeboomer: thread not promoted \226\128\148 p promotes it first", vim.log.levels.WARN)
    else
      local c = review["unposted-user-comments"]((target.id or 0))[1]
      if not c then
        return vim.notify("codeboomer: nothing unposted to edit", vim.log.levels.WARN)
      else
        local function _87_(lines)
          review["update-comment-body"]((c.id or 0), table.concat(lines, "\n"))
          return refresh_pane()
        end
        return input.open({title = string.format(" Edit comment #%d> ", (c.id or 0)), prefill = (c.body or ""), ["on-submit"] = _87_})
      end
    end
  end
end
local function pane_delete()
  local t
  local function _92_()
    local t_91_ = vim.api.nvim_win_get_cursor(pane_win)
    if (nil ~= t_91_) then
      t_91_ = t_91_[1]
    else
    end
    return t_91_
  end
  t = pane_thread_at(_92_())
  if not t then
    return vim.notify("codeboomer: no thread block under the pane cursor", vim.log.levels.WARN)
  else
    local cs = review["conversation-comments"]((t.id or 0))
    local c = cs[#cs]
    if not c then
      return vim.notify("codeboomer: the thread has no messages", vim.log.levels.WARN)
    elseif (("user" ~= (c.source or "user")) or ((c.sent or 0) > 0) or ((c.posted or 0) > 0) or c.gh_comment_id) then
      return vim.notify("codeboomer: the last message already left \226\128\148 nothing unsent to delete", vim.log.levels.WARN)
    else
      review["delete-comment"]((c.id or 0))
      refresh_pane()
      return vim.notify(string.format("codeboomer: deleted the unsent message on thread #%d", (t.id or 0)), vim.log.levels.INFO)
    end
  end
end
local function pane_refresh()
  if current_thread then
    return refresh_pane()
  else
    return nil
  end
end
local function covering_at_source()
  if not (pane_source_win and vim.api.nvim_win_is_valid(pane_source_win) and pane_win and vim.api.nvim_win_is_valid(pane_win)) then
    return nil
  else
    local row
    do
      local t_97_ = vim.api.nvim_win_get_cursor(pane_source_win)
      if (nil ~= t_97_) then
        t_97_ = t_97_[1]
      else
      end
      row = t_97_
    end
    return threads_at((pane_path or ""), (row or 0))
  end
end
local function pane_resolve()
  local t
  local function _101_()
    local t_100_ = vim.api.nvim_win_get_cursor(pane_win)
    if (nil ~= t_100_) then
      t_100_ = t_100_[1]
    else
    end
    return t_100_
  end
  t = pane_thread_at(_101_())
  if not t then
    return vim.notify("codeboomer: no thread block under the pane cursor", vim.log.levels.WARN)
  else
    local n = #all_threads
    local successor
    if (n > 0) then
      successor = all_threads[(1 + (((index_of(t) or -1) + 1) % n))]
    else
      successor = nil
    end
    review["resolve-thread"]((t.id or 0))
    return M["reload-threads"](successor)
  end
end
local pane_jump = nil
local function hide_pane()
  local win = pane_win
  pane_win = nil
  rendered_sig = nil
  if (win and vim.api.nvim_win_is_valid(win)) then
    return pcall(vim.api.nvim_win_close, win, true)
  else
    return nil
  end
end
local function open_pane()
  vim.cmd(string.format("botright %dvnew", pane_width))
  pane_win = vim.api.nvim_get_current_win()
  do
    local buf = vim.api.nvim_get_current_buf()
    local bo = vim.bo[buf]
    local wo = vim.wo[pane_win]
    bo.buftype = "nofile"
    bo.swapfile = false
    bo.bufhidden = "wipe"
    bo.modifiable = false
    pcall(vim.api.nvim_buf_set_name, buf, pane_buf_name)
    wo.wrap = true
    wo.linebreak = true
    wo.number = false
    wo.relativenumber = false
    wo.signcolumn = "no"
    wo.winfixwidth = true
    vim.keymap.set("n", "r", pane_reply, {buffer = buf, desc = "codeboomer: reply on this thread"})
    vim.keymap.set("n", "a", pane_agent_reply, {buffer = buf, desc = "codeboomer: reply to the agent on this thread"})
    vim.keymap.set("n", "z", pane_execute, {buffer = buf, desc = "codeboomer: tell the agent to execute on this thread"})
    vim.keymap.set("n", "p", pane_promote, {buffer = buf, desc = "codeboomer: promote this thread to the PR review"})
    vim.keymap.set("n", "e", pane_edit, {buffer = buf, desc = "codeboomer: edit the promoted comment"})
    vim.keymap.set("n", "d", pane_delete, {buffer = buf, desc = "codeboomer: delete the last unsent message"})
    vim.keymap.set("n", "f", pane_refresh, {buffer = buf, desc = "codeboomer: refresh this thread"})
    vim.keymap.set("n", "q", pane_resolve, {buffer = buf, desc = "codeboomer: resolve this thread"})
    local function _106_()
      return pane_jump(1)
    end
    vim.keymap.set("n", "n", _106_, {buffer = buf, desc = "codeboomer: jump to the next thread"})
    local function _107_()
      return pane_jump(-1)
    end
    vim.keymap.set("n", "N", _107_, {buffer = buf, desc = "codeboomer: jump to the previous thread"})
  end
  return vim.cmd("wincmd p")
end
local function pane_valid_3f()
  return (pane_win and vim.api.nvim_win_is_valid(pane_win))
end
local function show_pane(path, threads)
  do
    local here = source_win_3f(vim.api.nvim_get_current_win())
    if (here and pane_valid_3f() and (vim.api.nvim_win_get_tabpage(pane_win) ~= vim.api.nvim_get_current_tabpage())) then
      hide_pane()
    else
    end
    if (here and not pane_valid_3f()) then
      open_pane()
    else
    end
  end
  if pane_valid_3f() then
    return render_pane(path, threads)
  else
    return nil
  end
end
local function show_current()
  if current_thread then
    return show_pane(current_thread.file_path, {current_thread})
  else
    return show_pane(pane_path, {})
  end
end
local function open_on_session()
  if (#all_threads > 0) then
    ensure_current()
    if (vim.api.nvim_get_current_win() ~= pane_win) then
      pane_source_win = vim.api.nvim_get_current_win()
    else
    end
    return show_current()
  else
    return nil
  end
end
local function _114_(bufnr)
  if (vim.api.nvim_buf_is_valid(bufnr) and (bufnr == vim.api.nvim_get_current_buf()) and source_win_3f(vim.api.nvim_get_current_win())) then
    if (pane_win and vim.api.nvim_win_is_valid(pane_win) and (vim.api.nvim_win_get_tabpage(pane_win) == vim.api.nvim_get_current_tabpage())) then
      pane_source_win = vim.api.nvim_get_current_win()
    else
    end
    local path = buf_rel_path(bufnr)
    local file_threads = (threads_by_path[path] or {})
    local candidate
    if (current_thread and ((current_thread.file_path or "") == path)) then
      candidate = current_thread
    else
      candidate = file_threads[1]
    end
    if (candidate and (not pane_win or not vim.api.nvim_win_is_valid(pane_win) or (candidate ~= current_thread))) then
      current_thread = candidate
      pane_source_win = vim.api.nvim_get_current_win()
      return show_current()
    else
      return nil
    end
  else
    return nil
  end
end
M["enter-file"] = _114_
local function flash_line(win, row)
  local buf = vim.api.nvim_win_get_buf(win)
  local id = vim.api.nvim_buf_set_extmark(buf, flash_ns, (row - 1), 0, {end_row = row, hl_group = "IncSearch", hl_eol = true})
  local function _119_()
    if vim.api.nvim_buf_is_valid(buf) then
      return pcall(vim.api.nvim_buf_del_extmark, buf, flash_ns, id)
    else
      return nil
    end
  end
  return vim.defer_fn(_119_, flash_ms)
end
local function _121_(dir)
  if not (pane_source_win and vim.api.nvim_win_is_valid(pane_source_win)) then
    return vim.notify("codeboomer: the pane has no code window to jump from", vim.log.levels.WARN)
  else
    local n = #all_threads
    if (0 == n) then
      return vim.notify("codeboomer: no threads to jump to", vim.log.levels.WARN)
    else
      local target
      local or_122_ = index_of(current_thread)
      if not or_122_ then
        if (dir > 0) then
          or_122_ = -1
        else
          or_122_ = 0
        end
      end
      target = all_threads[(1 + ((or_122_ + dir) % n))]
      local source_buf = vim.api.nvim_win_get_buf(pane_source_win)
      local cur_path = buf_rel_path(source_buf)
      local target_path = ((git["work-root"](source_buf) or "") .. "/" .. target.file_path)
      do
        local jump_to
        local function _124_()
          if (cur_path ~= target.file_path) then
            vim.cmd({cmd = "edit", args = {target_path}})
          else
          end
          local row = math.min((target.line_start or 1), vim.api.nvim_buf_line_count(0))
          vim.api.nvim_win_set_cursor(pane_source_win, {row, 0})
          vim.cmd("normal! zz")
          return row
        end
        jump_to = _124_
        local row = vim.api.nvim_win_call(pane_source_win, jump_to)
        flash_line(pane_source_win, row)
      end
      current_thread = target
      show_pane(target.file_path, {target})
      return vim.api.nvim_win_set_cursor(pane_win, {1, 0})
    end
  end
end
pane_jump = _121_
local function evaluate_at(win)
  local buf = vim.api.nvim_win_get_buf(win)
  if source_win_3f(win) then
    local row
    do
      local t_128_ = vim.api.nvim_win_get_cursor(win)
      if (nil ~= t_128_) then
        t_128_ = t_128_[1]
      else
      end
      row = t_128_
    end
    local path = buf_rel_path(buf)
    local threads = threads_at(path, (row or 0))
    if (#threads > 0) then
      pane_source_win = win
      do
        local cur = fresh(current_thread)
        if (cur and ((cur.file_path or "") == path) and covers_3f(cur, (row or 0))) then
          current_thread = cur
        else
          current_thread = threads[1]
        end
      end
      return show_current()
    else
      return nil
    end
  else
    return nil
  end
end
local function check_now()
  local win = vim.api.nvim_get_current_win()
  if (win == pane_win) then
    if (pane_source_win and vim.api.nvim_win_is_valid(pane_source_win)) then
      return evaluate_at(pane_source_win)
    else
      return nil
    end
  else
    return evaluate_at(win)
  end
end
local function schedule_check()
  if timer_id then
    vim.fn.timer_stop(timer_id)
  else
  end
  timer_id = vim.fn.timer_start(rest_ms, check_now)
  return nil
end
local function idle_refresh()
  if M["session-id"]() then
    return M["reload-threads"]()
  else
    return nil
  end
end
local function schedule_db_refresh()
  if db_refresh_timer then
    vim.fn.timer_stop(db_refresh_timer)
  else
  end
  db_refresh_timer = vim.fn.timer_start(db_refresh_ms, idle_refresh)
  return nil
end
local function reconcile_pane(_3fprefer)
  if (pane_win and vim.api.nvim_win_is_valid(pane_win)) then
    current_thread = (fresh(current_thread) or fresh(covering_at_source()[1]) or fresh(_3fprefer) or all_threads[1])
    return show_current()
  else
    return nil
  end
end
local loaded_session_id = nil
local function maybe_reload_session()
  local sid = M["session-id"]()
  if (sid ~= loaded_session_id) then
    return M["reload-threads"]()
  else
    return nil
  end
end
M["reload-threads"] = function(_3fprefer)
  local sid = M["session-id"]()
  local before = map_sig()
  loaded_session_id = sid
  threads_by_path = {}
  if sid then
    all_threads = review["threads-for-session"](sid)
  else
    all_threads = {}
  end
  for _, t in ipairs(all_threads) do
    stamp_thread(t)
  end
  for _, t in ipairs(all_threads) do
    local path = (t.file_path or "")
    local peers = vim.list_extend((threads_by_path[path] or {}), {t})
    t["hl-index"] = #peers
    threads_by_path[path] = peers
  end
  if (before ~= map_sig()) then
    map_version = (1 + map_version)
    reconcile_pane(_3fprefer)
    return schedule_check()
  else
    return nil
  end
end
local function attach_autocmds()
  vim.api.nvim_create_augroup(augroup_name, {clear = true})
  local function _142_()
    maybe_reload_session()
    return open_on_session()
  end
  vim.api.nvim_create_autocmd("VimEnter", {group = augroup_name, callback = _142_})
  local function _143_(ev)
    maybe_reload_session()
    M["enter-file"](ev.buf)
    schedule_check()
    return schedule_db_refresh()
  end
  vim.api.nvim_create_autocmd("BufEnter", {group = augroup_name, callback = _143_})
  local function _144_()
    schedule_check()
    return schedule_db_refresh()
  end
  vim.api.nvim_create_autocmd({"WinEnter", "TabEnter", "CursorMoved", "CursorMovedI", "FocusGained"}, {group = augroup_name, callback = _144_})
  local function _145_(ev)
    if (pane_win == tonumber(ev.match)) then
      pane_win = nil
      rendered_sig = nil
      return nil
    else
      return nil
    end
  end
  vim.api.nvim_create_autocmd("WinClosed", {group = augroup_name, callback = _145_})
  local function _147_()
    return M["reload-threads"]()
  end
  return vim.api.nvim_create_autocmd("User", {group = augroup_name, pattern = {"CodeboomerAnnotated", "CodeboomerSessionReset", "CodeboomerImported"}, callback = _147_})
end
local function _148_()
  M["reload-threads"]()
  open_on_session()
  return check_now()
end
M.open = _148_
attach_autocmds()
return M
