-- [nfnl] fnl/codeboomer/init.fnl
vim = vim
local config = require("codeboomer.config")
local input = require("codeboomer.input")
local directives = require("codeboomer.directives")
local review = require("codeboomer.review")
local sidebar = require("codeboomer.sidebar")
local agent = require("codeboomer.agent")
local git = require("codeboomer.git")
local tmux = require("codeboomer.tmux")
local channel = require("codeboomer.channel")
local picker = require("codeboomer.picker")
local reviewer = require("codeboomer.reviewer")
codeboomer = (codeboomer or {})
local state = {["last-input"] = nil}
local M = {}
local function all_panes()
  return vim.list_extend(tmux["list-panes"](), channel["list-panes"]())
end
local function all_last_lines()
  return vim.tbl_extend("force", tmux["last-lines"](), channel["last-lines"]())
end
local function schedule_notify(msg, level)
  local function _1_()
    return vim.notify(msg, level)
  end
  return vim.schedule(_1_)
end
local function _2_(opts)
  return config.setup(opts)
end
M.setup = _2_
local function shorten_path(path)
  local home = os.getenv("HOME")
  if (home and (1 == string.find(path, home, 1, true))) then
    return ("~" .. string.sub(path, (1 + #home)))
  else
    return path
  end
end
local function send_keys_to_selected_pane(text)
  local case_4_
  do
    local t_5_ = codeboomer.pane
    if (nil ~= t_5_) then
      t_5_ = t_5_.driver
    else
    end
    case_4_ = t_5_
  end
  if (case_4_ == "channel") then
    return channel.send(codeboomer.pane, text)
  else
    local _ = case_4_
    return tmux.send(codeboomer.pane, text)
  end
end
local last_line_max_length = 80
local function pane_display(p, last_line)
  local location = string.format("%s:%s.%s", p["session-name"], p["window-index"], p["pane-index"])
  local short_line
  if (#last_line > last_line_max_length) then
    short_line = (string.sub(last_line, 1, last_line_max_length) .. "\226\128\166")
  else
    short_line = last_line
  end
  local mode
  if (p["pane-mode"] ~= "") then
    mode = ("[" .. p["pane-mode"] .. "] ")
  else
    mode = ""
  end
  return string.format("%-6s %-11s %-18s %-30s %s%s", p["pane-id"], p["pane-current-command"], location, shorten_path(p["pane-current-path"]), mode, short_line)
end
local function choose_pane(panes, _3fthen)
  local last_lines = all_last_lines()
  local on_pick
  local function _10_(pane)
    codeboomer.pane = pane
    schedule_notify(string.format("codeboomer: pane %s (%s:%s.%s) selected", pane["pane-id"], pane["session-name"], pane["window-index"], pane["pane-index"]), vim.log.levels.INFO)
    if _3fthen then
      return _3fthen()
    else
      return nil
    end
  end
  on_pick = _10_
  local function _12_(_241)
    return pane_display(_241, last_lines[_241["pane-id"]])
  end
  return picker.choose("Pick a Pane> ", panes, _12_, on_pick, {preview = channel["preview-command"], fzf_opts = {["--with-nth"] = "2.."}, winopts = {preview = {layout = "vertical", vertical = "down:45%:follow", wrap = false}}})
end
local function _13_()
  local sid = sidebar["session-id"]()
  if not sid then
    return schedule_notify("codeboomer: no session for this branch", vim.log.levels.WARN)
  else
    review["delete-session"](sid)
    vim.api.nvim_exec_autocmds("User", {pattern = "CodeboomerSessionReset"})
    return schedule_notify(string.format("codeboomer: session #%d reset \226\128\148 the next annotation starts a fresh one", sid), vim.log.levels.INFO)
  end
end
M.ResetSession = _13_
local function concat_list(lines)
  return table.concat(lines, "\n")
end
local function concat_list_with_format(lines, beginning, sep, _end)
  return (beginning .. "\n" .. table.concat(lines, (sep .. "\n")) .. "\n" .. _end .. "\n")
end
local function get_visual_lines(opts)
  local _16_
  do
    local t_15_ = opts
    if (nil ~= t_15_) then
      t_15_ = t_15_.range
    else
    end
    _16_ = t_15_
  end
  if (_16_ == 2) then
    local path = git["rel-path"]()
    local ok, region_lines = pcall(vim.fn.getregion, vim.fn.getpos("'<"), vim.fn.getpos("'>"), {type = vim.fn.visualmode()})
    local lines
    if ok then
      lines = concat_list(region_lines)
    else
      lines = concat_list(vim.api.nvim_buf_get_lines(0, (opts.line1 - 1), opts.line2, false))
    end
    return {lines = lines, line1 = opts.line1, line2 = opts.line2, file = path}
  else
    return nil
  end
end
local function compose_message(context, text)
  if context then
    return ("regarding " .. context.file .. " lines " .. context.line1 .. " to " .. context.line2 .. "\n" .. context.lines .. "\n" .. text .. "\n")
  else
    local file = git["rel-path"]()
    return ("regarding " .. file .. "\n" .. text .. "\n")
  end
end
local function comment_line(c)
  local name
  local _22_
  do
    local t_21_ = review["comment-author"](c)
    if (nil ~= t_21_) then
      t_21_ = t_21_.name
    else
    end
    _22_ = t_21_
  end
  name = (_22_ or "unknown")
  return string.format("[%s] %s: %s", (c.source or "user"), name, (c.body or ""))
end
local function thread_message(t)
  local conversation
  do
    local tbl_26_ = {}
    local i_27_ = 0
    for _, c in ipairs(review["conversation-comments"]((t.id or 0))) do
      local val_28_ = comment_line(c)
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    conversation = tbl_26_
  end
  if ("file" == (t.type or "line")) then
    return string.format("regarding %s (thread %s)\n%s", (t.file_path or "?"), (t.id or "?"), table.concat(conversation, "\n\n"))
  else
    return string.format("regarding %s lines %s to %s (thread %s)\n%s\n%s", (t.file_path or "?"), (t.line_start or "?"), (t.line_end or "?"), (t.id or "?"), (t.code_snapshot or ""), table.concat(conversation, "\n\n"))
  end
end
local function _26_()
  return choose_pane(all_panes())
end
M.SetPane = _26_
local function _27_()
  if not codeboomer.pane then
    return schedule_notify("codeboomer: no pane selected \226\128\148 pick one with SetPane first", vim.log.levels.WARN)
  else
    local case_28_ = codeboomer.pane.driver
    if (case_28_ == "channel") then
      local res, err = channel.toggle(codeboomer.pane)
      if res then
        local _29_
        if ("hidden" == res) then
          _29_ = "codeboomer: terminal collapsed \226\128\148 the process keeps running"
        else
          _29_ = "codeboomer: terminal back on the side"
        end
        return schedule_notify(_29_, vim.log.levels.INFO)
      else
        return schedule_notify(("codeboomer: " .. (err or "toggle failed")), vim.log.levels.WARN)
      end
    else
      local _ = case_28_
      return schedule_notify("codeboomer: the selected pane is a tmux pane \226\128\148 its window is tmux's to toggle", vim.log.levels.WARN)
    end
  end
end
M.TogglePane = _27_
local function _34_()
  local res, err = sidebar.toggle()
  if res then
    local _35_
    if ("hidden" == res) then
      _35_ = "codeboomer: comments pane collapsed \226\128\148 ToggleSidebar brings it back"
    else
      _35_ = "codeboomer: comments pane back"
    end
    return schedule_notify(_35_, vim.log.levels.INFO)
  else
    return schedule_notify(("codeboomer: " .. (err or "toggle failed")), vim.log.levels.WARN)
  end
end
M.ToggleSidebar = _34_
local function launch_process(entry)
  local cwd = (git["work-root"]() or vim.fn.getcwd())
  local pane, err = channel.spawn(cwd, entry.label, entry.argv)
  if pane then
    codeboomer.pane = pane
    return schedule_notify(string.format("codeboomer: %s started in terminal buffer %s \226\128\148 it is the pane now", entry.label, pane["pane-id"]), vim.log.levels.INFO)
  else
    return schedule_notify(("codeboomer: LaunchProcess failed: " .. (err or "unknown error")), vim.log.levels.ERROR)
  end
end
local function process_display(p)
  return string.format("%-16s %s", p.label, table.concat(p.argv, " "))
end
local function _39_()
  local processes
  local _41_
  do
    local t_40_ = config
    if (nil ~= t_40_) then
      t_40_ = t_40_.config
    else
    end
    if (nil ~= t_40_) then
      t_40_ = t_40_.prompting
    else
    end
    if (nil ~= t_40_) then
      t_40_ = t_40_.launch_processes
    else
    end
    _41_ = t_40_
  end
  processes = (_41_ or {})
  if (0 == #processes) then
    return schedule_notify("codeboomer: prompting.launch_processes not set \226\128\148 call setup() first", vim.log.levels.ERROR)
  else
    if (1 == #processes) then
      return launch_process(processes[1])
    else
      return picker.choose("Pick a Process> ", processes, process_display, launch_process)
    end
  end
end
M.LaunchProcess = _39_
local function _47_()
  local function _48_(pane)
    codeboomer.pane = pane
    return nil
  end
  return reviewer.launch(_48_)
end
M.LaunchReviewer = _47_
local function _49_(opts)
  if codeboomer.pane then
    local context = get_visual_lines(opts)
    local function _50_(lines)
      local text = concat_list(lines)
      if (text ~= "") then
        state["last-input"] = text
        return send_keys_to_selected_pane(compose_message(context, text))
      else
        return nil
      end
    end
    return input.open({title = " SendPrompt> ", ["on-submit"] = _50_})
  else
    local function _52_()
      local context = get_visual_lines(opts)
      local function _53_(lines)
        local text = concat_list(lines)
        if (text ~= "") then
          state["last-input"] = text
          return send_keys_to_selected_pane(compose_message(context, text))
        else
          return nil
        end
      end
      return input.open({title = " SendPrompt> ", ["on-submit"] = _53_})
    end
    return choose_pane(all_panes(), _52_)
  end
end
M.SendPrompt = _49_
local function _56_(opts)
  if state["last-input"] then
    if codeboomer.pane then
      local context = get_visual_lines(opts)
      return send_keys_to_selected_pane(compose_message(context, state["last-input"]))
    else
      local function _57_()
        local context = get_visual_lines(opts)
        return send_keys_to_selected_pane(compose_message(context, state["last-input"]))
      end
      return choose_pane(all_panes(), _57_)
    end
  else
    return schedule_notify("codeboomer: no prompt sent yet \226\128\148 nothing to resend", vim.log.levels.WARN)
  end
end
M.SendLastPrompt = _56_
local function _60_(opts)
  if codeboomer.pane then
    local context = get_visual_lines(opts)
    if context then
      return send_keys_to_selected_pane(context.lines)
    else
      return nil
    end
  else
    local function _62_()
      local context = get_visual_lines(opts)
      if context then
        return send_keys_to_selected_pane(context.lines)
      else
        return nil
      end
    end
    return choose_pane(all_panes(), _62_)
  end
end
M.SendSelection = _60_
local function annotate_flow(opts)
  if codeboomer.pane then
    local context = get_visual_lines(opts)
    local file_path
    if not context then
      file_path = git["rel-path"]()
    else
      file_path = nil
    end
    local repo_file_3f = (file_path and (file_path ~= "") and (file_path ~= vim.api.nvim_buf_get_name(0)))
    if (not context and not repo_file_3f) then
      return schedule_notify("codeboomer: annotate needs a selection or a repo file", vim.log.levels.ERROR)
    else
      local function _66_(lines)
        local text = concat_list(lines)
        if (text == "") then
          return schedule_notify("codeboomer: empty annotation ignored", vim.log.levels.WARN)
        else
          local sid = review["ensure-session"]()
          if not sid then
            local _67_
            if git["repo-root"]() then
              _67_ = "codeboomer: annotate needs a checked-out branch \226\128\148 sessions are tied to branches, a detached HEAD has none"
            else
              _67_ = "codeboomer: annotate needs a repo file"
            end
            return schedule_notify(_67_, vim.log.levels.ERROR)
          else
            if context then
              review["user-comment"](sid, context.file, context.line1, context.line2, context.lines, text)
            else
              review["file-comment"](sid, file_path, text)
            end
            return vim.api.nvim_exec_autocmds("User", {pattern = "CodeboomerAnnotated"})
          end
        end
      end
      return input.open({title = " Annotate> ", ["on-submit"] = _66_})
    end
  else
    local function _73_()
      local context = get_visual_lines(opts)
      local file_path
      if not context then
        file_path = git["rel-path"]()
      else
        file_path = nil
      end
      local repo_file_3f = (file_path and (file_path ~= "") and (file_path ~= vim.api.nvim_buf_get_name(0)))
      if (not context and not repo_file_3f) then
        return schedule_notify("codeboomer: annotate needs a selection or a repo file", vim.log.levels.ERROR)
      else
        local function _75_(lines)
          local text = concat_list(lines)
          if (text == "") then
            return schedule_notify("codeboomer: empty annotation ignored", vim.log.levels.WARN)
          else
            local sid = review["ensure-session"]()
            if not sid then
              local _76_
              if git["repo-root"]() then
                _76_ = "codeboomer: annotate needs a checked-out branch \226\128\148 sessions are tied to branches, a detached HEAD has none"
              else
                _76_ = "codeboomer: annotate needs a repo file"
              end
              return schedule_notify(_76_, vim.log.levels.ERROR)
            else
              if context then
                review["user-comment"](sid, context.file, context.line1, context.line2, context.lines, text)
              else
                review["file-comment"](sid, file_path, text)
              end
              return vim.api.nvim_exec_autocmds("User", {pattern = "CodeboomerAnnotated"})
            end
          end
        end
        return input.open({title = " Annotate> ", ["on-submit"] = _75_})
      end
    end
    return choose_pane(all_panes(), _73_)
  end
end
local function _83_(opts)
  return annotate_flow(opts)
end
M.Annotate = _83_
local function send_batch(pending, directive_text)
  do
    local seen = {}
    local threads = {}
    for _, a in ipairs(pending) do
      if not seen[(a.thread.id or 0)] then
        seen[(a.thread.id or 0)] = true
        table.insert(threads, a.thread)
      else
      end
    end
    local messages
    do
      local tbl_26_ = {}
      local i_27_ = 0
      for _, t in ipairs(threads) do
        local val_28_ = thread_message(t)
        if (nil ~= val_28_) then
          i_27_ = (i_27_ + 1)
          tbl_26_[i_27_] = val_28_
        else
        end
      end
      messages = tbl_26_
    end
    local annotations = concat_list_with_format(messages, "==Section Start==", "====", "==Section End==")
    local execute_3f
    do
      local hit = false
      for _, a in ipairs(pending) do
        if hit then break end
        hit = (a.comment.body == agent["execute-body"])
      end
      execute_3f = hit
    end
    local _86_
    if execute_3f then
      _86_ = agent["execute-instructions"]()
    else
      _86_ = ""
    end
    send_keys_to_selected_pane((annotations .. agent["reply-instructions"]() .. directive_text .. "\n" .. _86_))
    local function _88_()
      local tbl_26_ = {}
      local i_27_ = 0
      for _, a in ipairs(pending) do
        local val_28_ = a.comment.id
        if (nil ~= val_28_) then
          i_27_ = (i_27_ + 1)
          tbl_26_[i_27_] = val_28_
        else
        end
      end
      return tbl_26_
    end
    review["mark-annotations"]("sent", _88_())
  end
  return true
end
local function flush_pending(directive_text)
  local pending = review["pending-for-flush"](sidebar["session-id"]())
  if (0 == #pending) then
    return schedule_notify("codeboomer: nothing to flush \226\128\148 no unsent messages", vim.log.levels.WARN)
  else
    return send_batch(pending, directive_text)
  end
end
local function _91_()
  if codeboomer.pane then
    local function _92_(_241)
      return _241.label
    end
    local function _93_(_241)
      return flush_pending(_241.text)
    end
    return picker.choose("Pick a Directive> ", directives.list(), _92_, _93_)
  else
    local function _94_()
      local function _95_(_241)
        return _241.label
      end
      local function _96_(_241)
        return flush_pending(_241.text)
      end
      return picker.choose("Pick a Directive> ", directives.list(), _95_, _96_)
    end
    return choose_pane(all_panes(), _94_)
  end
end
M.FlushWithDirective = _91_
local function _98_(thread_id)
  if codeboomer.pane then
    local pending
    do
      local tbl_26_ = {}
      local i_27_ = 0
      for _, a in ipairs(review["pending-for-flush"](sidebar["session-id"]())) do
        local val_28_
        if ((a.thread.id or 0) == (thread_id or 0)) then
          val_28_ = a
        else
          val_28_ = nil
        end
        if (nil ~= val_28_) then
          i_27_ = (i_27_ + 1)
          tbl_26_[i_27_] = val_28_
        else
        end
      end
      pending = tbl_26_
    end
    if (0 == #pending) then
      return schedule_notify(string.format("codeboomer: thread #%d has nothing unsent", (thread_id or 0)), vim.log.levels.WARN)
    else
      send_batch(pending, agent["fix-directive"]())
      schedule_notify(string.format("codeboomer: thread #%d sent with the fix directive", (thread_id or 0)), vim.log.levels.INFO)
      return true
    end
  else
    local function _102_()
      local pending
      do
        local tbl_26_ = {}
        local i_27_ = 0
        for _, a in ipairs(review["pending-for-flush"](sidebar["session-id"]())) do
          local val_28_
          if ((a.thread.id or 0) == (thread_id or 0)) then
            val_28_ = a
          else
            val_28_ = nil
          end
          if (nil ~= val_28_) then
            i_27_ = (i_27_ + 1)
            tbl_26_[i_27_] = val_28_
          else
          end
        end
        pending = tbl_26_
      end
      if (0 == #pending) then
        return schedule_notify(string.format("codeboomer: thread #%d has nothing unsent", (thread_id or 0)), vim.log.levels.WARN)
      else
        send_batch(pending, agent["fix-directive"]())
        schedule_notify(string.format("codeboomer: thread #%d sent with the fix directive", (thread_id or 0)), vim.log.levels.INFO)
        return true
      end
    end
    return choose_pane(all_panes(), _102_)
  end
end
M.FixThread = _98_
return M
