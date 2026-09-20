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
local sign_text = "\226\150\140"
local pane_keys_footer = {("\226\148\128\226\148\128 keys " .. string.rep("\226\148\128", (pane_width - 8))), "r reply \194\183 a agent \194\183 p promote", "e edit \194\183 q resolve \194\183 n/N thread"}
local rest_ms = 100
local pane_win = nil
local threads_by_path = {}
local all_threads = {}
local timer_id = nil
local open_path_resolver = nil
M["set-open-path"] = function(f)
  open_path_resolver = f
  return nil
end
local promote_context = nil
M["set-promote-context"] = function(f)
  promote_context = f
  return nil
end
local function resolve_open_path(path)
  return ((open_path_resolver and open_path_resolver(path)) or ((git["repo-root"]() or "") .. "/" .. path))
end
local pane_source_win = nil
local pane_path = nil
local pane_threads = nil
local pane_header_rows = {}
local function thread_hl(index)
  local groups = {"Title", "Special", "String", "Function"}
  return groups[(1 + ((index - 1) % #groups))]
end
local function place_marks(bufnr, threads)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, extmark_ns, 0, -1)
    local _2_
    do
      local t_1_ = vim.b
      if (nil ~= t_1_) then
        t_1_ = t_1_[bufnr]
      else
      end
      if (nil ~= t_1_) then
        t_1_ = t_1_.codeboomer_review_side
      else
      end
      _2_ = t_1_
    end
    if ("new" == _2_) then
      local line_count = vim.api.nvim_buf_line_count(bufnr)
      local taken = {}
      for i, t in ipairs(threads) do
        local start = (t.line_start or 0)
        local finish = math.min((t.line_end or start), line_count)
        local hl = thread_hl((t["hl-index"] or i))
        for ln = start, finish do
          if not taken[ln] then
            taken[ln] = true
            vim.api.nvim_buf_set_extmark(bufnr, extmark_ns, (ln - 1), 0, {sign_text = sign_text, sign_hl_group = hl})
          else
          end
        end
      end
      return nil
    else
      return nil
    end
  else
    return nil
  end
end
local function normal_buf(bufnr)
  local _9_
  do
    local t_8_ = vim.bo
    if (nil ~= t_8_) then
      t_8_ = t_8_[bufnr]
    else
    end
    if (nil ~= t_8_) then
      t_8_ = t_8_.buftype
    else
    end
    _9_ = t_8_
  end
  return ("" == (_9_ or ""))
end
local rel_path_cache = {}
local function buf_rel_path(bufnr)
  local or_12_ = rel_path_cache[bufnr]
  if not or_12_ then
    local p = git["rel-path"](vim.api.nvim_buf_get_name(bufnr))
    rel_path_cache[bufnr] = p
    or_12_ = p
  end
  return or_12_
end
local function mark_loaded_buffers()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if (vim.api.nvim_buf_is_loaded(bufnr) and normal_buf(bufnr)) then
      local path = buf_rel_path(bufnr)
      place_marks(bufnr, (threads_by_path[path] or {}))
    else
    end
  end
  return nil
end
local function threads_at(path, line)
  local found = nil
  for _, t in ipairs((threads_by_path[path] or {})) do
    if found then break end
    if (t.line_start and t.line_end and (line >= t.line_start) and (line <= t.line_end)) then
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
local function stamp_thread(t)
  local twin = review.twin((t.id or 0))
  if twin then
    t["twin-kind"] = twin.kind
  else
    t["twin-kind"] = nil
  end
  t.conversation = review["conversation-comments"]((t.id or 0))
  for _, c in ipairs((t.conversation or {})) do
    local _19_
    do
      local t_18_ = review["comment-author"](c)
      if (nil ~= t_18_) then
        t_18_ = t_18_.name
      else
      end
      _19_ = t_18_
    end
    c["author-name"] = (_19_ or "unknown")
  end
  return nil
end
local stamp_ttl_ms = 1000
local last_stamp_ms = 0
local map_version = 0
local rendered_sig = nil
local function conv_sig(t)
  local sig = ""
  for _, c in ipairs((t.conversation or {})) do
    sig = (sig .. tostring((c.id or 0)) .. ",")
  end
  return sig
end
local function maybe_restamp(threads)
  if ((vim.loop.now() - (last_stamp_ms or 0)) > stamp_ttl_ms) then
    last_stamp_ms = vim.loop.now()
    local changed = false
    for _, t in ipairs((threads or {})) do
      local before = conv_sig(t)
      stamp_thread(t)
      if (before ~= conv_sig(t)) then
        changed = true
      else
      end
    end
    if changed then
      map_version = (1 + map_version)
      return nil
    else
      return nil
    end
  else
    return nil
  end
end
local function thread_header(base, t)
  local status
  local _24_
  if (t.gh_outdated and ((t.gh_outdated or 0) > 0)) then
    _24_ = ", outdated"
  else
    _24_ = nil
  end
  local _26_
  if ("review" == (t["twin-kind"] or "local")) then
    _26_ = " \194\183 promoted"
  else
    _26_ = nil
  end
  status = ((t.status or "open") .. (_24_ or "") .. (_26_ or ""))
  return string.format("#%d  %s:%s-%s  (%s)", (t.id or 0), base, (t.line_start or "?"), (t.line_end or "?"), status)
end
local function comment_label(c)
  return string.format("[%s] %s", (c.source or "user"), (c["author-name"] or "unknown"))
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
      table.insert(labels, {row = (#lines + 1)})
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
  local _31_
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
    _31_ = tbl_26_
  end
  return ((path or "") .. "|" .. tostring(map_version) .. "|" .. table.concat(_31_, ","))
end
local function render_pane(path, threads)
  if (pane_sig(path, threads) ~= rendered_sig) then
    rendered_sig = pane_sig(path, threads)
    local buf = vim.api.nvim_win_get_buf(pane_win)
    local bo = vim.bo[buf]
    local _let_33_ = render(path, threads)
    local lines = _let_33_.lines
    local headers = _let_33_.headers
    local labels = _let_33_.labels
    pane_path = path
    pane_threads = threads
    pane_header_rows = headers
    vim.api.nvim_buf_clear_namespace(buf, extmark_ns, 0, -1)
    bo.modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    bo.modifiable = false
    for _, h in ipairs(headers) do
      vim.api.nvim_buf_set_extmark(buf, extmark_ns, (h.row - 1), 0, {line_hl_group = h.hl})
    end
    for _, l in ipairs(labels) do
      vim.api.nvim_buf_set_extmark(buf, extmark_ns, (l.row - 1), 0, {line_hl_group = "Comment"})
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
    for _, t in ipairs((pane_threads or {})) do
      stamp_thread(t)
    end
    map_version = (1 + map_version)
    return render_pane(pane_path, pane_threads)
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
  local function _39_()
    local t_38_ = vim.api.nvim_win_get_cursor(pane_win)
    if (nil ~= t_38_) then
      t_38_ = t_38_[1]
    else
    end
    return t_38_
  end
  t = pane_thread_at(_39_())
  if not t then
    return vim.notify("codeboomer: no thread block under the pane cursor", vim.log.levels.WARN)
  else
    local target = review_half(t)
    if not target then
      return vim.notify("codeboomer: thread not promoted \226\128\148 p promotes it first", vim.log.levels.WARN)
    else
      local function _41_(lines)
        if review["user-reply"]((target.id or 0), table.concat(lines, "\n")) then
          return refresh_pane()
        else
          return nil
        end
      end
      return input.open({title = string.format(" Reply on thread #%d> ", (t.id or 0)), ["on-submit"] = _41_})
    end
  end
end
local function pane_agent_reply()
  local t
  local function _46_()
    local t_45_ = vim.api.nvim_win_get_cursor(pane_win)
    if (nil ~= t_45_) then
      t_45_ = t_45_[1]
    else
    end
    return t_45_
  end
  t = pane_thread_at(_46_())
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
      local function _49_(lines)
        if review["user-reply"]((target.id or 0), table.concat(lines, "\n")) then
          return refresh_pane()
        else
          return nil
        end
      end
      return input.open({title = string.format(" Reply to the agent on thread #%d> ", (t.id or 0)), ["on-submit"] = _49_})
    end
  end
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
local function first_user_body(t)
  local body = nil
  for _, c in ipairs(review["conversation-comments"]((t.id or 0))) do
    local or_55_ = body
    if not or_55_ then
      if ("user" == (c.source or "user")) then
        or_55_ = (c.body or "")
      else
        or_55_ = nil
      end
    end
    body = or_55_
  end
  return body
end
local function pane_promote()
  local t
  local function _58_()
    local t_57_ = vim.api.nvim_win_get_cursor(pane_win)
    if (nil ~= t_57_) then
      t_57_ = t_57_[1]
    else
    end
    return t_57_
  end
  t = pane_thread_at(_58_())
  if not t then
    return vim.notify("codeboomer: no thread block under the pane cursor", vim.log.levels.WARN)
  elseif ("review" == (t.kind or "local")) then
    return vim.notify("codeboomer: this thread is already on github", vim.log.levels.WARN)
  elseif review.twin((t.id or 0)) then
    return vim.notify(string.format("codeboomer: thread #%d already promoted", (t.id or 0)), vim.log.levels.WARN)
  else
    local ctx
    if promote_context then
      ctx = promote_context()
    else
      ctx = nil
    end
    if not ctx then
      return vim.notify("codeboomer: no open PR review \226\128\148 :Codeboomer Review first", vim.log.levels.WARN)
    elseif github["thread-off-diff"](t, ctx["head-ranges"]) then
      return vim.notify("codeboomer: the range falls outside the PR diff \226\128\148 move or resolve the thread first", vim.log.levels.ERROR)
    else
      local as_is = virgin_body(t)
      if as_is then
        review.promote((t.id or 0), as_is, ctx["session-id"], ctx["head-sha"])
        refresh_pane()
        return vim.notify(string.format("codeboomer: thread #%d promoted", (t.id or 0)), vim.log.levels.INFO)
      else
        local function _61_(lines)
          local body = table.concat(lines, "\n")
          if ("" ~= vim.trim(body)) then
            review.promote((t.id or 0), body, ctx["session-id"], ctx["head-sha"])
            refresh_pane()
            return vim.notify(string.format("codeboomer: thread #%d promoted", (t.id or 0)), vim.log.levels.INFO)
          else
            return nil
          end
        end
        return input.open({title = string.format(" Promote thread #%d> ", (t.id or 0)), prefill = (first_user_body(t) or ""), ["on-submit"] = _61_})
      end
    end
  end
end
local function pane_edit()
  local t
  local function _67_()
    local t_66_ = vim.api.nvim_win_get_cursor(pane_win)
    if (nil ~= t_66_) then
      t_66_ = t_66_[1]
    else
    end
    return t_66_
  end
  t = pane_thread_at(_67_())
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
        local function _69_(lines)
          review["update-comment-body"]((c.id or 0), table.concat(lines, "\n"))
          return refresh_pane()
        end
        return input.open({title = string.format(" Edit comment #%d> ", (c.id or 0)), prefill = (c.body or ""), ["on-submit"] = _69_})
      end
    end
  end
end
local function covering_at_source()
  if not (pane_source_win and vim.api.nvim_win_is_valid(pane_source_win) and pane_win and vim.api.nvim_win_is_valid(pane_win)) then
    return nil
  else
    local buf = vim.api.nvim_win_get_buf(pane_source_win)
    local _74_
    do
      local t_73_ = vim.b
      if (nil ~= t_73_) then
        t_73_ = t_73_[buf]
      else
      end
      if (nil ~= t_73_) then
        t_73_ = t_73_.codeboomer_review_side
      else
      end
      _74_ = t_73_
    end
    if ("old" == _74_) then
      return {}
    else
      local row
      do
        local t_77_ = vim.api.nvim_win_get_cursor(pane_source_win)
        if (nil ~= t_77_) then
          t_77_ = t_77_[1]
        else
        end
        row = t_77_
      end
      return threads_at((pane_path or ""), (row or 0))
    end
  end
end
local function pane_resolve()
  local t
  local function _82_()
    local t_81_ = vim.api.nvim_win_get_cursor(pane_win)
    if (nil ~= t_81_) then
      t_81_ = t_81_[1]
    else
    end
    return t_81_
  end
  t = pane_thread_at(_82_())
  if not t then
    return vim.notify("codeboomer: no thread block under the pane cursor", vim.log.levels.WARN)
  else
    local remaining
    do
      review["resolve-thread"]((t.id or 0))
      M["reload-threads"]()
      remaining = covering_at_source()
    end
    if remaining then
      return render_pane(pane_path, remaining)
    else
      return nil
    end
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
local function show_pane(path, threads)
  if (pane_win and vim.api.nvim_win_is_valid(pane_win) and (vim.api.nvim_win_get_tabpage(pane_win) ~= vim.api.nvim_get_current_tabpage())) then
    hide_pane()
  else
  end
  if not (pane_win and vim.api.nvim_win_is_valid(pane_win)) then
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
      vim.keymap.set("n", "p", pane_promote, {buffer = buf, desc = "codeboomer: promote this thread to the PR review"})
      vim.keymap.set("n", "e", pane_edit, {buffer = buf, desc = "codeboomer: edit the promoted comment"})
      vim.keymap.set("n", "q", pane_resolve, {buffer = buf, desc = "codeboomer: resolve this thread"})
      local function _88_()
        return pane_jump(1)
      end
      vim.keymap.set("n", "n", _88_, {buffer = buf, desc = "codeboomer: jump to the next thread"})
      local function _89_()
        return pane_jump(-1)
      end
      vim.keymap.set("n", "N", _89_, {buffer = buf, desc = "codeboomer: jump to the previous thread"})
    end
    vim.cmd("wincmd p")
  else
  end
  maybe_restamp(threads)
  return render_pane(path, threads)
end
local function flash_line(win, row)
  local buf = vim.api.nvim_win_get_buf(win)
  local id = vim.api.nvim_buf_set_extmark(buf, flash_ns, (row - 1), 0, {end_row = row, hl_group = "IncSearch", hl_eol = true})
  local function _91_()
    if vim.api.nvim_buf_is_valid(buf) then
      return pcall(vim.api.nvim_buf_del_extmark, buf, flash_ns, id)
    else
      return nil
    end
  end
  return vim.defer_fn(_91_, flash_ms)
end
local function _93_(dir)
  if not (pane_source_win and vim.api.nvim_win_is_valid(pane_source_win)) then
    return vim.notify("codeboomer: the pane has no code window to jump from", vim.log.levels.WARN)
  else
    local n = #all_threads
    if (0 == n) then
      return vim.notify("codeboomer: no threads to jump to", vim.log.levels.WARN)
    else
      local t
      local function _95_()
        local t_94_ = vim.api.nvim_win_get_cursor(pane_win)
        if (nil ~= t_94_) then
          t_94_ = t_94_[1]
        else
        end
        return t_94_
      end
      t = pane_thread_at(_95_())
      local idx
      do
        local found = nil
        for i, th in ipairs(all_threads) do
          if (t and (th.id == t.id)) then
            found = (i - 1)
          else
            found = found
          end
        end
        idx = found
      end
      local target0
      local or_98_ = idx
      if not or_98_ then
        if (dir > 0) then
          or_98_ = -1
        else
          or_98_ = 0
        end
      end
      target0 = ((or_98_ + dir) % n)
      local target = all_threads[(target0 + 1)]
      local cur_path = buf_rel_path(vim.api.nvim_win_get_buf(pane_source_win))
      local function _100_()
        if (cur_path ~= target.file_path) then
          vim.cmd({cmd = "edit", args = {resolve_open_path(target.file_path)}})
        else
        end
        vim.api.nvim_win_set_cursor(pane_source_win, {(target.line_start or 1), 0})
        return vim.cmd("normal! zz")
      end
      vim.api.nvim_win_call(pane_source_win, _100_)
      flash_line(pane_source_win, (target.line_start or 1))
      show_pane(target.file_path, {target})
      return vim.api.nvim_win_set_cursor(pane_win, {1, 0})
    end
  end
end
pane_jump = _93_
local function evaluate_at(win)
  local buf = vim.api.nvim_win_get_buf(win)
  local side
  do
    local t_104_ = vim.b
    if (nil ~= t_104_) then
      t_104_ = t_104_[buf]
    else
    end
    if (nil ~= t_104_) then
      t_104_ = t_104_.codeboomer_review_side
    else
    end
    side = t_104_
  end
  if ((side ~= "old") and normal_buf(buf)) then
    local row
    do
      local t_107_ = vim.api.nvim_win_get_cursor(win)
      if (nil ~= t_107_) then
        t_107_ = t_107_[1]
      else
      end
      row = t_107_
    end
    local path = buf_rel_path(buf)
    local threads = threads_at(path, (row or 0))
    if (#threads > 0) then
      pane_source_win = win
      return show_pane(path, threads)
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
    local _113_
    do
      local t_112_ = vim.api.nvim_win_get_config(win)
      if (nil ~= t_112_) then
        t_112_ = t_112_.relative
      else
      end
      _113_ = t_112_
    end
    if ("" == (_113_ or "")) then
      return evaluate_at(win)
    else
      return nil
    end
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
M["reload-threads"] = function()
  local sid = review["current-session-id"]()
  threads_by_path = {}
  if sid then
    all_threads = review["threads-for-session"](sid)
  else
    all_threads = {}
  end
  for _, t in ipairs(all_threads) do
    stamp_thread(t)
  end
  map_version = (1 + map_version)
  for _, t in ipairs(all_threads) do
    local path = (t.file_path or "")
    local peers = vim.list_extend((threads_by_path[path] or {}), {t})
    t["hl-index"] = #peers
    threads_by_path[path] = peers
  end
  mark_loaded_buffers()
  return schedule_check()
end
local function attach_autocmds()
  vim.api.nvim_create_augroup(augroup_name, {clear = true})
  vim.api.nvim_create_autocmd("BufEnter", {group = augroup_name, callback = schedule_check})
  vim.api.nvim_create_autocmd({"WinEnter", "TabEnter", "CursorMoved", "CursorMovedI"}, {group = augroup_name, callback = schedule_check})
  local function _119_(ev)
    if (pane_win == tonumber(ev.match)) then
      pane_win = nil
      rendered_sig = nil
      return nil
    else
      return nil
    end
  end
  vim.api.nvim_create_autocmd("WinClosed", {group = augroup_name, callback = _119_})
  return vim.api.nvim_create_autocmd("User", {group = augroup_name, pattern = {"CodeboomerAnnotated", "CodeboomerSessionChanged", "CodeboomerImported"}, callback = M["reload-threads"]})
end
local function _121_(bufnr)
  local path = buf_rel_path(bufnr)
  return place_marks(bufnr, (threads_by_path[path] or {}))
end
M["mark-buffer"] = _121_
local function _122_()
  M["reload-threads"]()
  return check_now()
end
M.open = _122_
attach_autocmds()
return M
