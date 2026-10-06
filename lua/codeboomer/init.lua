-- [nfnl] fnl/codeboomer/init.fnl
vim = vim
local config = require("codeboomer.config")
local input = require("codeboomer.input")
local directives = require("codeboomer.directives")
local review = require("codeboomer.review")
local sidebar = require("codeboomer.sidebar")
local agent = require("codeboomer.agent")
local one_offs = require("codeboomer.one-offs")
local git = require("codeboomer.git")
local tmux = require("codeboomer.tmux")
local picker = require("codeboomer.picker")
local reviewer = require("codeboomer.reviewer")
local state = {pane = nil, ["last-input"] = nil}
local M = {}
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
local function one_off_result(stdout)
  local ok, parsed = pcall(vim.json.decode, stdout)
  if (ok and (type(parsed) == "table") and parsed.result) then
    return parsed.result
  else
    return stdout
  end
end
local function run_one_off(cmd, prompt)
  local argv = vim.list_slice((cmd.argv or {}))
  local timeout = (cmd.timeout or 60000)
  local function _4_(obj)
    local function _5_()
      if (obj.code == 0) then
        return vim.notify(one_off_result((obj.stdout or "")), vim.log.levels.INFO)
      else
        return vim.notify(("codeboomer: one-off failed (exit " .. obj.code .. ")\n" .. (obj.stderr or "")), vim.log.levels.ERROR)
      end
    end
    return vim.schedule(_5_)
  end
  return vim.system(vim.list_extend(argv, {prompt}), {text = true, timeout = timeout}, _4_)
end
local function shorten_path(path)
  local home = os.getenv("HOME")
  if (home and (1 == string.find(path, home, 1, true))) then
    return ("~" .. string.sub(path, (1 + #home)))
  else
    return path
  end
end
local function send_keys_to_selected_pane(text)
  return tmux.send(state.pane, text)
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
  local last_lines = tmux["last-lines"]()
  local on_pick
  local function _10_(pane)
    state.pane = pane
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
  return picker.choose("Pick a Pane> ", panes, _12_, on_pick, {preview = tmux["preview-command"], fzf_opts = {["--with-nth"] = "2.."}, winopts = {preview = {layout = "vertical", vertical = "down:45%:follow", wrap = false}}})
end
local one_off_argv_max_length = 80
local function one_off_display(c)
  local argv = table.concat(c.argv, " ")
  local short_argv
  if (#argv > one_off_argv_max_length) then
    short_argv = (string.sub(argv, 1, one_off_argv_max_length) .. "\226\128\166")
  else
    short_argv = argv
  end
  local timeout
  if c.timeout then
    timeout = string.format(" (%ds)", math.floor((c.timeout / 1000)))
  else
    timeout = ""
  end
  return string.format("%-22s %s%s", c.label, short_argv, timeout)
end
local function choose_one_off(commands, k)
  return picker.choose("Pick a One-off> ", commands, one_off_display, k)
end
local function _15_()
  local sid = sidebar["session-id"]()
  if not sid then
    return schedule_notify("codeboomer: no session for this branch", vim.log.levels.WARN)
  else
    review["delete-session"](sid)
    vim.api.nvim_exec_autocmds("User", {pattern = "CodeboomerSessionReset"})
    return schedule_notify(string.format("codeboomer: session #%d reset \226\128\148 the next annotation starts a fresh one", sid), vim.log.levels.INFO)
  end
end
M.ResetSession = _15_
local function concat_list(lines)
  return table.concat(lines, "\n")
end
local function concat_list_with_format(lines, beginning, sep, _end)
  return (beginning .. "\n" .. table.concat(lines, (sep .. "\n")) .. "\n" .. _end .. "\n")
end
local function get_visual_lines(opts)
  local _18_
  do
    local t_17_ = opts
    if (nil ~= t_17_) then
      t_17_ = t_17_.range
    else
    end
    _18_ = t_17_
  end
  if (_18_ == 2) then
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
  local _24_
  do
    local t_23_ = review["comment-author"](c)
    if (nil ~= t_23_) then
      t_23_ = t_23_.name
    else
    end
    _24_ = t_23_
  end
  name = (_24_ or "unknown")
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
local function _28_()
  return choose_pane(tmux["list-panes"]())
end
M.SetPane = _28_
local function _29_()
  local function _30_(pane)
    state.pane = pane
    return nil
  end
  return reviewer.launch(_30_)
end
M.LaunchReviewer = _29_
local function _31_(opts)
  if state.pane then
    local context = get_visual_lines(opts)
    local function _32_(lines)
      local text = concat_list(lines)
      if (text ~= "") then
        state["last-input"] = text
        return send_keys_to_selected_pane(compose_message(context, text))
      else
        return nil
      end
    end
    return input.open({title = " SendPrompt> ", ["on-submit"] = _32_})
  else
    local function _34_()
      local context = get_visual_lines(opts)
      local function _35_(lines)
        local text = concat_list(lines)
        if (text ~= "") then
          state["last-input"] = text
          return send_keys_to_selected_pane(compose_message(context, text))
        else
          return nil
        end
      end
      return input.open({title = " SendPrompt> ", ["on-submit"] = _35_})
    end
    return choose_pane(tmux["list-panes"](), _34_)
  end
end
M.SendPrompt = _31_
local function _38_(opts)
  if state["last-input"] then
    if state.pane then
      local context = get_visual_lines(opts)
      return send_keys_to_selected_pane(compose_message(context, state["last-input"]))
    else
      local function _39_()
        local context = get_visual_lines(opts)
        return send_keys_to_selected_pane(compose_message(context, state["last-input"]))
      end
      return choose_pane(tmux["list-panes"](), _39_)
    end
  else
    return schedule_notify("codeboomer: no prompt sent yet \226\128\148 nothing to resend", vim.log.levels.WARN)
  end
end
M.SendLastPrompt = _38_
local function _42_(opts)
  if state.pane then
    local context = get_visual_lines(opts)
    if context then
      return send_keys_to_selected_pane(context.lines)
    else
      return nil
    end
  else
    local function _44_()
      local context = get_visual_lines(opts)
      if context then
        return send_keys_to_selected_pane(context.lines)
      else
        return nil
      end
    end
    return choose_pane(tmux["list-panes"](), _44_)
  end
end
M.SendSelection = _42_
local function _47_(opts)
  local context = get_visual_lines(opts)
  local commands = (one_offs.list() or {})
  local ask
  local function _48_(cmd)
    local function _49_(lines)
      local text = concat_list(lines)
      if (text ~= "") then
        return run_one_off(cmd, compose_message(context, text))
      else
        return nil
      end
    end
    return input.open({title = string.format(" AskOneOff: %s (Enter to send)> ", cmd.label), ["submit-on-enter"] = true, ["on-submit"] = _49_})
  end
  ask = _48_
  if (0 == #commands) then
    return schedule_notify("codeboomer: prompting.one_off_commands not set \226\128\148 call setup() first", vim.log.levels.ERROR)
  else
    if (1 == #commands) then
      return ask(commands[1])
    else
      return choose_one_off(commands, ask)
    end
  end
end
M.AskOneOff = _47_
local function annotate_flow(opts)
  if state.pane then
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
      local function _54_(lines)
        local text = concat_list(lines)
        if (text == "") then
          return schedule_notify("codeboomer: empty annotation ignored", vim.log.levels.WARN)
        else
          local sid = review["ensure-session"]()
          if not sid then
            local _55_
            if git["repo-root"]() then
              _55_ = "codeboomer: annotate needs a checked-out branch \226\128\148 sessions are tied to branches, a detached HEAD has none"
            else
              _55_ = "codeboomer: annotate needs a repo file"
            end
            return schedule_notify(_55_, vim.log.levels.ERROR)
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
      return input.open({title = " Annotate> ", ["on-submit"] = _54_})
    end
  else
    local function _61_()
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
        local function _63_(lines)
          local text = concat_list(lines)
          if (text == "") then
            return schedule_notify("codeboomer: empty annotation ignored", vim.log.levels.WARN)
          else
            local sid = review["ensure-session"]()
            if not sid then
              local _64_
              if git["repo-root"]() then
                _64_ = "codeboomer: annotate needs a checked-out branch \226\128\148 sessions are tied to branches, a detached HEAD has none"
              else
                _64_ = "codeboomer: annotate needs a repo file"
              end
              return schedule_notify(_64_, vim.log.levels.ERROR)
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
        return input.open({title = " Annotate> ", ["on-submit"] = _63_})
      end
    end
    return choose_pane(tmux["list-panes"](), _61_)
  end
end
local function _71_(opts)
  return annotate_flow(opts)
end
M.Annotate = _71_
local function flush_pending(directive_text)
  local pending = review["pending-for-flush"](sidebar["session-id"]())
  if (0 == #pending) then
    return schedule_notify("codeboomer: nothing to flush \226\128\148 no unsent messages", vim.log.levels.WARN)
  else
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
    send_keys_to_selected_pane((annotations .. agent["reply-instructions"]() .. directive_text .. "\n"))
    local function _74_()
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
    return review["mark-annotations"]("sent", _74_())
  end
end
local function _77_()
  if state.pane then
    local function _78_(_241)
      return _241.label
    end
    local function _79_(_241)
      return flush_pending(_241.text)
    end
    return picker.choose("Pick a Directive> ", directives.list(), _78_, _79_)
  else
    local function _80_()
      local function _81_(_241)
        return _241.label
      end
      local function _82_(_241)
        return flush_pending(_241.text)
      end
      return picker.choose("Pick a Directive> ", directives.list(), _81_, _82_)
    end
    return choose_pane(tmux["list-panes"](), _80_)
  end
end
M.FlushWithDirective = _77_
return M
